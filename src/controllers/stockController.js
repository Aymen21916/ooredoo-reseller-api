'use strict';

const db       = require('../config/db');
const AppError = require('../utils/AppError');
const { asyncHandler, sendSuccess, sendCreated } = require('../utils/asyncHandler');
const { audit } = require('../utils/audit');
const { requireFields, parseId, parsePositiveInt, parseString } = require('../utils/validators');

// ─── Serial-number helpers ───────────────────────────────────────────────────

/**
 * Validate a SIM serial number. Real Ooredoo ICCIDs are 19-20 digit numeric
 * strings, but we keep it loose: 10-22 digits, numeric only.
 */
const validateSerial = (raw, fieldName = 'first_serial') => {
  const s = String(raw || '').trim();
  if (!/^\d{10,22}$/.test(s)) {
    throw AppError.badRequest(
      `"${fieldName}" must be a numeric serial number (10-22 digits).`,
      'VALIDATION_ERROR'
    );
  }
  return s;
};

/**
 * Generate a sequence of serial numbers using BigInt arithmetic (so we don't
 * lose precision on 16+ digit numbers — JS Number maxes out at 2^53).
 *
 * @param {string} firstSerial - numeric string
 * @param {number} count
 * @returns {string[]}
 */
const generateSerials = (firstSerial, count) => {
  const start = BigInt(firstSerial);
  const length = firstSerial.length;
  const out = new Array(count);
  for (let i = 0; i < count; i++) {
    out[i] = (start + BigInt(i)).toString().padStart(length, '0');
  }
  return out;
};

// ─── POST /api/stock/assign  (admin only) ───────────────────────────────────
// Body: { cashier_id, first_serial, count }
// Inserts `count` consecutive generic SIM cards owned by the cashier.
// The offer is decided at sale time, not at assignment.

const assignBatch = asyncHandler(async (req, res) => {
  requireFields(req.body, ['cashier_id', 'first_serial', 'count']);

  const cashierId   = parseId(req.body.cashier_id, 'cashier_id');
  const firstSerial = validateSerial(req.body.first_serial, 'first_serial');
  const count       = parsePositiveInt(req.body.count, 'count');

  if (count > 1000) {
    throw AppError.badRequest('count must be 1000 or less per batch.', 'VALIDATION_ERROR');
  }

  const result = await db.withTransaction(async (client) => {
    // Validate cashier
    const { rows: userRows } = await client.query(
      `SELECT id, full_name, role, is_active FROM users WHERE id = $1`,
      [cashierId]
    );
    if (!userRows[0])           throw AppError.notFound('Cashier not found.');
    if (!userRows[0].is_active) throw AppError.badRequest('Cashier is deactivated.');
    if (userRows[0].role !== 'cashier') {
      throw AppError.badRequest('Stock can only be assigned to cashier accounts.', 'VALIDATION_ERROR');
    }

    // Generate the serial sequence
    const serials = generateSerials(firstSerial, count);
    const lastSerial = serials[serials.length - 1];

    // Bulk-insert; conflict on duplicate serial returns the conflicting row
    const placeholders = serials
      .map((_, i) => `($${i * 4 + 1}, $${i * 4 + 2}, $${i * 4 + 3}, $${i * 4 + 4})`)
      .join(', ');
    const params = serials.flatMap((s) => [s, cashierId, req.user.id, 'available']);

    let insertResult;
    try {
      insertResult = await client.query(
        `INSERT INTO sim_cards (serial_number, cashier_id, assigned_by, status)
         VALUES ${placeholders}
         RETURNING id, serial_number`,
        params
      );
    } catch (err) {
      if (err.code === '23505') {
        const { rows: clashes } = await client.query(
          `SELECT serial_number FROM sim_cards WHERE serial_number = ANY($1::varchar[])`,
          [serials]
        );
        throw AppError.conflict(
          `Some serials already exist in the system: ${clashes.map((c) => c.serial_number).slice(0, 5).join(', ')}${clashes.length > 5 ? '…' : ''}.`,
          'DUPLICATE_SERIAL'
        );
      }
      throw err;
    }

    audit({
      userId:    req.user.id,
      action:    'STOCK_ASSIGN',
      table:     'sim_cards',
      recordId:  null,
      newValues: { cashier_id: cashierId, count, first_serial: firstSerial, last_serial: lastSerial },
      ip:        req.clientIp,
    });

    return {
      cashier:      { id: cashierId, name: userRows[0].full_name },
      count,
      first_serial: firstSerial,
      last_serial:  lastSerial,
      cards:        insertResult.rows,
    };
  });

  sendCreated(res, result, `Assigned ${count} SIM card(s).`);
});

