'use strict';

const db = require('../config/db');
const AppError = require('../utils/AppError');
const { asyncHandler, sendSuccess } = require('../utils/asyncHandler');
const { audit } = require('../utils/audit');
const {
  requireFields, parseId, parsePositiveNumber, parseString,
} = require('../utils/validators');

// ─── Helpers ─────────────────────────────────────────────────────────────────

/** Load the current pool state (latest row). Returns zeros if the log is empty. */
const loadCurrentPool = async (client = db) => {
  const { rows } = await client.query(
    `SELECT available_balance, available_bonus, available_points
     FROM global_pool_state
     ORDER BY id DESC
     LIMIT 1`
  );
  return rows[0] || { available_balance: 0, available_bonus: 0, available_points: 0 };
};

/** Load the current register cash for a given store (latest row). */
const loadCurrentRegister = async (storeId, client = db) => {
  const { rows } = await client.query(
    `SELECT cash_amount
     FROM store_register_state
     WHERE store_id = $1
     ORDER BY id DESC
     LIMIT 1`,
    [storeId]
  );
  return rows[0] ? parseFloat(rows[0].cash_amount) : 0;
};

/** Apply a +/- adjustment, clamped at 0 (schema forbids negative values). */
const applyAdjustment = (current, amount, type) => {
  const delta = type === 'subtract' ? -amount : amount;
  const next  = Number(current) + delta;
  if (next < 0) {
    throw AppError.badRequest(
      'Adjustment would result in a negative value.',
      'NEGATIVE_RESULT'
    );
  }
  return next;
};

// ─── GET /api/finances/pool ──────────────────────────────────────────────────
// Returns the current global pool state in the shape the frontend expects.

const getPool = asyncHandler(async (req, res) => {
  const pool = await loadCurrentPool();
  sendSuccess(res, {
    balance: parseFloat(pool.available_balance) || 0,
    bonus:   parseFloat(pool.available_bonus)   || 0,
    points:  parseInt(pool.available_points, 10) || 0,
  });
});

// ─── GET /api/finances/registers ─────────────────────────────────────────────
// Returns every active store with its current register cash.

const getRegisters = asyncHandler(async (req, res) => {
  const { rows } = await db.query(
    `SELECT s.id, s.name, s.location,
            COALESCE(r.cash_amount, 0) AS current_cash
     FROM stores s
     LEFT JOIN LATERAL (
       SELECT cash_amount
       FROM store_register_state
       WHERE store_id = s.id
       ORDER BY id DESC
       LIMIT 1
     ) r ON TRUE
     WHERE s.is_active = TRUE
     ORDER BY s.id`
  );

  sendSuccess(res, rows.map((r) => ({
    id:           r.id,
    name:         r.name,
    location:     r.location,
    current_cash: parseFloat(r.current_cash) || 0,
  })));
});

// ─── PUT /api/finances/pool ──────────────────────────────────────────────────
// Appends a new row to `global_pool_state` reflecting the adjusted value.
// Body: { field: 'balance'|'bonus'|'points', amount, type: 'add'|'subtract', note }

const updatePool = asyncHandler(async (req, res) => {
  requireFields(req.body, ['field', 'amount', 'type']);

  const fieldMap = {
    balance: 'available_balance',
    bonus:   'available_bonus',
    points:  'available_points',
  };
  const column = fieldMap[req.body.field];
  if (!column) {
    throw AppError.badRequest('field must be "balance", "bonus", or "points".', 'VALIDATION_ERROR');
  }

  const type = ['add', 'subtract'].includes(req.body.type) ? req.body.type : null;
  if (!type) throw AppError.badRequest('type must be "add" or "subtract".', 'VALIDATION_ERROR');

  const amount = parsePositiveNumber(req.body.amount, 'amount');
  const note   = req.body.note ? parseString(req.body.note, 'note', 500) : null;

  const result = await db.withTransaction(async (client) => {
    const current = await loadCurrentPool(client);

    // Start from current values; adjust only the targeted field.
    const next = {
      available_balance: parseFloat(current.available_balance) || 0,
      available_bonus:   parseFloat(current.available_bonus)   || 0,
      available_points:  parseInt(current.available_points, 10) || 0,
    };

    const rawNext = applyAdjustment(next[column], amount, type);
    next[column] = column === 'available_points' ? Math.round(rawNext) : rawNext;

    const { rows } = await client.query(
      `INSERT INTO global_pool_state
         (available_balance, available_bonus, available_points, updated_by, notes)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, available_balance, available_bonus, available_points, updated_at`,
      [
        next.available_balance,
        next.available_bonus,
        next.available_points,
        req.user.id,
        note,
      ]
    );

    audit({
      userId:    req.user.id,
      action:    'UPDATE',
      table:     'global_pool_state',
      recordId:  rows[0].id,
      oldValues: current,
      newValues: { [column]: next[column], delta: type === 'subtract' ? -amount : amount, note },
      ip:        req.clientIp,
    });

    return rows[0];
  });

  sendSuccess(res, {
    balance: parseFloat(result.available_balance) || 0,
    bonus:   parseFloat(result.available_bonus)   || 0,
    points:  parseInt(result.available_points, 10) || 0,
    updated_at: result.updated_at,
  }, 200, 'Pool updated.');
});

// ─── PUT /api/finances/registers/:id ─────────────────────────────────────────
// Appends a new row to `store_register_state` with the adjusted cash amount.
// Body: { amount, type: 'add'|'subtract', note }

const updateRegister = asyncHandler(async (req, res) => {
  requireFields(req.body, ['amount', 'type']);

  const storeId = parseId(req.params.id, 'store_id');
  const type    = ['add', 'subtract'].includes(req.body.type) ? req.body.type : null;
  if (!type) throw AppError.badRequest('type must be "add" or "subtract".', 'VALIDATION_ERROR');

  const amount = parsePositiveNumber(req.body.amount, 'amount');
  const note   = req.body.note ? parseString(req.body.note, 'note', 500) : null;

  // Verify the store exists and is active
  const { rows: storeRows } = await db.query(
    `SELECT id, name FROM stores WHERE id = $1 AND is_active = TRUE`,
    [storeId]
  );
  if (!storeRows[0]) throw AppError.notFound('Store not found.');

  const result = await db.withTransaction(async (client) => {
    const current = await loadCurrentRegister(storeId, client);
    const next    = applyAdjustment(current, amount, type);

    const { rows } = await client.query(
      `INSERT INTO store_register_state
         (store_id, cash_amount, updated_by, notes)
       VALUES ($1, $2, $3, $4)
       RETURNING id, store_id, cash_amount, updated_at`,
      [storeId, next, req.user.id, note]
    );

    audit({
      userId:    req.user.id,
      action:    'UPDATE',
      table:     'store_register_state',
      recordId:  rows[0].id,
      oldValues: { cash_amount: current },
      newValues: { cash_amount: next, delta: type === 'subtract' ? -amount : amount, note },
      ip:        req.clientIp,
    });

    return rows[0];
  });

  sendSuccess(res, {
    store_id:     result.store_id,
    current_cash: parseFloat(result.cash_amount) || 0,
    updated_at:   result.updated_at,
  }, 200, `${storeRows[0].name} register updated.`);
});

module.exports = {
  getPool,
  getRegisters,
  updatePool,
  updateRegister,
};
