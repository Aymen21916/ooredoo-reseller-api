'use strict';

const db = require('../config/db');
const AppError = require('../utils/AppError');
const { asyncHandler, sendCreated, sendSuccess } = require('../utils/asyncHandler');
const { audit } = require('../utils/audit');
const {
  requireFields,
  parseId,
  parsePositiveNumber,
  validateAmount,
  validateVoidReason,
} = require('../utils/validators');

// ─── HELPER: Assert Session Ownership ────────────────────────────────────────

/** Ensures the session exists, is open, and belongs to the authenticated cashier. */
const resolveActiveSession = async (sessionId, cashierId, client = db) => {
  const { rows } = await client.query(
    `SELECT * FROM cashier_sessions WHERE id = $1`, [sessionId]
  );
  
  const session = rows[0];
  if (!session) throw AppError.notFound('Session not found.');
  if (session.cashier_id !== cashierId) throw AppError.forbidden('You do not own this session.');
  if (session.status !== 'open') throw AppError.conflict('Cannot add sales to a closed session.', 'SESSION_CLOSED');
  
  return session;
};

// ─── POST /api/sales/sim ─────────────────────────────────────────────────────
// Body: { session_id, offer_id, customer_id }
// The cashier picks an offer and an existing/new customer (handled by the
// frontend before calling this endpoint).

const recordSimSale = asyncHandler(async (req, res) => {
  requireFields(req.body, ['session_id', 'offer_id', 'customer_id']);
  const sessionId  = parseId(req.body.session_id, 'session_id');
  const offerId    = parseId(req.body.offer_id, 'offer_id');
  const customerId = parseId(req.body.customer_id, 'customer_id');

  const result = await db.withTransaction(async (client) => {
    await resolveActiveSession(sessionId, req.user.id, client);

    // 1. Verify customer exists
    const { rows: customerRows } = await client.query(
      `SELECT id, first_name, last_name FROM customers WHERE id = $1`,
      [customerId]
    );
    if (!customerRows[0]) throw AppError.notFound('Customer not found.');

    // 2. Verify offer exists and grab snapshot data
    const { rows: offerRows } = await client.query(
      `SELECT name, real_price, selling_price, points, commission_amount, is_active
       FROM offers WHERE id = $1 FOR SHARE`,
      [offerId]
    );
    const offer = offerRows[0];
    if (!offer) throw AppError.notFound('Offer not found.');
    if (!offer.is_active) throw AppError.badRequest('This offer is currently inactive.');

    // 3. Pull the next available SIM card for this cashier (FIFO by serial).
    //    SIM cards are generic — the offer is decided at sale time.
    //    FOR UPDATE SKIP LOCKED prevents two concurrent sales from grabbing
    //    the same card.
    const { rows: cardRows } = await client.query(
      `SELECT id, serial_number
       FROM sim_cards
       WHERE cashier_id = $1 AND status = 'available'
       ORDER BY serial_number
       LIMIT 1 FOR UPDATE SKIP LOCKED`,
      [req.user.id]
    );
    const card = cardRows[0];
    if (!card) {
      throw AppError.conflict(
        'No available SIM cards in your inventory. Ask the admin to assign more.',
        'OUT_OF_STOCK'
      );
    }

    // 4. Mark the card as sold
    await client.query(
      `UPDATE sim_cards SET status = 'sold', sold_at = NOW() WHERE id = $1`,
      [card.id]
    );

    // 5. Insert the sale with snapshotted prices, the consumed serial, and customer
    const { rows } = await client.query(
      `INSERT INTO session_sim_sales
        (session_id, offer_id, customer_id, sim_card_id, serial_number_snapshot,
         offer_name_snapshot, real_price_snapshot,
         selling_price_snapshot, points_snapshot, commission_snapshot)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       RETURNING *`,
      [
        sessionId, offerId, customerId, card.id, card.serial_number,
        offer.name, offer.real_price, offer.selling_price,
        offer.points, offer.commission_amount,
      ]
    );

    audit({
      userId:    req.user.id,
      action:    'INSERT',
      table:     'session_sim_sales',
      recordId:  rows[0].id,
      newValues: { serial_number: card.serial_number, offer_id: offerId, customer_id: customerId },
      ip:        req.clientIp,
    });

    return {
      ...rows[0],
      customer_name: `${customerRows[0].first_name} ${customerRows[0].last_name}`,
    };
  });

  sendCreated(res, result, 'SIM sale recorded.');
});

