'use strict';

const express = require('express');
const productsController = require('../controllers/productsController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();

// ─── Protected Routes ────────────────────────────────────────────────────────
router.use(authenticate);

// ─── Shared Routes (Admin & Cashier) ─────────────────────────────────────────

// Get all product categories (must be defined before /:id)
router.get('/categories', productsController.listCategories);

// Cashiers only see active products; Admins see all. Supports ?category=id filtering.
router.get('/', productsController.listProducts);
router.get('/:id', productsController.getProduct);

// ─── Admin-Only Routes ───────────────────────────────────────────────────────
router.post('/', authorize('admin'), productsController.createProduct);
router.patch('/:id', authorize('admin'), productsController.updateProduct);
router.delete('/:id', authorize('admin'), productsController.deleteProduct);
router.post('/:id/restore', authorize('admin'), productsController.restoreProduct);
router.delete('/:id/permanent', authorize('admin'), productsController.permanentDeleteProduct);

module.exports = router;