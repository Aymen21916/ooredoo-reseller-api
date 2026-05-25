'use strict';

const express = require('express');
const sessionsController = require('../controllers/sessionsController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');
const salesController = require('../controllers/salesController');

const router = express.Router();

// ─── Protected Routes ────────────────────────────────────────────────────────
router.use(authenticate);

// ─── Shared Routes (Admin & Cashier) ─────────────────────────────────────────

// Open a new session (cashiers open their own; admins can open on behalf)
router.post('/', sessionsController.openSession);

// List sessions (cashiers see own; admins see all, filterable)
router.get('/', sessionsController.listSessions);

// ─── Admin-Only Dashboards (Must be defined before /:id) ─────────────────────
// Fetch real-time totals for all open sessions across stores
router.get('/live', authorize('admin'), sessionsController.getLiveSessions);

// ─── Session-Specific Routes ─────────────────────────────────────────────────
// Cashiers can only access their own session ID; admins can access any.

router.get('/:id', sessionsController.getSession);
router.post('/:id/close', sessionsController.closeSession);

// Live totals for a specific session
router.get('/:id/totals', sessionsController.getSessionTotals);

// Remaining SIM stock for a specific session
router.get('/:id/stock', sessionsController.getSessionStock);

// Admin-Only: Assign SIM stock quota to a specific session
router.post('/:id/stock-assign', authorize('admin'), sessionsController.assignStock);

router.get('/:sessionId/history', salesController.getSessionHistory);

module.exports = router;