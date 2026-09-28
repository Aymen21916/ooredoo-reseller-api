'use strict';

const db = require('../config/db');
const xlsx = require('xlsx');
const AppError = require('../utils/AppError');
const { asyncHandler, sendSuccess, sendCreated } = require('../utils/asyncHandler');
const { audit } = require('../utils/audit');
const { requireFields, parseId, parseString, parsePositiveNumber } = require('../utils/validators');

const listCategories = asyncHandler(async (req, res) => {
  const { rows } = await db.query('SELECT * FROM product_categories ORDER BY sort_order, name');
  sendSuccess(res, rows);
});

const createCategory = asyncHandler(async (req, res) => {
  requireFields(req.body, ['name']);
  const { rows } = await db.query('INSERT INTO product_categories (name, sort_order) VALUES ($1, $2) RETURNING *', [req.body.name, parseInt(req.body.sort_order ?? 0, 10)]);
  sendCreated(res, rows[0], 'Category created.');
});

const updateCategory = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const { rows } = await db.query('UPDATE product_categories SET name = $1 WHERE id = $2 RETURNING *', [req.body.name, id]);
  if (!rows[0]) throw AppError.notFound('Category not found.');
  sendSuccess(res, rows[0], 200, 'Category updated.');
});

const deleteCategory = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  try {
    const { rows } = await db.query('DELETE FROM product_categories WHERE id = $1 RETURNING *', [id]);
    if (!rows[0]) throw AppError.notFound('Category not found.');
    sendSuccess(res, null, 200, 'Category deleted.');
  } catch (err) { throw AppError.badRequest('Cannot delete category used by products.'); }
});

const listProducts = asyncHandler(async (req, res) => {
  const activeOnly = req.user.role === 'cashier';
  const where = activeOnly ? `WHERE p.is_active = TRUE` : '';
  const { rows } = await db.query(`SELECT p.id, p.name, p.price, p.real_price, p.commission_amount, p.loyalty_points, p.low_stock_threshold, p.stock_quantity, p.is_active, p.category_id, p.barcode, pc.name AS category_name FROM products p LEFT JOIN product_categories pc ON pc.id = p.category_id ${where} ORDER BY pc.sort_order, p.name`);
  sendSuccess(res, rows);
});

const getProduct = asyncHandler(async (req, res) => {
  const { rows } = await db.query('SELECT * FROM products WHERE id = $1', [parseId(req.params.id)]);
  if (!rows[0]) throw AppError.notFound('Product not found.');
  sendSuccess(res, rows[0]);
});

