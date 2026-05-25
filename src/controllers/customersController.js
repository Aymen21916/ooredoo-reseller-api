'use strict';

const db = require('../config/db');
const AppError = require('../utils/AppError');
const { asyncHandler, sendSuccess, sendCreated } = require('../utils/asyncHandler');
const { audit } = require('../utils/audit');
const { requireFields, parseId, parseString, parsePagination } = require('../utils/validators');

// ─── Helpers ─────────────────────────────────────────────────────────────────

/** Strip everything except digits and a leading + so phone numbers are normalised. */
const normalisePhone = (raw) => {
  const s = String(raw || '').trim();
  const cleaned = s.startsWith('+') ? '+' + s.slice(1).replace(/\D/g, '') : s.replace(/\D/g, '');
  if (cleaned.length < 6 || cleaned.length > 20) {
    throw AppError.badRequest('Phone number looks invalid (6-20 digits required).', 'VALIDATION_ERROR');
  }
  return cleaned;
};

const stats = async (client, customerId) => {
  const [{ rows: simRows }, { rows: stormRows }, { rows: accRows }] = await Promise.all([
    client.query(
      `SELECT COUNT(*) FILTER (WHERE is_voided = FALSE) AS sim_count,
              COALESCE(SUM(selling_price_snapshot)
                       FILTER (WHERE is_voided = FALSE), 0) AS sim_total,
              MAX(sold_at) AS sim_last
       FROM session_sim_sales WHERE customer_id = $1`,
      [customerId]
    ),
    client.query(
      `SELECT COUNT(*) FILTER (WHERE is_voided = FALSE) AS storm_count,
              COALESCE(SUM(amount)
                       FILTER (WHERE is_voided = FALSE), 0) AS storm_total,
              MAX(entered_at) AS storm_last
       FROM session_storm_entries WHERE customer_id = $1`,
      [customerId]
    ),
    client.query(
      `SELECT COUNT(*) FILTER (WHERE is_voided = FALSE) AS acc_count,
              COALESCE(SUM(price_snapshot)
                       FILTER (WHERE is_voided = FALSE), 0) AS acc_total,
              MAX(sold_at) AS acc_last
       FROM session_accessory_sales WHERE customer_id = $1`,
      [customerId]
    ),
  ]);
  const sim_count   = parseInt(simRows[0].sim_count, 10);
  const storm_count = parseInt(stormRows[0].storm_count, 10);
  const acc_count   = parseInt(accRows[0].acc_count, 10);
  const sim_total   = parseFloat(simRows[0].sim_total);
  const storm_total = parseFloat(stormRows[0].storm_total);
  const acc_total   = parseFloat(accRows[0].acc_total);
  const lasts = [simRows[0].sim_last, stormRows[0].storm_last, accRows[0].acc_last]
    .filter(Boolean).map((d) => new Date(d).getTime());

  return {
    sim_count,
    storm_count,
    accessory_count: acc_count,
    sim_total,
    storm_total,
    accessory_total: acc_total,
    total_spent: sim_total + storm_total + acc_total,
    last_purchase_at: lasts.length ? new Date(Math.max(...lasts)).toISOString() : null,
  };
};

// ─── GET /api/customers/lookup?phone= ────────────────────────────────────────
// Used by the cashier sale flow to detect existing customers by phone.

const lookupByPhone = asyncHandler(async (req, res) => {
  if (!req.query.phone) {
    throw AppError.badRequest('phone is required.', 'VALIDATION_ERROR');
  }
  const phone = normalisePhone(req.query.phone);

  const { rows } = await db.query(
    `SELECT id, phone_number, first_name, last_name, address, profession, notes, created_at
     FROM customers WHERE phone_number = $1`,
    [phone]
  );

  if (!rows[0]) return sendSuccess(res, null);

  const s = await stats(db, rows[0].id);
  sendSuccess(res, { ...rows[0], stats: s });
});