// ─── POST /api/sales/storm ───────────────────────────────────────────────────

const recordStormEntry = asyncHandler(async (req, res) => {
  requireFields(req.body, ['session_id', 'amount', 'customer_id']);
  const sessionId  = parseId(req.body.session_id, 'session_id');
  const customerId = parseId(req.body.customer_id, 'customer_id');
  const amount     = parsePositiveNumber(req.body.amount, 'amount');
  const note       = req.body.note ? String(req.body.note).trim().slice(0, 500) : null;

  const { rows } = await db.withTransaction(async (client) => {
    await resolveActiveSession(sessionId, req.user.id, client);

    const { rows: customerRows } = await client.query(
      `SELECT id FROM customers WHERE id = $1`, [customerId]
    );
    if (!customerRows[0]) throw AppError.notFound('Customer not found.');

    return client.query(
      `INSERT INTO session_storm_entries (session_id, customer_id, amount, note)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [sessionId, customerId, amount, note]
    );
  });

  audit({ userId: req.user.id, action: 'INSERT', table: 'session_storm_entries', recordId: rows[0].id, ip: req.clientIp });
  sendCreated(res, rows[0], 'Storm entry recorded.');
});

// ─── POST /api/sales/accessory ───────────────────────────────────────────────

const recordAccessorySale = asyncHandler(async (req, res) => {
  requireFields(req.body, ['session_id', 'product_id', 'customer_id']);
  const sessionId  = parseId(req.body.session_id, 'session_id');
  const productId  = parseId(req.body.product_id, 'product_id');
  const customerId = parseId(req.body.customer_id, 'customer_id');

  const result = await db.withTransaction(async (client) => {
    await resolveActiveSession(sessionId, req.user.id, client);

    const { rows: customerRows } = await client.query(
      `SELECT id FROM customers WHERE id = $1`, [customerId]
    );
    if (!customerRows[0]) throw AppError.notFound('Customer not found.');

    const { rows: prodRows } = await client.query(
      `SELECT p.name as product_name, p.price, p.real_price, p.commission_amount, p.is_active, pc.name as category_name
       FROM products p
       JOIN product_categories pc ON pc.id = p.category_id
       WHERE p.id = $1`,
      [productId]
    );
    const prod = prodRows[0];
    if (!prod) throw AppError.notFound('Product not found.');
    if (!prod.is_active) throw AppError.badRequest('Product is inactive.');

    const { rows } = await client.query(
      `INSERT INTO session_accessory_sales
        (session_id, product_id, customer_id, product_name_snapshot, category_name_snapshot,
         price_snapshot, real_price_snapshot, commission_snapshot)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [sessionId, productId, customerId, prod.product_name, prod.category_name,
       prod.price, prod.real_price, prod.commission_amount]
    );
    return rows[0];
  });

  audit({ userId: req.user.id, action: 'INSERT', table: 'session_accessory_sales', recordId: result.id, ip: req.clientIp });
  sendCreated(res, result, 'Accessory sale recorded.');
});

// ─── POST /api/sales/debt ────────────────────────────────────────────────────
// Body: { session_id?, customer_id?, phone_number?, amount, description? }
//
// Customer link is mandatory (Req 1.7, 1.8, 1.10): the caller MUST supply
// either `customer_id` or, for the existing-customer-by-phone path used by
// the new debt modal, a `phone_number` that resolves to an existing
// customer. Sending neither yields `CUSTOMER_REQUIRED` (HTTP 400).
//
// We re-validate the cashier's open session here (rather than reusing
// `resolveActiveSession`) so any session-state failure surfaces as the
// NO_OPEN_SESSION (HTTP 400) error code mandated by Req 1.6.

