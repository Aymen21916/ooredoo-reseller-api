'use strict';

const express = require('express');
const productsController = require('../controllers/productsController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');
const multer = require('multer');
const upload = multer({ storage: multer.memoryStorage() });

const router = express.Router();

router.use(authenticate);

// ─── Category Routes ─────────────────────────────────────────────────────────
router.get('/categories', productsController.listCategories);
router.post('/categories', authorize('admin'), productsController.createCategory);
router.put('/categories/:id', authorize('admin'), productsController.updateCategory);
router.delete('/categories/:id', authorize('admin'), productsController.deleteCategory);

// ─── Product Routes ──────────────────────────────────────────────────────────
router.get('/', productsController.listProducts);
router.get('/:id', productsController.getProduct);

router.post('/', authorize('admin'), productsController.createProduct);
router.patch('/:id', authorize('admin'), productsController.updateProduct);
router.delete('/:id', authorize('admin'), productsController.deleteProduct);

router.post('/bulk-upload', upload.single('file'), productsController.bulkUpload);

module.exports = router;