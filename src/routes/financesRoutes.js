'use strict';

const express = require('express');
const financesController = require('../controllers/financesController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();

// All finance routes require an authenticated admin.
router.use(authenticate, authorize('admin'));

// ─── Global Pool ────────────────────────────────────────────────────────────
router.get('/pool', financesController.getPool);
router.put('/pool', financesController.updatePool);

// ─── Store Registers ────────────────────────────────────────────────────────
router.get('/registers', financesController.getRegisters);
router.put('/registers/:id', financesController.updateRegister);

module.exports = router;
