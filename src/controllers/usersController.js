'use strict';

const bcrypt   = require('bcryptjs');
const db       = require('../config/db');
const env      = require('../config/env');
const AppError = require('../utils/AppError');
const { asyncHandler, sendSuccess, sendCreated } = require('../utils/asyncHandler');
const { audit } = require('../utils/audit');
const {
  requireFields, parseId, parseString, parsePagination
} = require('../utils/validators');

// ─── GET /api/users ──────────────────────────────────────────────────────────
// Admin: list all users. Cashier: only their own record.

const listUsers = asyncHandler(async (req, res) => {
  const { limit, offset } = parsePagination(req.query);

  let sql, params;

  if (req.user.role === 'admin') {
    sql = `
      SELECT u.id, u.username, u.full_name, u.role, u.is_active,
             u.store_id, s.name AS store_name, u.created_at
      FROM users u
      LEFT JOIN stores s ON s.id = u.store_id
      ORDER BY u.role, u.full_name
      LIMIT $1 OFFSET $2`;
    params = [limit, offset];
  } else {
    sql = `
      SELECT u.id, u.username, u.full_name, u.role, u.is_active,
             u.store_id, s.name AS store_name
      FROM users u
      LEFT JOIN stores s ON s.id = u.store_id
      WHERE u.id = $1`;
    params = [req.user.id];
  }

  const { rows } = await db.query(sql, params);
  sendSuccess(res, rows);
});

// ─── GET /api/users/:id ──────────────────────────────────────────────────────

const getUser = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);

  // Cashiers can only view themselves
  if (req.user.role !== 'admin' && req.user.id !== id) {
    throw AppError.forbidden('Access denied.', 'INSUFFICIENT_OWNERSHIP');
  }

  const { rows } = await db.query(
    `SELECT u.id, u.username, u.full_name, u.role, u.is_active,
            u.store_id, s.name AS store_name, u.created_at
     FROM users u
     LEFT JOIN stores s ON s.id = u.store_id
     WHERE u.id = $1`,
    [id]
  );
  if (!rows[0]) throw AppError.notFound('User not found.');
  sendSuccess(res, rows[0]);
});

// ─── POST /api/users  (admin only) ──────────────────────────────────────────

const createUser = asyncHandler(async (req, res) => {
  const { username, password, full_name, role, store_id } = req.body;
  requireFields(req.body, ['username', 'password', 'full_name', 'role']);

  const safeUsername = parseString(username, 'username', 50).toLowerCase();
  const safeFullName = parseString(full_name, 'full_name', 100);
  const safeRole     = ['admin', 'cashier'].includes(role) ? role : null;
  if (!safeRole) throw AppError.badRequest('role must be "admin" or "cashier".', 'VALIDATION_ERROR');

  if (safeRole === 'cashier' && !store_id) {
    throw AppError.badRequest('store_id is required for cashier accounts.', 'VALIDATION_ERROR');
  }

  // Validate store exists
  if (store_id) {
    const { rows: storeRows } = await db.query(
      'SELECT id FROM stores WHERE id = $1 AND is_active = TRUE', [store_id]
    );
    if (!storeRows[0]) throw AppError.badRequest('Invalid store_id.', 'VALIDATION_ERROR');
  }

  const passwordHash = await bcrypt.hash(password, env.BCRYPT_ROUNDS);

  const { rows } = await db.query(
    `INSERT INTO users (username, password_hash, full_name, role, store_id)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, username, full_name, role, store_id, is_active, created_at`,
    [safeUsername, passwordHash, safeFullName, safeRole, store_id || null]
  );

  audit({
    userId:     req.user.id,
    action:     'INSERT',
    table:      'users',
    recordId:   rows[0].id,
    newValues:  { username: safeUsername, role: safeRole, store_id },
    ip:         req.clientIp,
  });

  sendCreated(res, rows[0], 'User created successfully.');
});

// ─── PATCH /api/users/:id  (admin only) ─────────────────────────────────────

