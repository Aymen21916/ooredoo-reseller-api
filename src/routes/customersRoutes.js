'use strict';

const express = require('express');
const customersController = require('../controllers/customersController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();

// All authenticated users (admin + cashier) need access for the sale flow.
router.use(authenticate);

router.get('/lookup',  customersController.lookupByPhone);
router.get('/',        customersController.listCustomers);
router.get('/:id',     customersController.getCustomer);
router.get('/:id/purchases', customersController.getCustomerPurchases);
router.post('/',       customersController.createCustomer);
router.patch('/:id',   customersController.updateCustomer);
router.delete('/:id',  authorize('admin'), customersController.deleteCustomer);

module.exports = router;
