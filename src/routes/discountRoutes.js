'use strict';
const express = require('express');
const discountController = require('../controllers/discountController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();

router.use(authenticate);

// Cashiers request and check status
router.post('/request', authorize('cashier', 'admin'), discountController.requestDiscount);
router.get('/:id/status', authorize('cashier', 'admin'), discountController.getRequestStatus);

// Admins view pending and resolve them
router.get('/admin/pending', authorize('admin'), discountController.getPendingRequests);
router.post('/:id/resolve', authorize('admin'), discountController.resolveRequest);

module.exports = router;