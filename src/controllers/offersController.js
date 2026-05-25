'use strict';

const db       = require('../config/db');
const AppError = require('../utils/AppError');
const { asyncHandler, sendSuccess, sendCreated } = require('../utils/asyncHandler');
const { audit } = require('../utils/audit');
const {
  requireFields, parseId, parseString,
  parsePositiveNumber, parsePositiveInt
} = require('../utils/validators');

// ─── GET /api/offers/categories  (any authenticated user) ──────────────────

const listCategories = asyncHandler(async (req, res) => {
  const { rows } = await db.query(
    `SELECT id, name, sort_order, is_active
     FROM offer_categories
     WHERE is_active = TRUE
     ORDER BY sort_order, name`
  );
  sendSuccess(res, rows);
});

// ─── GET /api/offers  (cashier + admin) ─────────────────────────────────────

const listOffers = asyncHandler(async (req, res) => {
  const activeOnly = req.user.role === 'cashier';
  const params = [];
  const conditions = [];
  if (activeOnly) conditions.push('o.is_active = TRUE');
  if (req.query.category_id) {
    params.push(parseId(req.query.category_id, 'category_id'));
    conditions.push(`o.category_id = $${params.length}`);
  }
  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

  const { rows } = await db.query(
    `SELECT o.id, o.name, o.real_price, o.selling_price, o.points,
            o.commission_amount, o.low_stock_threshold, o.is_active, o.sort_order,
            o.category_id, oc.name AS category_name
     FROM offers o
     LEFT JOIN offer_categories oc ON oc.id = o.category_id
     ${where}
     ORDER BY oc.sort_order, o.sort_order, o.selling_price, o.name`,
    params
  );
  sendSuccess(res, rows);
});

// ─── GET /api/offers/:id ─────────────────────────────────────────────────────

const getOffer = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);

  const { rows } = await db.query(
    'SELECT * FROM offers WHERE id = $1', [id]
  );
  if (!rows[0]) throw AppError.notFound('Offer not found.');
  sendSuccess(res, rows[0]);
});

// ─── POST /api/offers  (admin only) ─────────────────────────────────────────

const createOffer = asyncHandler(async (req, res) => {
  requireFields(req.body, ['name', 'real_price', 'selling_price', 'category_id']);

  const name              = parseString(req.body.name, 'name', 100);
  const category_id       = parseId(req.body.category_id, 'category_id');
  const real_price        = parsePositiveNumber(req.body.real_price, 'real_price', true);
  const selling_price     = parsePositiveNumber(req.body.selling_price, 'selling_price', true);
  const points            = parsePositiveInt(req.body.points ?? 0, 'points', true);
  const commission_amount = parsePositiveNumber(req.body.commission_amount ?? 0, 'commission_amount', true);
  const low_stock_threshold = parsePositiveInt(req.body.low_stock_threshold ?? 5, 'low_stock_threshold', true);
  const sort_order        = parseInt(req.body.sort_order ?? 0, 10);

  // Validate category exists
  const { rows: catRows } = await db.query(
    'SELECT id FROM offer_categories WHERE id = $1 AND is_active = TRUE', [category_id]
  );
  if (!catRows[0]) throw AppError.badRequest('Invalid category_id.', 'VALIDATION_ERROR');

  const { rows } = await db.query(
    `INSERT INTO offers
       (name, category_id, real_price, selling_price, points,
        commission_amount, low_stock_threshold, sort_order)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING *`,
    [name, category_id, real_price, selling_price, points, commission_amount, low_stock_threshold, sort_order]
  );

  audit({
    userId:    req.user.id,
    action:    'INSERT',
    table:     'offers',
    recordId:  rows[0].id,
    newValues: rows[0],
    ip:        req.clientIp,
  });

  sendCreated(res, rows[0], 'Offer created.');
});

// ─── PATCH /api/offers/:id  (admin only) ─────────────────────────────────────

