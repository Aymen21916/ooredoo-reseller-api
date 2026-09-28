'use strict';

const db = require('../config/db');
const { asyncHandler, sendSuccess } = require('../utils/asyncHandler');

const getStores = asyncHandler(async (req, res) => {
  // Fetches all active stores to populate the frontend dropdowns
  const { rows } = await db.query('SELECT id, name FROM stores WHERE is_active = TRUE ORDER BY id');
  sendSuccess(res, rows);
});

module.exports = { getStores };