// ─── GET /api/customers ──────────────────────────────────────────────────────
// Admin: search/list customers. Cashiers can also search to assist sales.
// Includes per-customer SIM/storm/accessory counts and total spent.

const listCustomers = asyncHandler(async (req, res) => {
  const { limit, offset } = parsePagination(req.query);
  const params = [];
  const conditions = [];

  if (req.query.q) {
    const q = parseString(req.query.q, 'q', 100);
    params.push(`%${q}%`);
    conditions.push(
      `(c.phone_number ILIKE $${params.length}
        OR (c.first_name || ' ' || c.last_name) ILIKE $${params.length}
        OR c.profession ILIKE $${params.length})`
    );
  }
  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  params.push(limit, offset);

  const { rows } = await db.query(
    `SELECT
       c.id, c.phone_number, c.first_name, c.last_name,
       c.address, c.profession, c.notes, c.created_at, c.updated_at,
       COALESCE(sim_stats.sim_count, 0)            AS sim_count,
       COALESCE(sim_stats.sim_total, 0)            AS sim_total,
       COALESCE(storm_stats.storm_count, 0)        AS storm_count,
       COALESCE(storm_stats.storm_total, 0)        AS storm_total,
       COALESCE(acc_stats.acc_count, 0)            AS accessory_count,
       COALESCE(acc_stats.acc_total, 0)            AS accessory_total,
       GREATEST(
         sim_stats.sim_last,
         storm_stats.storm_last,
         acc_stats.acc_last
       )                                           AS last_purchase_at
     FROM customers c
     LEFT JOIN LATERAL (
       SELECT COUNT(*) FILTER (WHERE is_voided = FALSE)              AS sim_count,
              COALESCE(SUM(selling_price_snapshot)
                       FILTER (WHERE is_voided = FALSE), 0)          AS sim_total,
              MAX(sold_at)                                           AS sim_last
       FROM session_sim_sales WHERE customer_id = c.id
     ) sim_stats ON TRUE
     LEFT JOIN LATERAL (
       SELECT COUNT(*) FILTER (WHERE is_voided = FALSE)              AS storm_count,
              COALESCE(SUM(amount)
                       FILTER (WHERE is_voided = FALSE), 0)          AS storm_total,
              MAX(entered_at)                                        AS storm_last
       FROM session_storm_entries WHERE customer_id = c.id
     ) storm_stats ON TRUE
     LEFT JOIN LATERAL (
       SELECT COUNT(*) FILTER (WHERE is_voided = FALSE)              AS acc_count,
              COALESCE(SUM(price_snapshot)
                       FILTER (WHERE is_voided = FALSE), 0)          AS acc_total,
              MAX(sold_at)                                           AS acc_last
       FROM session_accessory_sales WHERE customer_id = c.id
     ) acc_stats ON TRUE
     ${where}
     ORDER BY c.last_name, c.first_name
     LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params
  );

  sendSuccess(res, rows.map((r) => ({
    ...r,
    sim_count:        parseInt(r.sim_count, 10),
    storm_count:      parseInt(r.storm_count, 10),
    accessory_count:  parseInt(r.accessory_count, 10),
    sim_total:        parseFloat(r.sim_total),
    storm_total:      parseFloat(r.storm_total),
    accessory_total:  parseFloat(r.accessory_total),
    total_spent:      parseFloat(r.sim_total) + parseFloat(r.storm_total) + parseFloat(r.accessory_total),
  })));
});

// ─── GET /api/customers/:id ──────────────────────────────────────────────────

const getCustomer = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const { rows } = await db.query(
    `SELECT id, phone_number, first_name, last_name, address, profession, notes, created_at, updated_at
     FROM customers WHERE id = $1`,
    [id]
  );
  if (!rows[0]) throw AppError.notFound('Customer not found.');

  const customerStats = await stats(db, id);
  sendSuccess(res, { ...rows[0], stats: customerStats });
});

// ─── GET /api/customers/:id/purchases?type=sim|storm|accessory ───────────────
// Returns the customer's purchase history for the requested category.
// Cashier and admin can both call this (cashier only their own customers in
// future if needed; for now scoped read access is fine).

const getCustomerPurchases = asyncHandler(async (req, res) => {
  const id   = parseId(req.params.id);
  const type = req.query.type;

  if (!['sim', 'storm', 'accessory'].includes(type)) {
    throw AppError.badRequest('type must be "sim", "storm", or "accessory".', 'VALIDATION_ERROR');
  }

  const { rows: c } = await db.query(`SELECT id FROM customers WHERE id = $1`, [id]);
  if (!c[0]) throw AppError.notFound('Customer not found.');

  let query;
  if (type === 'sim') {
    query = `SELECT s.id, s.sold_at AS at, s.serial_number_snapshot AS serial,
                    s.offer_name_snapshot AS label,
                    s.selling_price_snapshot AS amount,
                    s.points_snapshot AS points,
                    s.is_voided, s.void_reason,
                    u.full_name AS cashier_name, st.name AS store_name
             FROM session_sim_sales s
             JOIN cashier_sessions cs ON cs.id = s.session_id
             JOIN users u  ON u.id  = cs.cashier_id
             JOIN stores st ON st.id = cs.store_id
             WHERE s.customer_id = $1
             ORDER BY s.sold_at DESC
             LIMIT 200`;
  } else if (type === 'storm') {
    query = `SELECT e.id, e.entered_at AS at, e.note AS label, e.amount,
                    e.is_voided, e.void_reason,
                    u.full_name AS cashier_name, st.name AS store_name
             FROM session_storm_entries e
             JOIN cashier_sessions cs ON cs.id = e.session_id
             JOIN users u  ON u.id  = cs.cashier_id
             JOIN stores st ON st.id = cs.store_id
             WHERE e.customer_id = $1
             ORDER BY e.entered_at DESC
             LIMIT 200`;
  } else {
    query = `SELECT a.id, a.sold_at AS at, a.product_name_snapshot AS label,
                    a.category_name_snapshot AS category,
                    a.price_snapshot AS amount,
                    a.real_price_snapshot AS real_price,
                    a.is_voided, a.void_reason,
                    u.full_name AS cashier_name, st.name AS store_name
             FROM session_accessory_sales a
             JOIN cashier_sessions cs ON cs.id = a.session_id
             JOIN users u  ON u.id  = cs.cashier_id
             JOIN stores st ON st.id = cs.store_id
             WHERE a.customer_id = $1
             ORDER BY a.sold_at DESC
             LIMIT 200`;
  }

  const { rows } = await db.query(query, [id]);
  sendSuccess(res, rows);
});

// ─── POST /api/customers ─────────────────────────────────────────────────────
// Body: { phone_number, first_name, last_name, address, profession, notes? }

const createCustomer = asyncHandler(async (req, res) => {
  requireFields(req.body, ['phone_number', 'first_name', 'last_name', 'address', 'profession']);

  const phone      = normalisePhone(req.body.phone_number);
  const firstName  = parseString(req.body.first_name, 'first_name', 100);
  const lastName   = parseString(req.body.last_name, 'last_name', 100);
  const address    = parseString(req.body.address, 'address', 500);
  const profession = parseString(req.body.profession, 'profession', 100);
  const notes      = req.body.notes ? parseString(req.body.notes, 'notes', 1000) : null;

  try {
    const { rows } = await db.query(
      `INSERT INTO customers (phone_number, first_name, last_name, address, profession, notes, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [phone, firstName, lastName, address, profession, notes, req.user.id]
    );

    audit({
      userId:    req.user.id,
      action:    'INSERT',
      table:     'customers',
      recordId:  rows[0].id,
      newValues: { phone, first_name: firstName, last_name: lastName },
      ip:        req.clientIp,
    });

    sendCreated(res, rows[0], 'Customer created.');
  } catch (err) {
    if (err.code === '23505') {
      throw AppError.conflict(
        `A customer with phone ${phone} already exists.`,
        'CUSTOMER_PHONE_EXISTS'
      );
    }
    throw err;
  }
});