const updateOffer = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);

  const { rows: existing } = await db.query('SELECT * FROM offers WHERE id = $1', [id]);
  if (!existing[0]) throw AppError.notFound('Offer not found.');

  const prev    = existing[0];
  const allowed = [
    'name', 'category_id', 'real_price', 'selling_price', 'points',
    'commission_amount', 'low_stock_threshold', 'is_active', 'sort_order',
  ];

  const updates = {};
  for (const key of allowed) {
    if (req.body[key] !== undefined) updates[key] = req.body[key];
  }
  if (Object.keys(updates).length === 0) {
    throw AppError.badRequest('No updateable fields provided.', 'VALIDATION_ERROR');
  }

  const setClauses = Object.keys(updates).map((k, i) => `${k} = $${i + 2}`);
  const { rows }   = await db.query(
    `UPDATE offers SET ${setClauses.join(', ')}, updated_at = NOW()
     WHERE id = $1 RETURNING *`,
    [id, ...Object.values(updates)]
  );

  audit({
    userId:    req.user.id,
    action:    'UPDATE',
    table:     'offers',
    recordId:  id,
    oldValues: prev,
    newValues: updates,
    ip:        req.clientIp,
  });

  sendSuccess(res, rows[0], 200, 'Offer updated.');
});

// ─── DELETE /api/offers/:id  (admin only — soft delete) ──────────────────────

const deleteOffer = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);

  const { rows } = await db.query(
    `UPDATE offers SET is_active = FALSE, updated_at = NOW()
     WHERE id = $1 AND is_active = TRUE RETURNING id, name`,
    [id]
  );
  if (!rows[0]) throw AppError.notFound('Offer not found or already inactive.');

  audit({
    userId:    req.user.id,
    action:    'DELETE',
    table:     'offers',
    recordId:  id,
    newValues: { is_active: false },
    ip:        req.clientIp,
  });

  sendSuccess(res, null, 200, `Offer "${rows[0].name}" deactivated.`);
});

// ─── POST /api/offers/:id/restore  (admin only) ──────────────────────────────

const restoreOffer = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);

  const { rows } = await db.query(
    `UPDATE offers SET is_active = TRUE, updated_at = NOW()
     WHERE id = $1 AND is_active = FALSE RETURNING *`,
    [id]
  );
  if (!rows[0]) throw AppError.notFound('Offer not found or already active.');

  audit({
    userId:    req.user.id,
    action:    'UPDATE',
    table:     'offers',
    recordId:  id,
    oldValues: { is_active: false },
    newValues: { is_active: true },
    ip:        req.clientIp,
  });

  sendSuccess(res, rows[0], 200, `Offer "${rows[0].name}" restored.`);
});

// ─── DELETE /api/offers/:id/permanent  (admin only — hard delete) ────────────

const permanentDeleteOffer = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);

  const { rows: checkRows } = await db.query(
    `SELECT id, name, is_active FROM offers WHERE id = $1`,
    [id]
  );
  if (!checkRows[0]) throw AppError.notFound('Offer not found.');
  if (checkRows[0].is_active) {
    throw AppError.badRequest(
      'Deactivate the offer first, then delete permanently.',
      'MUST_DEACTIVATE_FIRST'
    );
  }

  try {
    await db.query(`DELETE FROM offers WHERE id = $1`, [id]);
  } catch (err) {
    if (err.code === '23503') {
      throw AppError.unprocessable(
        'Cannot delete: this offer has historical sales or assigned SIM cards. It must remain deactivated.',
        'REFERENCED_ROW'
      );
    }
    throw err;
  }

  audit({
    userId:    req.user.id,
    action:    'DELETE',
    table:     'offers',
    recordId:  id,
    description: `Permanently deleted offer "${checkRows[0].name}"`,
    ip:        req.clientIp,
  });

  sendSuccess(res, null, 200, `Offer "${checkRows[0].name}" permanently deleted.`);
});

module.exports = { listOffers, listCategories, getOffer, createOffer, updateOffer, deleteOffer, restoreOffer, permanentDeleteOffer };
