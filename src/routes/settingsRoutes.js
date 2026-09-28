'use strict';

const express = require('express');
const settingsController = require('../controllers/settingsController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();

router.use(authenticate);

// Cashiers need to GET settings to calculate points, but only Admins can UPDATE them
router.get('/loyalty', settingsController.getLoyaltySettings);
router.patch('/loyalty', authorize('admin'), settingsController.updateLoyaltySettings);

module.exports = router;