const createProduct = asyncHandler(async (req, res) => {
  requireFields(req.body, ['name', 'price', 'real_price', 'category_id']);
  const name = parseString(req.body.name, 'name', 100);
  const category_id = parseId(req.body.category_id, 'category_id');
  const price = parsePositiveNumber(req.body.price, 'price', true);
  const real_price = parsePositiveNumber(req.body.real_price, 'real_price', true);
  const commission_amount = parsePositiveNumber(req.body.commission_amount ?? 0, 'commission_amount', true);
  const loyalty_points = parsePositiveNumber(req.body.loyalty_points ?? 0, 'loyalty_points', true);
  const low_stock_threshold = parseInt(req.body.low_stock_threshold ?? 5, 10);
  const stock_quantity = parseInt(req.body.stock_quantity ?? 0, 10);
  const barcode = req.body.barcode && req.body.barcode.trim() !== '' ? parseString(req.body.barcode, 'barcode', 100) : null;

  try {
    const { rows } = await db.query(
      `INSERT INTO products (name, category_id, price, real_price, commission_amount, loyalty_points, low_stock_threshold, barcode, stock_quantity) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
      [name, category_id, price, real_price, commission_amount, loyalty_points, low_stock_threshold, barcode, stock_quantity]
    );
    sendCreated(res, rows[0], 'Product created.');
  } catch (err) { throw err; }
});

const updateProduct = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const allowed = ['name', 'category_id', 'price', 'real_price', 'commission_amount', 'loyalty_points', 'low_stock_threshold', 'is_active', 'barcode', 'stock_quantity'];
  const updates = {};
  for (const key of allowed) if (req.body[key] !== undefined) updates[key] = req.body[key];
  if (updates.barcode === "") updates.barcode = null;

  const setClauses = Object.keys(updates).map((k, i) => `${k} = $${i + 2}`);
  const { rows } = await db.query(`UPDATE products SET ${setClauses.join(', ')}, updated_at = NOW() WHERE id = $1 RETURNING *`, [id, ...Object.values(updates)]);
  sendSuccess(res, rows[0], 200, 'Product updated.');
});

const deleteProduct = asyncHandler(async (req, res) => {
  const { rows } = await db.query(`UPDATE products SET is_active = FALSE, updated_at = NOW() WHERE id = $1 RETURNING id, name`, [parseId(req.params.id)]);
  sendSuccess(res, null, 200, `Product deactivated.`);
});

const bulkUpload = asyncHandler(async (req, res) => {
  if (!req.file) throw AppError.badRequest('No Excel file provided.');

  const workbook = xlsx.read(req.file.buffer, { type: 'buffer' });
  const sheetName = workbook.SheetNames[0];
  const rows = xlsx.utils.sheet_to_json(workbook.Sheets[sheetName]);

  if (rows.length === 0) throw AppError.badRequest('Excel file is empty.');

  await db.withTransaction(async (client) => {
    // 1. Load existing categories to memory
    const { rows: existingCats } = await client.query('SELECT id, name FROM product_categories');
    const categoryMap = new Map();
    existingCats.forEach(c => categoryMap.set(c.name.toLowerCase().trim(), c.id));

    // 2. Load existing products to memory so we can compare what changed
    const { rows: existingProds } = await client.query('SELECT * FROM products');
    const productMap = new Map();
    existingProds.forEach(p => productMap.set(p.name.toLowerCase().trim(), p));

    for (const row of rows) {
      const rawName = row['Name'] || row['name'];
      if (!rawName) continue; // Skip empty rows

      const name = rawName.toString().trim();
      const prodKey = name.toLowerCase();
      
      // Check if product already exists in database
      const existingProduct = productMap.get(prodKey);

      // Handle Category Smartly
      let categoryId = existingProduct ? existingProduct.category_id : null;
      const categoryName = row['CategoryName'] || row['category_name'] || row['Category'];

      if (categoryName && categoryName.toString().trim() !== '') {
        const cleanCatName = categoryName.toString().trim();
        const catKey = cleanCatName.toLowerCase();
        if (categoryMap.has(catKey)) {
          categoryId = categoryMap.get(catKey);
        } else {
          const { rows: newCat } = await client.query(
            'INSERT INTO product_categories (name, sort_order) VALUES ($1, 0) RETURNING id',
            [cleanCatName]
          );
          categoryId = newCat[0].id;
          categoryMap.set(catKey, categoryId);
        }
      } else if (!existingProduct) {
         // Default category ONLY for brand new products missing a category in Excel
         const catKey = 'uncategorized';
         if (categoryMap.has(catKey)) {
            categoryId = categoryMap.get(catKey);
         } else {
            const { rows: newCat } = await client.query(
              'INSERT INTO product_categories (name, sort_order) VALUES ($1, 0) RETURNING id',
              ['Uncategorized']
            );
            categoryId = newCat[0].id;
            categoryMap.set(catKey, categoryId);
         }
      }

      // Stock is always additive (New Excel Stock + Existing DB Stock)
      const incomingStock = parseInt(row['Stock'] || row['stock_quantity'] || 0, 10);

      if (existingProduct) {
        // UPDATE EXISTING PRODUCT
        // It ONLY overwrites the database if you actually typed a value in the Excel cell
        const realPrice = row['RealPrice'] !== undefined ? parseFloat(row['RealPrice']) : existingProduct.real_price;
        const price = row['SellingPrice'] !== undefined ? parseFloat(row['SellingPrice']) : existingProduct.price;
        const barcode = row['Barcode'] !== undefined ? row['Barcode'] : existingProduct.barcode;
        const loyaltyPoints = row['LoyaltyPoints'] !== undefined ? parseInt(row['LoyaltyPoints'], 10) : existingProduct.loyalty_points;
        const commission = row['Commission'] !== undefined ? parseFloat(row['Commission']) : existingProduct.commission_amount;
        
        const newStock = existingProduct.stock_quantity + incomingStock;

        await client.query(
          `UPDATE products SET 
            category_id = $1, real_price = $2, price = $3, 
            stock_quantity = $4, barcode = $5, loyalty_points = $6, commission_amount = $7
           WHERE id = $8`,
          [categoryId, realPrice, price, newStock, barcode, loyaltyPoints, commission, existingProduct.id]
        );

        // Update memory map so duplicate rows in the same Excel sheet calculate correctly
        existingProduct.stock_quantity = newStock;
        existingProduct.real_price = realPrice;
        existingProduct.price = price;

      } else {
        // INSERT BRAND NEW PRODUCT
        const realPrice = row['RealPrice'] !== undefined ? parseFloat(row['RealPrice']) : 0;
        const price = row['SellingPrice'] !== undefined ? parseFloat(row['SellingPrice']) : 0;
        const barcode = row['Barcode'] !== undefined ? row['Barcode'] : null;
        const loyaltyPoints = row['LoyaltyPoints'] !== undefined ? parseInt(row['LoyaltyPoints'], 10) : 0;
        const commission = row['Commission'] !== undefined ? parseFloat(row['Commission']) : 0;

        const { rows: newProd } = await client.query(
          `INSERT INTO products 
            (name, category_id, real_price, price, stock_quantity, barcode, loyalty_points, commission_amount, is_active)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true) RETURNING *`,
          [name, categoryId, realPrice, price, incomingStock, barcode, loyaltyPoints, commission]
        );
        
        productMap.set(prodKey, newProd[0]);
      }
    }
  });

  sendSuccess(res, null, 200, 'Products successfully imported and smartly updated!');
});

module.exports = { listCategories, createCategory, updateCategory, deleteCategory, listProducts, getProduct, createProduct, updateProduct, deleteProduct, bulkUpload };