// ─── GET /api/stock/cashiers  (admin only) ──────────────────────────────────
// Returns one row per cashier with available/sold counts (no offer breakdown).

const getCashierInventory = asyncHandler(async (req, res) => {
  const { rows } = await db.query(
    `SELECT * FROM v_cashier_sim_inventory
     ORDER BY store_id, cashier_name`
  );

  sendSuccess(res, rows.map((r) => ({
    cashier_id:      r.cashier_id,
    cashier_name:    r.cashier_name,
    store_id:        r.store_id,
    store_name:      r.store_name,
    available_count: parseInt(r.available_count, 10),
    sold_count:      parseInt(r.sold_count, 10),
    voided_count:    parseInt(r.voided_count, 10),
    next_serial:     r.next_serial,
    last_serial:     r.last_serial,
    is_low_stock:    r.is_low_stock,
  })));
});

// ─── GET /api/stock/my  (cashier or admin) ───────────────────────────────────
// Returns the authenticated cashier's inventory totals (or another cashier's
// when an admin passes ?cashier_id=).

const getMyInventory = asyncHandler(async (req, res) => {
  const cashierId = req.user.role === 'admin' && req.query.cashier_id
    ? parseId(req.query.cashier_id, 'cashier_id')
    : req.user.id;

  const { rows } = await db.query(
    `SELECT * FROM v_cashier_sim_inventory WHERE cashier_id = $1`,
    [cashierId]
  );

  const r = rows[0];
  if (!r) {
    return sendSuccess(res, {
      available_count: 0,
      sold_count:      0,
      next_serial:     null,
      is_low_stock:    true,
    });
  }

  sendSuccess(res, {
    available_count: parseInt(r.available_count, 10),
    sold_count:      parseInt(r.sold_count, 10),
    voided_count:    parseInt(r.voided_count, 10),
    next_serial:     r.next_serial,
    last_serial:     r.last_serial,
    is_low_stock:    r.is_low_stock,
  });
});

// ─── GET /api/stock/cards  (admin only) ──────────────────────────────────────
// Detailed paginated list of SIM cards for audit / search.
// Filters: cashier_id, status, q (serial substring)

const listCards = asyncHandler(async (req, res) => {
  const conditions = [];
  const params     = [];

  if (req.query.cashier_id) {
    params.push(parseId(req.query.cashier_id, 'cashier_id'));
    conditions.push(`sc.cashier_id = $${params.length}`);
  }
  if (req.query.status && ['available', 'sold', 'voided'].includes(req.query.status)) {
    params.push(req.query.status);
    conditions.push(`sc.status = $${params.length}`);
  }
  if (req.query.q) {
    const q = parseString(req.query.q, 'q', 32);
    params.push(`%${q}%`);
    conditions.push(`sc.serial_number LIKE $${params.length}`);
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

  const { rows } = await db.query(
    `SELECT sc.id, sc.serial_number, sc.status, sc.assigned_at, sc.sold_at,
            u.full_name AS cashier_name
     FROM sim_cards sc
     JOIN users  u ON u.id = sc.cashier_id
     ${where}
     ORDER BY sc.serial_number
     LIMIT 500`,
    params
  );

  sendSuccess(res, rows);
});

module.exports = {
  assignBatch,
  getCashierInventory,
  getMyInventory,
  listCards,
};
