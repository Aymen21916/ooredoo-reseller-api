'use strict';

const db = require('../config/db');
const { asyncHandler, sendSuccess } = require('../utils/asyncHandler');
const { audit } = require('../utils/audit');
const AppError = require('../utils/AppError');

// Fetch all settings as a simple key-value object
const getLoyaltySettings = asyncHandler(async (req, res) => {
  const { rows } = await db.query('SELECT key, value FROM loyalty_settings');
  const settings = {};
  rows.forEach(row => {
    settings[row.key] = parseFloat(row.value);
  });
  sendSuccess(res, settings);
});

// Update multiple settings at once
const updateLoyaltySettings = asyncHandler(async (req, res) => {
  const updates = req.body; // e.g., { storm_earn_percent: 1.5, referral_bonus_points: 50 }
  if (!updates || Object.keys(updates).length === 0) {
    throw AppError.badRequest('No settings provided to update.');
  }

  await db.withTransaction(async (client) => {
    for (const [key, value] of Object.entries(updates)) {
      if (typeof value !== 'number' || isNaN(value)) continue;
      
      await client.query(
        `UPDATE loyalty_settings SET value = $1 WHERE key = $2`,
        [value, key]
      );
    }
  });

  audit({ 
    userId: req.user.id, action: 'UPDATE', table: 'loyalty_settings', 
    recordId: 0, newValues: updates, ip: req.clientIp 
  });

  sendSuccess(res, null, 200, 'Loyalty rules updated successfully.');
});

module.exports = { getLoyaltySettings, updateLoyaltySettings };