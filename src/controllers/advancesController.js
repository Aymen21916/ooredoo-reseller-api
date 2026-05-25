'use strict';

const db = require('../config/db');
const AppError = require('../utils/AppError');
const { asyncHandler, sendCreated, sendSuccess } = require('../utils/asyncHandler');
const { audit } = require('../utils/audit');
const {
  parseId,
  parsePositiveInt,
  parsePagination,
  validateAmount,
  validateVoidReason,
} = require('../utils/validators');

// ─── Constants ───────────────────────────────────────────────────────────────

// Per design "Field Validation Rules" and Requirement 2.2/2.5.
const AMOUNT_LIMITS = { min: 0.01, max: 9999999999.99, decimals_allowed: 2 };
const NOTE_MAX_LEN  = 500;

// ─── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Validate and trim an optional note. Returns a string ≤500 chars or null.
 * Throws AppError('VALIDATION_ERROR', 400) if the value is the wrong shape.
 */
const parseNote = (raw) => {
  if (raw === undefined || raw === null || raw === '') return null;
  if (typeof raw !== 'string') {
    throw AppError.badRequest('"note" must be a string.', 'VALIDATION_ERROR');
  }
  const trimmed = raw.trim();
  if (trimmed.length === 0) return null;
  if (trimmed.length > NOTE_MAX_LEN) {
    throw AppError.badRequest(
      `"note" must be at most ${NOTE_MAX_LEN} characters after trimming.`,
      'VALIDATION_ERROR'
    );
  }
  return trimmed;
};

/**
 * Run the shared `validateAmount` helper but remap a VALIDATION_ERROR result
 * to `INVALID_AMOUNT` per Requirements 2.3 and the design's API contract.
 * Anything else (e.g. non-AppError programming bugs) propagates unchanged.
 */
const parseAdvanceAmount = (raw) => {
  try {
    return validateAmount(raw, { ...AMOUNT_LIMITS, fieldName: 'amount' });
  } catch (err) {
    if (err && err.isOperational && err.code === 'VALIDATION_ERROR') {
      throw AppError.badRequest(err.message, 'INVALID_AMOUNT');
    }
    throw err;
  }
};

/**
 * Resolve the cashier's currently open session. Throws 400 NO_OPEN_SESSION
 * when none exists. Cashier-only contexts use this; repayments do NOT.
 */
const requireOpenSession = async (cashierId, client = db) => {
  const { rows } = await client.query(
    `SELECT id FROM cashier_sessions
     WHERE cashier_id = $1 AND status = 'open'
     ORDER BY id DESC LIMIT 1`,
    [cashierId]
  );
  if (!rows[0]) {
    throw AppError.badRequest(
      'You have no open session. Open one before recording an advance.',
      'NO_OPEN_SESSION'
    );
  }
  return rows[0];
};

/**
 * Compute Outstanding_Advance_Balance for a cashier per Requirement 2.7
 * and the design's "Outstanding Advance Balance" SQL.
 *
 * Runs against the supplied client (so callers inside a transaction get a
 * consistent snapshot under their isolation level).
 */
const loadOutstandingBalance = async (cashierId, client = db) => {
  const { rows } = await client.query(
    `SELECT
       COALESCE(SUM(amount) FILTER (WHERE direction = 'advance'   AND is_voided = FALSE), 0)
     - COALESCE(SUM(amount) FILTER (WHERE direction = 'repayment' AND is_voided = FALSE), 0)
       AS outstanding_balance
     FROM cashier_advances
     WHERE cashier_id = $1`,
    [cashierId]
  );
  // NUMERIC parser is configured to return float; coerce defensively in case
  // a future caller turns it off.
  return parseFloat(rows[0].outstanding_balance) || 0;
};

/** Format a `cashier_advances` row for API responses. */
const shapeRow = (row) => ({
  id:           row.id,
  cashier_id:   row.cashier_id,
  session_id:   row.session_id,
  direction:    row.direction,
  amount:       parseFloat(row.amount) || 0,
  note:         row.note,
  is_voided:    row.is_voided,
  voided_at:    row.voided_at,
  voided_by:    row.voided_by,
  void_reason:  row.void_reason,
  created_at:   row.created_at,
  created_by:   row.created_by,
});

