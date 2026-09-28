'use strict';

const db = require('../config/db');
const AppError = require('../utils/AppError');
const { asyncHandler, sendSuccess } = require('../utils/asyncHandler');
const { audit } = require('../utils/audit');
const { requireFields, parsePositiveInt, parseId } = require('../utils/validators');

// ─── GET /api/stock/balances (Admin Only) ──────────────────────────────────
const getBalances = asyncHandler(async (req, res) => {
  const { rows: adminRows } = await db.query(`SELECT quantity FROM sim_balances WHERE owner_type = 'admin' AND owner_id = 1`);
  const adminBalance = adminRows[0] ? adminRows[0].quantity : 0;

  const { rows: stores } = await db.query(`
    SELECT s.id, s.name, COALESCE(sb.quantity, 0) as quantity 
    FROM stores s 
    LEFT JOIN sim_balances sb ON sb.owner_type = 'store' AND sb.owner_id = s.id
    WHERE s.is_active = TRUE ORDER BY s.id
  `);

  sendSuccess(res, { admin: adminBalance, stores });
});

// ─── POST /api/stock/transfer (Admin Only) ─────────────────────────────────
const transferStock = asyncHandler(async (req, res) => {
  requireFields(req.body, ['from_type', 'from_id', 'to_type', 'to_id', 'quantity']);
  const quantity = parsePositiveInt(req.body.quantity, 'quantity');
  const fromType = req.body.from_type;
  const fromId = parseInt(req.body.from_id, 10);
  const toType = req.body.to_type;
  const toId = parseInt(req.body.to_id, 10);

  const result = await db.withTransaction(async (client) => {
    const { rows: fromRows } = await client.query(
      `UPDATE sim_balances SET quantity = quantity - $1 WHERE owner_type = $2 AND owner_id = $3 AND quantity >= $1 RETURNING quantity`,
      [quantity, fromType, fromId]
    );

    if (!fromRows[0]) {
      throw AppError.badRequest('Insufficient SIM cards in the source wallet.', 'INSUFFICIENT_STOCK');
    }

    await client.query(
      `INSERT INTO sim_balances (owner_type, owner_id, quantity) VALUES ($1, $2, $3)
       ON CONFLICT (owner_type, owner_id) DO UPDATE SET quantity = sim_balances.quantity + $3`,
      [toType, toId, quantity]
    );

    return { transferred: quantity };
  });

  audit({ userId: req.user.id, action: 'UPDATE', table: 'sim_balances', description: `Transferred ${quantity} SIMs from ${fromType} ${fromId} to ${toType} ${toId}`, ip: req.clientIp });
  sendSuccess(res, result, 200, `Successfully transferred ${quantity} SIM cards.`);
});

// ─── POST /api/stock/admin/adjust (Admin Only) ─────────────────────────────
const adjustAdminStock = asyncHandler(async (req, res) => {
  requireFields(req.body, ['quantity']);
  const quantity = parseInt(req.body.quantity, 10);
  
  if (isNaN(quantity) || quantity === 0) throw AppError.badRequest('Quantity must be a non-zero number.');

  const result = await db.withTransaction(async (client) => {
    const { rows: current } = await client.query(`SELECT quantity FROM sim_balances WHERE owner_type = 'admin' AND owner_id = 1 FOR UPDATE`);
    let newBalance = 0;

    if (current.length > 0) {
      if (quantity < 0 && Math.abs(quantity) > current[0].quantity) {
        throw AppError.badRequest(`Cannot deduct more SIMs than the Admin Vault holds (${current[0].quantity}).`);
      }
      const { rows } = await client.query(`UPDATE sim_balances SET quantity = quantity + $1 WHERE owner_type = 'admin' AND owner_id = 1 RETURNING quantity`, [quantity]);
      newBalance = rows[0].quantity;
    } else {
      if (quantity < 0) throw AppError.badRequest('Cannot deduct from an empty vault.');
      const { rows } = await client.query(`INSERT INTO sim_balances (owner_type, owner_id, quantity) VALUES ('admin', 1, $1) RETURNING quantity`, [quantity]);
      newBalance = rows[0].quantity;
    }
    return { new_balance: newBalance, adjustment: quantity };
  });

  audit({ userId: req.user.id, action: 'UPDATE', table: 'sim_balances', description: `Admin vault adjusted by ${quantity} SIMs`, ip: req.clientIp });
  sendSuccess(res, result, 200, `Admin Vault successfully updated by ${quantity} SIMs.`);
});

// ─── GET /api/stock/my (Cashier) ───────────────────────────────────────────
const getMyInventory = asyncHandler(async (req, res) => {
  const cashierId = req.user.role === 'admin' && req.query.cashier_id ? parseId(req.query.cashier_id, 'cashier_id') : req.user.id;
  
  const { rows: userRows } = await db.query(`SELECT store_id FROM users WHERE id = $1`, [cashierId]);
  const storeId = userRows[0] ? userRows[0].store_id : null;

  let available_count = 0;
  if (storeId) {
    const { rows } = await db.query(`SELECT quantity FROM sim_balances WHERE owner_type = 'store' AND owner_id = $1`, [storeId]);
    available_count = rows[0] ? rows[0].quantity : 0;
  }
  
  sendSuccess(res, { available_count, sold_count: 0, voided_count: 0, is_low_stock: available_count <= 5 });
});

module.exports = { getBalances, transferStock, getMyInventory, adjustAdminStock };