const recordDebt = asyncHandler(async (req, res) => {
  // ── 1. Mandatory customer link ─────────────────────────────────────────
  const rawCustomerId  = req.body.customer_id;
  const rawPhoneNumber = req.body.phone_number;
  const hasCustomerId  =
    rawCustomerId !== undefined && rawCustomerId !== null && rawCustomerId !== '';
  const hasPhone       =
    typeof rawPhoneNumber === 'string' && rawPhoneNumber.trim().length > 0;

  if (!hasCustomerId && !hasPhone) {
    throw AppError.badRequest(
      'A linked customer is required for every debt.',
      'CUSTOMER_REQUIRED'
    );
  }

  // ── 2. Amount + optional description (post-trim, length-bounded) ──────
  const amount = validateAmount(req.body.amount, {
    min: 0.01,
    max: 9999999999.99,
    decimals_allowed: 2,
    fieldName: 'amount',
  });

  let description = null;
  if (req.body.description !== undefined && req.body.description !== null) {
    if (typeof req.body.description !== 'string') {
      throw AppError.badRequest(
        '"description" must be a string of at most 1000 characters.',
        'VALIDATION_ERROR'
      );
    }
    const trimmed = req.body.description.trim();
    if (trimmed.length > 1000) {
      throw AppError.badRequest(
        '"description" must be at most 1000 characters after trimming.',
        'VALIDATION_ERROR'
      );
    }
    description = trimmed.length === 0 ? null : trimmed;
  }

  const result = await db.withTransaction(async (client) => {
    // ── 3. Cashier MUST have exactly one open session ───────────────────
    const { rows: sessionRows } = await client.query(
      `SELECT id FROM cashier_sessions
        WHERE cashier_id = $1 AND status = 'open'
        ORDER BY id DESC
        LIMIT 1`,
      [req.user.id]
    );
    const openSession = sessionRows[0];
    if (!openSession) {
      throw AppError.badRequest(
        'You have no open cashier session.',
        'NO_OPEN_SESSION'
      );
    }

    // If the client passed a session_id, it must match the cashier's open
    // one. Any mismatch (closed, foreign, non-existent) is treated as the
    // same NO_OPEN_SESSION condition per Req 1.6.
    if (req.body.session_id !== undefined && req.body.session_id !== null && req.body.session_id !== '') {
      const claimed = parseId(req.body.session_id, 'session_id');
      if (claimed !== openSession.id) {
        throw AppError.badRequest(
          'You have no open cashier session.',
          'NO_OPEN_SESSION'
        );
      }
    }

    // ── 4. Resolve the linked customer ──────────────────────────────────
    // Prefer customer_id when supplied; otherwise fall back to phone-only
    // resolution (existing-customer path from the modal).
    let customer = null;

    if (hasCustomerId) {
      const customerId = parseId(rawCustomerId, 'customer_id');
      const { rows } = await client.query(
        `SELECT id, first_name, last_name FROM customers WHERE id = $1`,
        [customerId]
      );
      customer = rows[0] || null;
    } else {
      // Phone-only payload — re-use existing record rather than create a
      // duplicate (Req 1.4). Defer creation flow to the dedicated
      // `customersController.createCustomer` endpoint.
      const phone = rawPhoneNumber.trim();
      const { rows } = await client.query(
        `SELECT id, first_name, last_name FROM customers WHERE phone_number = $1`,
        [phone]
      );
      customer = rows[0] || null;
    }

    if (!customer) {
      throw AppError.notFound('Customer not found.', 'CUSTOMER_NOT_FOUND');
    }

    // ── 5. Insert the debt row ──────────────────────────────────────────
    const { rows: insertRows } = await client.query(
      `INSERT INTO session_debts (session_id, customer_id, amount, description)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [openSession.id, customer.id, amount, description]
    );
    const debtRow = insertRows[0];

    return {
      ...debtRow,
      customer_name: `${customer.first_name} ${customer.last_name}`,
    };
  });

  // ── 6. Fire-and-forget audit log (Req 1.14) ──────────────────────────
  audit({
    userId:    req.user.id,
    action:    'INSERT',
    table:     'session_debts',
    recordId:  result.id,
    newValues: {
      customer_id: result.customer_id,
      session_id:  result.session_id,
      amount:      result.amount,
    },
    ip:        req.clientIp,
  });

  sendCreated(res, result, 'Debt recorded.');
});

// Add this new function to fetch history
const getSessionHistory = asyncHandler(async (req, res) => {
  const sessionId = req.params.sessionId;

  // Use a UNION ALL to combine all 4 sales tables into one chronological feed
  const { rows } = await db.query(`
    SELECT 'sim' as type, id, offer_name_snapshot as description, selling_price_snapshot as amount, sold_at AS created_at, is_voided
    FROM session_sim_sales WHERE session_id = $1
    UNION ALL
    SELECT 'storm' as type, id, COALESCE(note, 'Storm / Bundle') as description, amount, entered_at AS created_at, is_voided
    FROM session_storm_entries WHERE session_id = $1
    UNION ALL
    SELECT 'accessory' as type, id, product_name_snapshot as description, price_snapshot as amount, sold_at AS created_at, is_voided
    FROM session_accessory_sales WHERE session_id = $1
    UNION ALL
    SELECT 'debt' as type, id, COALESCE(description, 'Client Debt') as description, amount, entered_at AS created_at, is_voided
    FROM session_debts WHERE session_id = $1
    ORDER BY created_at DESC
    LIMIT 50
  `, [sessionId]);

  res.json({ success: true, data: rows });
});

// Void a transaction with ownership check, full void metadata, and audit.
//
// For debt rows (Req 1.13, 1.14):
//   - The customer link on `session_debts.customer_id` is preserved by
//     simply not touching that column during the soft-void update — the
//     audit row records it under `old_values` so the link is reconstructible.
//   - Already-voided rows are rejected with HTTP 409 / `ALREADY_VOIDED`.
//   - `void_reason` is validated through the shared helper, which emits
//     `MISSING_VOID_REASON` (when absent) or `INVALID_VOID_REASON` (when
//     present but malformed/out-of-bounds).
const voidTransaction = asyncHandler(async (req, res) => {
  const { type, id } = req.params;
  const tableMap = {
    sim: 'session_sim_sales',
    storm: 'session_storm_entries',
    accessory: 'session_accessory_sales',
    debt: 'session_debts',
  };
  const table = tableMap[type];
  if (!table) throw AppError.badRequest('Invalid transaction type.', 'VALIDATION_ERROR');

  const transactionId = parseId(id, 'id');

  // Validate void_reason via the shared helper (1..500 chars after trim).
  const reason = validateVoidReason(req.body && req.body.reason);

  // Pull the row first WITHOUT the is_voided filter so we can distinguish
  // "row not found" (404) from "row exists but already voided" (409).
  // We also widen the projection so the debt path can carry `customer_id`
  // into the audit log without an extra query.
  const extraSelect =
    type === 'sim'  ? ', t.sim_card_id'
  : type === 'debt' ? ', t.customer_id, t.amount'
  : '';

  const oldValues = await db.withTransaction(async (client) => {
    const { rows } = await client.query(
      `SELECT t.id, t.session_id, t.is_voided, cs.cashier_id${extraSelect}
         FROM ${table} t
         JOIN cashier_sessions cs ON cs.id = t.session_id
        WHERE t.id = $1`,
      [transactionId]
    );
    const row = rows[0];
    if (!row) throw AppError.notFound('Transaction not found.');
    if (row.cashier_id !== req.user.id) throw AppError.forbidden('Not your transaction.');
    if (row.is_voided) {
      throw AppError.conflict('Transaction is already voided.', 'ALREADY_VOIDED');
    }

    await client.query(
      `UPDATE ${table}
          SET is_voided = TRUE, voided_at = NOW(),
              voided_by = $1, void_reason = $2
        WHERE id = $3`,
      [req.user.id, reason, transactionId]
    );

    // If we're voiding a SIM sale, return the physical card to inventory
    if (type === 'sim' && row.sim_card_id) {
      await client.query(
        `UPDATE sim_cards SET status = 'available', sold_at = NULL WHERE id = $1`,
        [row.sim_card_id]
      );
    }

    // Build the audit `old_values` payload with whatever identifying
    // fields we projected for this transaction type. For debts this
    // includes `customer_id` per Req 1.14.
    const payload = { session_id: row.session_id };
    if (type === 'debt') {
      payload.customer_id = row.customer_id;
      payload.amount      = row.amount;
    }
    return payload;
  });

  audit({
    userId:    req.user.id,
    action:    'VOID',
    table,
    recordId:  transactionId,
    oldValues,
    ip:        req.clientIp,
  });

  sendSuccess(res, null, 200, 'Transaction voided.');
});

// Don't forget to export them at the bottom!
module.exports = { recordSimSale, recordStormEntry, recordAccessorySale, recordDebt, getSessionHistory, voidTransaction };
