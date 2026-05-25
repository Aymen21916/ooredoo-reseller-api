'use strict';

const express = require('express');
const usersController = require('../controllers/usersController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();

// ─── Protected Routes ────────────────────────────────────────────────────────
// All user routes require a valid access token.
router.use(authenticate);

// ─── Shared Routes (Admin & Cashier) ─────────────────────────────────────────
// The controller logic handles data filtering so cashiers only see their own record.
router.get('/', usersController.listUsers);
router.get('/:id', usersController.getUser);

// ─── Admin-Only Routes ───────────────────────────────────────────────────────
// Only users with the 'admin' role can create, update, or deactivate accounts.
router.post('/', authorize('admin'), usersController.createUser);
router.patch('/:id', authorize('admin'), usersController.updateUser);
router.delete('/:id', authorize('admin'), usersController.deleteUser);
router.post('/:id/restore', authorize('admin'), usersController.restoreUser);
router.delete('/:id/permanent', authorize('admin'), usersController.permanentDeleteUser);

module.exports = router;