const updateUser = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);

  const { rows: existing } = await db.query(
    'SELECT * FROM users WHERE id = $1', [id]
  );
  if (!existing[0]) throw AppError.notFound('User not found.');

  const prev = existing[0];

  // Build partial update — only update provided fields
  const updates = {};
  if (req.body.full_name !== undefined) {
    updates.full_name = parseString(req.body.full_name, 'full_name', 100);
  }
  if (req.body.username !== undefined) {
    updates.username = parseString(req.body.username, 'username', 50).toLowerCase();
  }
  if (req.body.is_active !== undefined) {
    updates.is_active = Boolean(req.body.is_active);
  }
  if (req.body.store_id !== undefined) {
    updates.store_id = req.body.store_id ? parseInt(req.body.store_id, 10) : null;
  }
  if (req.body.password) {
    updates.password_hash = await bcrypt.hash(req.body.password, env.BCRYPT_ROUNDS);
  }

  if (Object.keys(updates).length === 0) {
    throw AppError.badRequest('No updateable fields provided.', 'VALIDATION_ERROR');
  }

  const setClauses = Object.keys(updates).map((k, i) => `${k} = $${i + 2}`);
  const values     = [id, ...Object.values(updates)];

  const { rows } = await db.query(
    `UPDATE users SET ${setClauses.join(', ')}, updated_at = NOW()
     WHERE id = $1
     RETURNING id, username, full_name, role, store_id, is_active, updated_at`,
    values
  );

  audit({
    userId:    req.user.id,
    action:    'UPDATE',
    table:     'users',
    recordId:  id,
    oldValues: { username: prev.username, full_name: prev.full_name, is_active: prev.is_active, store_id: prev.store_id },
    newValues: updates,
    ip:        req.clientIp,
  });

  sendSuccess(res, rows[0], 200, 'User updated.');
});

// ─── DELETE /api/users/:id  (admin only — soft delete via is_active) ─────────

const deleteUser = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);

  if (id === req.user.id) {
    throw AppError.forbidden('Admins cannot deactivate their own account.', 'SELF_DEACTIVATE');
  }

  const { rows } = await db.query(
    `UPDATE users SET is_active = FALSE, updated_at = NOW()
     WHERE id = $1 AND is_active = TRUE
     RETURNING id, username`,
    [id]
  );
  if (!rows[0]) throw AppError.notFound('User not found or already deactivated.');

  // Revoke all active sessions
  await db.query(
    `UPDATE refresh_tokens SET is_revoked = TRUE, revoked_at = NOW()
     WHERE user_id = $1 AND is_revoked = FALSE`,
    [id]
  );

  audit({
    userId:    req.user.id,
    action:    'DELETE',
    table:     'users',
    recordId:  id,
    oldValues: { is_active: true },
    newValues: { is_active: false },
    ip:        req.clientIp,
  });

  sendSuccess(res, null, 200, `User "${rows[0].username}" deactivated.`);
});

// ─── POST /api/users/:id/restore  (admin only) ───────────────────────────────

const restoreUser = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);

  const { rows } = await db.query(
    `UPDATE users SET is_active = TRUE, updated_at = NOW()
     WHERE id = $1 AND is_active = FALSE
     RETURNING id, username, full_name, role, store_id, is_active`,
    [id]
  );
  if (!rows[0]) throw AppError.notFound('User not found or already active.');

  audit({
    userId:    req.user.id,
    action:    'UPDATE',
    table:     'users',
    recordId:  id,
    oldValues: { is_active: false },
    newValues: { is_active: true },
    ip:        req.clientIp,
  });

  sendSuccess(res, rows[0], 200, `User "${rows[0].username}" restored.`);
});

// ─── DELETE /api/users/:id/permanent  (admin only — hard delete) ─────────────
// Only allowed if the user has no historical references (sessions, audit logs).
// PostgreSQL's foreign-key constraints will reject the delete otherwise; we
// translate the 23503 violation into a friendly 422.

const permanentDeleteUser = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);

  if (id === req.user.id) {
    throw AppError.forbidden('Admins cannot delete their own account.', 'SELF_DELETE');
  }

  // Only allow permanent deletion for already-deactivated users (safer)
  const { rows: checkRows } = await db.query(
    `SELECT id, username, is_active FROM users WHERE id = $1`,
    [id]
  );
  if (!checkRows[0]) throw AppError.notFound('User not found.');
  if (checkRows[0].is_active) {
    throw AppError.badRequest(
      'Deactivate the user first, then delete permanently.',
      'MUST_DEACTIVATE_FIRST'
    );
  }

  try {
    await db.query(`DELETE FROM users WHERE id = $1`, [id]);
  } catch (err) {
    if (err.code === '23503') {
      throw AppError.unprocessable(
        'Cannot delete: this user has historical records (sessions, sales, or audit logs). They must remain deactivated.',
        'REFERENCED_ROW'
      );
    }
    throw err;
  }

  audit({
    userId:    req.user.id,
    action:    'DELETE',
    table:     'users',
    recordId:  id,
    description: `Permanently deleted user "${checkRows[0].username}"`,
    ip:        req.clientIp,
  });

  sendSuccess(res, null, 200, `User "${checkRows[0].username}" permanently deleted.`);
});

module.exports = { listUsers, getUser, createUser, updateUser, deleteUser, restoreUser, permanentDeleteUser };