// ─── POST /api/advances  — cashier records an advance ───────────────────────

const createAdvance = asyncHandler(async (req, res) => {
  if (req.user.role !== 'cashier') {
    throw AppError.forbidden(
      'Only cashiers can record their own advances.',
      'INSUFFICIENT_ROLE'
    );
  }

  const amount = parseAdvanceAmount(req.body.amount);
  const note   = parseNote(req.body.note);

  const result = await db.withTransaction(async (client) => {
    const session = await requireOpenSession(req.user.id, client);

    const { rows } = await client.query(
      `INSERT INTO cashier_advances
         (cashier_id, session_id, direction, amount, note, created_by)
       VALUES ($1, $2, 'advance', $3, $4, $1)
       RETURNING *`,
      [req.user.id, session.id, amount, note]
    );
    return rows[0];
  });

  audit({
    userId:      req.user.id,
    action:      'INSERT',
    table:       'cashier_advances',
    recordId:    result.id,
    newValues:   {
      cashier_id: result.cashier_id,
      session_id: result.session_id,
      direction:  'advance',
      amount,
      note,
    },
    description: 'advance',
    ip:          req.clientIp,
  });

  sendCreated(res, shapeRow(result), 'Advance recorded.');
});

// ─── POST /api/advances/repayment  — admin records a repayment ──────────────

const createRepayment = asyncHandler(async (req, res) => {
  if (req.user.role !== 'admin') {
    throw AppError.forbidden(
      'Only admins can record repayments.',
      'INSUFFICIENT_ROLE'
    );
  }

  const cashierId = parsePositiveInt(req.body.cashier_id, 'cashier_id');
  const amount    = parseAdvanceAmount(req.body.amount);
  const note      = parseNote(req.body.note);

  const { row, balance_after } = await db.withTransaction(async (client) => {
    // Look up the cashier — must exist, be a cashier, AND be active.
    // Requirement 2.5 / Design API: 404 CASHIER_NOT_FOUND on missing/inactive.
    const { rows: userRows } = await client.query(
      `SELECT id, role, is_active FROM users WHERE id = $1`,
      [cashierId]
    );
    const user = userRows[0];
    if (!user || user.role !== 'cashier' || user.is_active !== true) {
      throw AppError.notFound('Cashier not found.', 'CASHIER_NOT_FOUND');
    }

    // Compute the current Outstanding_Advance_Balance. The transaction
    // isolates this read from concurrent inserts; in the unlikely case of a
    // race the schema accepts the row and the next read still sees a
    // non-negative balance (advances are bounded by INSUFFICIENT_REGISTER_CASH
    // checks elsewhere; here we just enforce the ceiling at request time).
    const balance = await loadOutstandingBalance(cashierId, client);

    if (amount > balance) {
      throw AppError.badRequest(
        'Repayment exceeds the cashier\'s outstanding balance.',
        'REPAYMENT_EXCEEDS_BALANCE'
      ).withDetails({ current_balance: balance });
    }

    const { rows: insertRows } = await client.query(
      `INSERT INTO cashier_advances
         (cashier_id, session_id, direction, amount, note, created_by)
       VALUES ($1, NULL, 'repayment', $2, $3, $4)
       RETURNING *`,
      [cashierId, amount, note, req.user.id]
    );

    const inserted = insertRows[0];

    // Round to two decimals to keep the response value stable against
    // floating-point drift (NUMERIC math in PG is exact, but JS subtraction
    // is not).
    const balanceAfter = Math.round((balance - amount) * 100) / 100;

    return { row: inserted, balance_after: balanceAfter };
  });

  audit({
    userId:      req.user.id,
    action:      'INSERT',
    table:       'cashier_advances',
    recordId:    row.id,
    newValues:   {
      cashier_id: row.cashier_id,
      session_id: null,
      direction:  'repayment',
      amount,
      note,
    },
    description: 'repayment',
    ip:          req.clientIp,
  });

  sendCreated(res, {
    ...shapeRow(row),
    outstanding_balance: balance_after,
  }, 'Repayment recorded.');
});

