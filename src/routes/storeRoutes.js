const express = require('express');
const router = express.Router();
const storeController = require('../controllers/storeController');

// The GET /api/stores endpoint
router.get('/', storeController.getStores);

module.exports = router;