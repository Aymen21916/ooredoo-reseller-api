'use strict';

const db       = require('../config/db');
const AppError = require('../utils/AppError');
const { asyncHandler, sendSuccess, sendCreated } = require('../utils/asyncHandler');
const { audit } = require('../utils/audit');
const {
  requireFields, parseId, parseString,
  parsePositiveNumber, parsePositiveInt
} = require('../utils/validators');

// ─── GET /api/products/categories ───────────────────────────────────────────

const listCategories = asyncHandler(async (req, res) => {
  const { rows } = await db.query(
    'SELECT * FROM product_categories ORDER BY sort_order'
  );
  sendSuccess(res, rows);
});

// ─── GET /api/products  ──────────────────────────────────────────────────────

const listProducts = asyncHandler(async (req, res) => {
  const activeOnly   = req.user.role === 'cashier';
  const { category } = req.query;

  const conditions = [];
  const params     = [];

  if (activeOnly) {
    conditions.push('p.is_active = TRUE');
  }
  if (category) {
    const catId = parseId(category, 'category');
    params.push(catId);
    conditions.push(`p.category_id = $${params.length}`);
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

  const { rows } = await db.query(
    `SELECT p.id, p.name, p.price, p.commission_amount,
            p.is_active, p.sort_order,
            pc.id AS category_id, pc.name AS category_name
     FROM products p
     JOIN product_categories pc ON pc.id = p.category_id
     ${where}
     ORDER BY pc.sort_order, p.sort_order, p.name`,
    params
  );
  sendSuccess(res, rows);
});

// ─── GET /api/products/:id ───────────────────────────────────────────────────

const getProduct = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);

  const { rows } = await db.query(
    `SELECT p.*, pc.name AS category_name
     FROM products p
     JOIN product_categories pc ON pc.id = p.category_id
     WHERE p.id = $1`,
    [id]
  );
  if (!rows[0]) throw AppError.notFound('Product not found.');
  sendSuccess(res, rows[0]);
});

// ─── POST /api/products  (admin only) ───────────────────────────────────────

const createProduct = asyncHandler(async (req, res) => {
  requireFields(req.body, ['name', 'price', 'real_price', 'category_id']);

  const name              = parseString(req.body.name, 'name', 200);
  const price             = parsePositiveNumber(req.body.price, 'price', true);
  const real_price        = parsePositiveNumber(req.body.real_price, 'real_price', true);
  const category_id       = parsePositiveInt(req.body.category_id, 'category_id');
  const commission_amount = parsePositiveNumber(req.body.commission_amount ?? 0, 'commission_amount', true);
  const sort_order        = parseInt(req.body.sort_order ?? 0, 10);

  // Validate category
  const { rows: catRows } = await db.query(
    'SELECT id FROM product_categories WHERE id = $1', [category_id]
  );
  if (!catRows[0]) throw AppError.badRequest('Invalid category_id.', 'VALIDATION_ERROR');

  const { rows } = await db.query(
    `INSERT INTO products (name, price, real_price, category_id, commission_amount, sort_order)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
    [name, price, real_price, category_id, commission_amount, sort_order]
  );

  audit({
    userId:    req.user.id,
    action:    'INSERT',
    table:     'products',
    recordId:  rows[0].id,
    newValues: rows[0],
    ip:        req.clientIp,
  });

  sendCreated(res, rows[0], 'Product created.');
});

// ─── PATCH /api/products/:id  (admin only) ───────────────────────────────────

const updateProduct = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);

  const { rows: existing } = await db.query('SELECT * FROM products WHERE id = $1', [id]);
  if (!existing[0]) throw AppError.notFound('Product not found.');

  const prev    = existing[0];
  const allowed = ['name', 'price', 'real_price', 'category_id', 'commission_amount', 'is_active', 'sort_order'];
  const updates = {};

  for (const key of allowed) {
    if (req.body[key] !== undefined) updates[key] = req.body[key];
  }
  if (Object.keys(updates).length === 0) {
    throw AppError.badRequest('No updateable fields provided.', 'VALIDATION_ERROR');
  }

  const setClauses = Object.keys(updates).map((k, i) => `${k} = $${i + 2}`);
  const { rows }   = await db.query(
    `UPDATE products SET ${setClauses.join(', ')}, updated_at = NOW()
     WHERE id = $1 RETURNING *`,
    [id, ...Object.values(updates)]
  );

  audit({
    userId:    req.user.id,
    action:    'UPDATE',
    table:     'products',
    recordId:  id,
    oldValues: prev,
    newValues: updates,
    ip:        req.clientIp,
  });

  sendSuccess(res, rows[0], 200, 'Product updated.');
});

// ─── DELETE /api/products/:id  (admin only — soft delete) ────────────────────

const deleteProduct = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);

  const { rows } = await db.query(
    `UPDATE products SET is_active = FALSE, updated_at = NOW()
     WHERE id = $1 AND is_active = TRUE RETURNING id, name`,
    [id]
  );
  if (!rows[0]) throw AppError.notFound('Product not found or already inactive.');

  audit({
    userId:    req.user.id,
    action:    'DELETE',
    table:     'products',
    recordId:  id,
    newValues: { is_active: false },
    ip:        req.clientIp,
  });

  sendSuccess(res, null, 200, `Product "${rows[0].name}" deactivated.`);
});

// ─── POST /api/products/:id/restore  (admin only) ────────────────────────────

const restoreProduct = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);

  const { rows } = await db.query(
    `UPDATE products SET is_active = TRUE, updated_at = NOW()
     WHERE id = $1 AND is_active = FALSE RETURNING *`,
    [id]
  );
  if (!rows[0]) throw AppError.notFound('Product not found or already active.');

  audit({
    userId:    req.user.id,
    action:    'UPDATE',
    table:     'products',
    recordId:  id,
    oldValues: { is_active: false },
    newValues: { is_active: true },
    ip:        req.clientIp,
  });

  sendSuccess(res, rows[0], 200, `Product "${rows[0].name}" restored.`);
});

// ─── DELETE /api/products/:id/permanent  (admin only — hard delete) ──────────
// Products are forgiving: session_accessory_sales has ON DELETE SET NULL on
// product_id, so historical rows are preserved with their snapshot data.

const permanentDeleteProduct = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);

  const { rows: checkRows } = await db.query(
    `SELECT id, name, is_active FROM products WHERE id = $1`,
    [id]
  );
  if (!checkRows[0]) throw AppError.notFound('Product not found.');
  if (checkRows[0].is_active) {
    throw AppError.badRequest(
      'Deactivate the product first, then delete permanently.',
      'MUST_DEACTIVATE_FIRST'
    );
  }

  try {
    await db.query(`DELETE FROM products WHERE id = $1`, [id]);
  } catch (err) {
    if (err.code === '23503') {
      throw AppError.unprocessable(
        'Cannot delete: this product is referenced elsewhere. It must remain deactivated.',
        'REFERENCED_ROW'
      );
    }
    throw err;
  }

  audit({
    userId:    req.user.id,
    action:    'DELETE',
    table:     'products',
    recordId:  id,
    description: `Permanently deleted product "${checkRows[0].name}"`,
    ip:        req.clientIp,
  });

  sendSuccess(res, null, 200, `Product "${checkRows[0].name}" permanently deleted.`);
});

module.exports = {
  listCategories, listProducts, getProduct,
  createProduct, updateProduct, deleteProduct,
  restoreProduct, permanentDeleteProduct,
};