// ─── PATCH /api/customers/:id ────────────────────────────────────────────────

const updateCustomer = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);

  const { rows: existingRows } = await db.query('SELECT * FROM customers WHERE id = $1', [id]);
  if (!existingRows[0]) throw AppError.notFound('Customer not found.');
  const prev = existingRows[0];

  const updates = {};
  if (req.body.phone_number !== undefined)
    updates.phone_number = normalisePhone(req.body.phone_number);
  if (req.body.first_name !== undefined)
    updates.first_name = parseString(req.body.first_name, 'first_name', 100);
  if (req.body.last_name !== undefined)
    updates.last_name = parseString(req.body.last_name, 'last_name', 100);
  if (req.body.address !== undefined)
    updates.address = parseString(req.body.address, 'address', 500);
  if (req.body.profession !== undefined)
    updates.profession = parseString(req.body.profession, 'profession', 100);
  if (req.body.notes !== undefined)
    updates.notes = req.body.notes ? parseString(req.body.notes, 'notes', 1000) : null;

  if (Object.keys(updates).length === 0) {
    throw AppError.badRequest('No updateable fields provided.', 'VALIDATION_ERROR');
  }

  const setClauses = Object.keys(updates).map((k, i) => `${k} = $${i + 2}`);
  const values     = [id, ...Object.values(updates)];

  try {
    const { rows } = await db.query(
      `UPDATE customers SET ${setClauses.join(', ')}, updated_at = NOW()
       WHERE id = $1 RETURNING *`,
      values
    );

    audit({
      userId:    req.user.id,
      action:    'UPDATE',
      table:     'customers',
      recordId:  id,
      oldValues: prev,
      newValues: updates,
      ip:        req.clientIp,
    });

    sendSuccess(res, rows[0], 200, 'Customer updated.');
  } catch (err) {
    if (err.code === '23505') {
      throw AppError.conflict('Phone number already used by another customer.', 'CUSTOMER_PHONE_EXISTS');
    }
    throw err;
  }
});