// ─── GET /api/advances/me  — cashier's own ledger and balance ────────────────

const getMyAdvances = asyncHandler(async (req, res) => {
  if (req.user.role !== 'cashier') {
    throw AppError.forbidden(
      'Only cashiers can view their own advance ledger.',
      'INSUFFICIENT_ROLE'
    );
  }

  const { limit, offset } = parsePagination(req.query);

  const [{ rows: items }, balance] = await Promise.all([
    db.query(
      `SELECT *
       FROM cashier_advances
       WHERE cashier_id = $1
       ORDER BY created_at DESC, id DESC
       LIMIT $2 OFFSET $3`,
      [req.user.id, limit, offset]
    ),
    loadOutstandingBalance(req.user.id),
  ]);

  sendSuccess(res, {
    outstanding_balance: balance,
    items: items.map(shapeRow),
    limit,
    offset,
  });
});

// ─── GET /api/advances  — admin overview, one row per active cashier ────────

const getAllAdvances = asyncHandler(async (req, res) => {
  if (req.user.role !== 'admin') {
    throw AppError.forbidden(
      'Only admins can list every cashier\'s advance balance.',
      'INSUFFICIENT_ROLE'
    );
  }

  // One row per active cashier (Requirement 2.9). LEFT JOIN against the
  // ledger so cashiers with zero balance still appear, then aggregate the
  // outstanding balance and the latest non-voided activity timestamp.
  const { rows } = await db.query(
    `SELECT u.id                                AS cashier_id,
            u.full_name                         AS cashier_name,
            u.store_id                          AS store_id,
            s.name                              AS store_name,
            COALESCE(
              SUM(ca.amount) FILTER (
                WHERE ca.direction = 'advance'   AND ca.is_voided = FALSE
              ), 0
            )
            -
            COALESCE(
              SUM(ca.amount) FILTER (
                WHERE ca.direction = 'repayment' AND ca.is_voided = FALSE
              ), 0
            )                                   AS outstanding_balance,
            MAX(ca.created_at)
              FILTER (WHERE ca.is_voided = FALSE) AS last_activity_at
       FROM users u
       LEFT JOIN stores s           ON s.id = u.store_id
       LEFT JOIN cashier_advances ca ON ca.cashier_id = u.id
      WHERE u.role = 'cashier' AND u.is_active = TRUE
      GROUP BY u.id, u.full_name, u.store_id, s.name
      ORDER BY outstanding_balance DESC, u.full_name ASC`
  );

  sendSuccess(res, rows.map((r) => ({
    cashier_id:          r.cashier_id,
    cashier_name:        r.cashier_name,
    store_id:            r.store_id,
    store_name:          r.store_name,
    outstanding_balance: parseFloat(r.outstanding_balance) || 0,
    last_activity_at:    r.last_activity_at,
  })));
});

// ─── GET /api/advances/cashier/:id  — admin drill-down ──────────────────────

const getCashierAdvances = asyncHandler(async (req, res) => {
  if (req.user.role !== 'admin') {
    throw AppError.forbidden(
      'Only admins can drill into another cashier\'s advance ledger.',
      'INSUFFICIENT_ROLE'
    );
  }

  const cashierId = parseId(req.params.id, 'cashier_id');
  const { limit, offset } = parsePagination(req.query);

  const { rows: userRows } = await db.query(
    `SELECT u.id, u.full_name, u.role, u.is_active, u.store_id, s.name AS store_name
       FROM users u
       LEFT JOIN stores s ON s.id = u.store_id
      WHERE u.id = $1`,
    [cashierId]
  );
  const cashier = userRows[0];
  if (!cashier || cashier.role !== 'cashier' || cashier.is_active !== true) {
    throw AppError.notFound('Cashier not found.', 'CASHIER_NOT_FOUND');
  }

  const [{ rows: items }, balance] = await Promise.all([
    db.query(
      `SELECT *
         FROM cashier_advances
        WHERE cashier_id = $1
        ORDER BY created_at DESC, id DESC
        LIMIT $2 OFFSET $3`,
      [cashierId, limit, offset]
    ),
    loadOutstandingBalance(cashierId),
  ]);

  sendSuccess(res, {
    cashier: {
      id:         cashier.id,
      full_name:  cashier.full_name,
      store_id:   cashier.store_id,
      store_name: cashier.store_name,
    },
    outstanding_balance: balance,
    items:               items.map(shapeRow),
    limit,
    offset,
  });
});

