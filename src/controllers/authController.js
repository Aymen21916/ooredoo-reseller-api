'use strict';

const bcrypt = require('bcryptjs');
const db     = require('../config/db');
const AppError = require('../utils/AppError');
const { asyncHandler, sendSuccess } = require('../utils/asyncHandler');
const {
  signAccessToken,
  generateRefreshToken,
  hashRefreshToken,
  refreshTokenExpiresAt,
  verifyAccessToken,
} = require('../utils/jwt');
const { audit } = require('../utils/audit');
const { requireFields } = require('../utils/validators');

// ─── POST /api/auth/login ────────────────────────────────────────────────────

const login = asyncHandler(async (req, res) => {
  const { username, password } = req.body;
  requireFields(req.body, ['username', 'password']);

  // Fetch user — always run bcrypt even when user not found (timing attack mitigation)
  const { rows } = await db.query(
    `SELECT id, username, password_hash, full_name, role, store_id, is_active
     FROM users WHERE username = $1 LIMIT 1`,
    [username.trim().toLowerCase()]
  );

  const user        = rows[0];
  const dummyHash   = '$2a$12$invalidhashtopreventtimingattacksonmissingusers.....';
  const hashToCheck = user ? user.password_hash : dummyHash;
  const match       = await bcrypt.compare(password, hashToCheck);

  if (!user || !match) {
    throw AppError.unauthorized('Invalid username or password.', 'INVALID_CREDENTIALS');
  }

  if (!user.is_active) {
    throw AppError.forbidden('Account is deactivated. Contact admin.', 'ACCOUNT_DISABLED');
  }

  // Issue tokens
  const accessToken  = signAccessToken(user);
  const rawRefresh   = generateRefreshToken();
  const refreshHash  = hashRefreshToken(rawRefresh);
  const expiresAt    = refreshTokenExpiresAt();

  // Persist refresh token — revoke any existing tokens for this user first
  // (one active session per user — matches the shift model)
  await db.withTransaction(async (client) => {
    await client.query(
      `UPDATE refresh_tokens SET is_revoked = TRUE, revoked_at = NOW()
       WHERE user_id = $1 AND is_revoked = FALSE`,
      [user.id]
    );
    await client.query(
      `INSERT INTO refresh_tokens (user_id, token_hash, expires_at, ip_address)
       VALUES ($1, $2, $3, $4::inet)`,
      [user.id, refreshHash, expiresAt, req.clientIp]
    );
  });

  audit({
    userId:      user.id,
    action:      'LOGIN',
    description: `User "${user.username}" logged in`,
    ip:          req.clientIp,
  });

  sendSuccess(res, {
    accessToken,
    refreshToken: rawRefresh,
    expiresIn:    process.env.JWT_ACCESS_EXPIRES_IN || '1h',
    user: {
      id:       user.id,
      username: user.username,
      fullName: user.full_name,
      role:     user.role,
      storeId:  user.store_id,
    },
  });
});

// ─── POST /api/auth/refresh ──────────────────────────────────────────────────

const refresh = asyncHandler(async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    throw AppError.badRequest('refreshToken is required.', 'TOKEN_MISSING');
  }

  const tokenHash = hashRefreshToken(refreshToken);

  const { rows } = await db.query(
    `SELECT rt.id, rt.user_id, rt.expires_at, rt.is_revoked,
            u.username, u.full_name, u.role, u.store_id, u.is_active
     FROM refresh_tokens rt
     JOIN users u ON u.id = rt.user_id
     WHERE rt.token_hash = $1 LIMIT 1`,
    [tokenHash]
  );

  const record = rows[0];

  if (!record) {
    throw AppError.unauthorized('Invalid refresh token.', 'TOKEN_INVALID');
  }

  if (record.is_revoked) {
    // Token reuse detected — revoke ALL tokens for this user (token theft signal)
    await db.query(
      `UPDATE refresh_tokens SET is_revoked = TRUE, revoked_at = NOW()
       WHERE user_id = $1`,
      [record.user_id]
    );
    audit({
      userId:      record.user_id,
      action:      'LOGIN',
      description: 'Refresh token reuse detected — all sessions revoked',
      ip:          req.clientIp,
    });
    throw AppError.unauthorized('Token reuse detected. Please log in again.', 'TOKEN_REUSE');
  }

  if (new Date(record.expires_at) < new Date()) {
    throw AppError.unauthorized('Refresh token has expired. Please log in again.', 'TOKEN_EXPIRED');
  }

  if (!record.is_active) {
    throw AppError.forbidden('Account is deactivated.', 'ACCOUNT_DISABLED');
  }

  // Rotate: revoke old, issue new pair
  const newAccessToken = signAccessToken({
    id:       record.user_id,
    username: record.username,
    role:     record.role,
    store_id: record.store_id,
  });
  const newRawRefresh  = generateRefreshToken();
  const newRefreshHash = hashRefreshToken(newRawRefresh);
  const newExpiresAt   = refreshTokenExpiresAt();

  await db.withTransaction(async (client) => {
    await client.query(
      `UPDATE refresh_tokens SET is_revoked = TRUE, revoked_at = NOW()
       WHERE id = $1`,
      [record.id]
    );
    await client.query(
      `INSERT INTO refresh_tokens (user_id, token_hash, expires_at, ip_address)
       VALUES ($1, $2, $3, $4::inet)`,
      [record.user_id, newRefreshHash, newExpiresAt, req.clientIp]
    );
  });

  sendSuccess(res, {
    accessToken:  newAccessToken,
    refreshToken: newRawRefresh,
  });
});

// ─── POST /api/auth/logout ───────────────────────────────────────────────────

const logout = asyncHandler(async (req, res) => {
  const { refreshToken } = req.body;

  if (refreshToken) {
    const tokenHash = hashRefreshToken(refreshToken);
    await db.query(
      `UPDATE refresh_tokens SET is_revoked = TRUE, revoked_at = NOW()
       WHERE token_hash = $1`,
      [tokenHash]
    );
  }

  // Also revoke all tokens for the user (belt-and-suspenders for shift-end logout)
  await db.query(
    `UPDATE refresh_tokens SET is_revoked = TRUE, revoked_at = NOW()
     WHERE user_id = $1 AND is_revoked = FALSE`,
    [req.user.id]
  );

  audit({
    userId:      req.user.id,
    action:      'LOGOUT',
    description: `User "${req.user.username}" logged out`,
    ip:          req.clientIp,
  });

  sendSuccess(res, null, 200, 'Logged out successfully.');
});

// ─── GET /api/auth/me ────────────────────────────────────────────────────────

const me = asyncHandler(async (req, res) => {
  const { rows } = await db.query(
    `SELECT u.id, u.username, u.full_name, u.role, u.store_id,
            s.name AS store_name
     FROM users u
     LEFT JOIN stores s ON s.id = u.store_id
     WHERE u.id = $1 AND u.is_active = TRUE`,
    [req.user.id]
  );
  if (!rows[0]) throw AppError.notFound('User not found.');
  sendSuccess(res, rows[0]);
});

module.exports = { login, refresh, logout, me };
