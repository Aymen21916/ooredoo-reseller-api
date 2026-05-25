'use strict';

const express = require('express');
const stockController = require('../controllers/stockController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();

router.use(authenticate);

// Cashier (own inventory) and admin (any inventory via ?cashier_id)
router.get('/my', stockController.getMyInventory);

// Admin-only routes
router.get('/cashiers', authorize('admin'), stockController.getCashierInventory);
router.get('/cards',    authorize('admin'), stockController.listCards);
router.post('/assign',  authorize('admin'), stockController.assignBatch);

module.exports = router;
