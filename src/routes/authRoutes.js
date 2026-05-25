'use strict';

const express = require('express');
const authController = require('../controllers/authController');
const { authenticate } = require('../middleware/authenticate');

const router = express.Router();

// ─── Public Routes ───────────────────────────────────────────────────────────
// These endpoints do not require a valid access token.

router.post('/login', authController.login);
router.post('/refresh', authController.refresh);

// ─── Protected Routes ────────────────────────────────────────────────────────
// All routes below this line require the Authorization: Bearer <token> header.
router.use(authenticate);

router.post('/logout', authController.logout);
router.get('/me', authController.me);

module.exports = router;