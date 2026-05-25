'use strict';

const express = require('express');
const salesController = require('../controllers/salesController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();

// ─── Protected Routes ────────────────────────────────────────────────────────
router.use(authenticate);

// Only cashiers can record active sales. Admins don't ring up customers.
router.use(authorize('cashier'));

router.post('/sim', salesController.recordSimSale);
router.post('/storm', salesController.recordStormEntry);
router.post('/accessory', salesController.recordAccessorySale);
router.post('/debt', salesController.recordDebt);
router.post('/:type/:id/void', salesController.voidTransaction);

module.exports = router;