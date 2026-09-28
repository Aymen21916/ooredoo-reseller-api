'use strict';

const db       = require('../config/db');
const AppError = require('../utils/AppError');
const { asyncHandler, sendSuccess, sendCreated } = require('../utils/asyncHandler');
const { audit } = require('../utils/audit');
const { requireFields, parseId, parseString, parsePositiveNumber, parsePositiveInt } = require('../utils/validators');

const listCategories = asyncHandler(async (req, res) => {
  const { rows } = await db.query('SELECT id, name, sort_order, is_active FROM offer_categories WHERE is_active = TRUE ORDER BY sort_order, name');
  sendSuccess(res, rows);
});

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
    `SELECT o.id, o.name, o.real_price, o.selling_price, o.commission_points, o.loyalty_points,
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

const getOffer = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const { rows } = await db.query('SELECT * FROM offers WHERE id = $1', [id]);
  if (!rows[0]) throw AppError.notFound('Offer not found.');
  sendSuccess(res, rows[0]);
});

const createOffer = asyncHandler(async (req, res) => {
  requireFields(req.body, ['name', 'real_price', 'selling_price', 'category_id']);

  const name              = parseString(req.body.name, 'name', 100);
  const category_id       = parseId(req.body.category_id, 'category_id');
  const real_price        = parsePositiveNumber(req.body.real_price, 'real_price', true);
  const selling_price     = parsePositiveNumber(req.body.selling_price, 'selling_price', true);
  const commission_points = parsePositiveNumber(req.body.commission_points ?? 0, 'commission_points', true);
  const loyalty_points    = parsePositiveNumber(req.body.loyalty_points ?? 0, 'loyalty_points', true);
  const commission_amount = parsePositiveNumber(req.body.commission_amount ?? 0, 'commission_amount', true);
  const low_stock_threshold = parsePositiveInt(req.body.low_stock_threshold ?? 5, 'low_stock_threshold', true);
  const sort_order        = parseInt(req.body.sort_order ?? 0, 10);

  const { rows: catRows } = await db.query('SELECT id FROM offer_categories WHERE id = $1 AND is_active = TRUE', [category_id]);
  if (!catRows[0]) throw AppError.badRequest('Invalid category_id.', 'VALIDATION_ERROR');

  const { rows } = await db.query(
    `INSERT INTO offers (name, category_id, real_price, selling_price, commission_points, loyalty_points, commission_amount, low_stock_threshold, sort_order)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
    [name, category_id, real_price, selling_price, commission_points, loyalty_points, commission_amount, low_stock_threshold, sort_order]
  );

  audit({ userId: req.user.id, action: 'INSERT', table: 'offers', recordId: rows[0].id, newValues: rows[0], ip: req.clientIp });
  sendCreated(res, rows[0], 'Offer created.');
});

const updateOffer = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const { rows: existing } = await db.query('SELECT * FROM offers WHERE id = $1', [id]);
  if (!existing[0]) throw AppError.notFound('Offer not found.');

  const allowed = ['name', 'category_id', 'real_price', 'selling_price', 'commission_points', 'loyalty_points', 'commission_amount', 'low_stock_threshold', 'is_active', 'sort_order'];
  const updates = {};
  for (const key of allowed) if (req.body[key] !== undefined) updates[key] = req.body[key];
  if (Object.keys(updates).length === 0) throw AppError.badRequest('No updateable fields provided.', 'VALIDATION_ERROR');

  const setClauses = Object.keys(updates).map((k, i) => `${k} = $${i + 2}`);
  const { rows } = await db.query(`UPDATE offers SET ${setClauses.join(', ')}, updated_at = NOW() WHERE id = $1 RETURNING *`, [id, ...Object.values(updates)]);

  audit({ userId: req.user.id, action: 'UPDATE', table: 'offers', recordId: id, oldValues: existing[0], newValues: updates, ip: req.clientIp });
  sendSuccess(res, rows[0], 200, 'Offer updated.');
});

const deleteOffer = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const { rows } = await db.query(`UPDATE offers SET is_active = FALSE, updated_at = NOW() WHERE id = $1 AND is_active = TRUE RETURNING id, name`, [id]);
  if (!rows[0]) throw AppError.notFound('Offer not found or already inactive.');
  sendSuccess(res, null, 200, `Offer "${rows[0].name}" deactivated.`);
});

const restoreOffer = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const { rows } = await db.query(`UPDATE offers SET is_active = TRUE, updated_at = NOW() WHERE id = $1 AND is_active = FALSE RETURNING *`, [id]);
  if (!rows[0]) throw AppError.notFound('Offer not found or already active.');
  sendSuccess(res, rows[0], 200, `Offer "${rows[0].name}" restored.`);
});

const permanentDeleteOffer = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const { rows: checkRows } = await db.query(`SELECT id, name, is_active FROM offers WHERE id = $1`, [id]);
  if (!checkRows[0]) throw AppError.notFound('Offer not found.');
  if (checkRows[0].is_active) throw AppError.badRequest('Deactivate the offer first, then delete permanently.', 'MUST_DEACTIVATE_FIRST');
  try { await db.query(`DELETE FROM offers WHERE id = $1`, [id]); } 
  catch (err) { throw AppError.unprocessable('Cannot delete: this offer has historical sales. It must remain deactivated.', 'REFERENCED_ROW'); }
  sendSuccess(res, null, 200, `Offer "${checkRows[0].name}" permanently deleted.`);
});

const createCategory = asyncHandler(async (req, res) => {
  requireFields(req.body, ['name']);
  const name = parseString(req.body.name, 'name', 50);
  const sortOrder = parseInt(req.body.sort_order ?? 0, 10);
  const { rows: existing } = await db.query('SELECT id, name, is_active FROM offer_categories WHERE name = $1', [name]);

  let categoryRow;
  if (existing.length > 0) {
    if (existing[0].is_active) throw AppError.badRequest(`The category "${name}" already exists.`, 'ALREADY_EXISTS');
    const { rows: restored } = await db.query(`UPDATE offer_categories SET is_active = TRUE, sort_order = $2 WHERE id = $1 RETURNING id, name, sort_order, is_active`, [existing[0].id, sortOrder]);
    categoryRow = restored[0];
  } else {
    const { rows: inserted } = await db.query(`INSERT INTO offer_categories (name, sort_order) VALUES ($1, $2) RETURNING id, name, sort_order, is_active`, [name, sortOrder]);
    categoryRow = inserted[0];
  }
  sendCreated(res, categoryRow, 'Category created successfully.');
});

const deleteCategory = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const { rows: offerRows } = await db.query('SELECT id FROM offers WHERE category_id = $1 LIMIT 1', [id]);
  if (offerRows.length > 0) throw AppError.badRequest('Cannot delete this category because it is used by offers.');
  const { rows } = await db.query(`UPDATE offer_categories SET is_active = FALSE WHERE id = $1 AND is_active = TRUE RETURNING id, name`, [id]);
  if (!rows[0]) throw AppError.notFound('Category not found.');
  sendSuccess(res, null, 200, `Category "${rows[0].name}" removed.`);
});

module.exports = { listOffers, listCategories, getOffer, createOffer, updateOffer, deleteOffer, restoreOffer, permanentDeleteOffer, createCategory, deleteCategory };