// ─── POST /api/advances/:id/void  — shared cashier + admin endpoint ─────────

const voidAdvance = asyncHandler(async (req, res) => {
  const advanceId = parseId(req.params.id, 'id');
  // Per design API: the void payload field is `reason`. Tolerate the
  // alternative `void_reason` so admin tools that follow the audit-log
  // column name still work.
  const reason = validateVoidReason(
    req.body.reason !== undefined ? req.body.reason : req.body.void_reason
  );

  const updated = await db.withTransaction(async (client) => {
    const { rows } = await client.query(
      `SELECT id, cashier_id, session_id, direction, amount, is_voided, created_by
         FROM cashier_advances
        WHERE id = $1
        FOR UPDATE`,
      [advanceId]
    );
    const row = rows[0];
    if (!row) throw AppError.notFound('Advance not found.');

    if (row.is_voided) {
      // Requirement 2.10/2.11/3.12 contract: 409 ALREADY_VOIDED.
      throw AppError.conflict(
        'This advance row is already voided.',
        'ALREADY_VOIDED'
      );
    }

    // Role-based access control (Requirements 2.11, 2.12).
    if (req.user.role === 'cashier') {
      if (row.cashier_id !== req.user.id) {
        throw AppError.forbidden('Not your advance row.', 'FORBIDDEN');
      }

      // Cashiers may only void rows tied to their own currently open
      // session. Repayment rows have session_id = NULL, so the second check
      // already rejects those for cashier callers. Advance rows must
      // additionally match the cashier's open session id. Per Req 2.11 the
      // failure mode here is 403 FORBIDDEN — even a missing open session
      // surfaces as FORBIDDEN, not NO_OPEN_SESSION.
      const { rows: openRows } = await client.query(
        `SELECT id FROM cashier_sessions
          WHERE cashier_id = $1 AND status = 'open'
          ORDER BY id DESC LIMIT 1`,
        [req.user.id]
      );
      const openSessionId = openRows[0]?.id ?? null;
      if (openSessionId === null || row.session_id !== openSessionId) {
        throw AppError.forbidden(
          'Cashiers can only void advances from their currently open session.',
          'FORBIDDEN'
        );
      }
    } else if (req.user.role !== 'admin') {
      throw AppError.forbidden('Insufficient role.', 'INSUFFICIENT_ROLE');
    }

    const { rows: updatedRows } = await client.query(
      `UPDATE cashier_advances
          SET is_voided   = TRUE,
              voided_at   = NOW(),
              voided_by   = $1,
              void_reason = $2
        WHERE id = $3
        RETURNING *`,
      [req.user.id, reason, advanceId]
    );
    return { ...updatedRows[0], _direction: row.direction };
  });

  audit({
    userId:      req.user.id,
    action:      'VOID',
    table:       'cashier_advances',
    recordId:    updated.id,
    oldValues:   { is_voided: false, direction: updated._direction },
    newValues:   {
      is_voided: true,
      direction: updated._direction,
      void_reason: reason,
    },
    description: updated._direction,
    ip:          req.clientIp,
  });

  sendSuccess(res, {
    id:         updated.id,
    is_voided:  updated.is_voided,
    voided_at:  updated.voided_at,
    voided_by:  updated.voided_by,
  }, 200, 'Advance voided.');
});

module.exports = {
  createAdvance,
  createRepayment,
  getMyAdvances,
  getAllAdvances,
  getCashierAdvances,
  voidAdvance,
};
