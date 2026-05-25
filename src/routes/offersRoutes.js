'use strict';

const express = require('express');
const offersController = require('../controllers/offersController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();

// ─── Protected Routes ────────────────────────────────────────────────────────
router.use(authenticate);

// ─── Shared Routes (Admin & Cashier) ─────────────────────────────────────────
// Cashiers only see active offers; Admins see all.
router.get('/categories', offersController.listCategories);
router.get('/', offersController.listOffers);
router.get('/:id', offersController.getOffer);

// ─── Admin-Only Routes ───────────────────────────────────────────────────────
router.post('/', authorize('admin'), offersController.createOffer);
router.patch('/:id', authorize('admin'), offersController.updateOffer);
router.delete('/:id', authorize('admin'), offersController.deleteOffer);
router.post('/:id/restore', authorize('admin'), offersController.restoreOffer);
router.delete('/:id/permanent', authorize('admin'), offersController.permanentDeleteOffer);

module.exports = router;