// ─── DELETE /api/customers/:id  (admin only) ─────────────────────────────────
// Removes the customer permanently. The session_sim_sales.customer_id FK has
// ON DELETE SET NULL, so historical sales are preserved with their snapshot
// data — only the loyalty link is severed.

const deleteCustomer = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);

  const { rows } = await db.query(
    `SELECT id, phone_number, first_name, last_name FROM customers WHERE id = $1`,
    [id]
  );
  if (!rows[0]) throw AppError.notFound('Customer not found.');

  // Count linked sales for the audit trail
  const { rows: countRows } = await db.query(
    `SELECT COUNT(*)::int AS sale_count FROM session_sim_sales WHERE customer_id = $1`,
    [id]
  );
  const saleCount = countRows[0].sale_count;

  await db.query(`DELETE FROM customers WHERE id = $1`, [id]);

  audit({
    userId:    req.user.id,
    action:    'DELETE',
    table:     'customers',
    recordId:  id,
    oldValues: rows[0],
    description: `Deleted customer ${rows[0].first_name} ${rows[0].last_name} (${rows[0].phone_number}) — ${saleCount} historical sale(s) unlinked`,
    ip:        req.clientIp,
  });

  sendSuccess(res, { unlinked_sales: saleCount }, 200,
    `Customer "${rows[0].first_name} ${rows[0].last_name}" deleted.`);
});

module.exports = {
  lookupByPhone, listCustomers, getCustomer, getCustomerPurchases,
  createCustomer, updateCustomer, deleteCustomer,
};
