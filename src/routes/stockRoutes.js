'use strict';

const express = require('express');
const stockController = require('../controllers/stockController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();

router.use(authenticate);

// Cashiers can fetch their own balance
router.get('/my', stockController.getMyInventory);

// Admin-only distribution routes
router.get('/balances', authorize('admin'), stockController.getBalances);
router.post('/transfer', authorize('admin'), stockController.transferStock);
router.post('/admin/adjust', authorize('admin'), stockController.adjustAdminStock);

module.exports = router;