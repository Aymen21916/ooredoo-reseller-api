'use strict';

const jwt    = require('jsonwebtoken');
const crypto = require('crypto');
const env    = require('../config/env');

// ─── Access token (short-lived, stateless) ───────────────────────────────────

/**
 * Sign an access token containing the user's identity claim.
 * @param {{ id: number, username: string, role: string, storeId: number|null }} user
 * @returns {string} signed JWT
 */
const signAccessToken = (user) =>
  jwt.sign(
    {
      sub:     user.id,
      username: user.username,
      role:    user.role,
      storeId: user.store_id ?? null,
    },
    env.JWT_ACCESS_SECRET,
    {
      expiresIn: env.JWT_ACCESS_EXPIRES_IN,
      issuer:    'ooredoo-reseller',
      audience:  'ooredoo-reseller-client',
    }
  );

/**
 * Verify and decode an access token.
 * @param {string} token
 * @returns {{ sub: number, username: string, role: string, storeId: number|null }}
 * @throws {JsonWebTokenError | TokenExpiredError}
 */
const verifyAccessToken = (token) =>
  jwt.verify(token, env.JWT_ACCESS_SECRET, {
    issuer:   'ooredoo-reseller',
    audience: 'ooredoo-reseller-client',
  });

// ─── Refresh token (long-lived, stateful — stored as hash in DB) ─────────────

/**
 * Generate a cryptographically random refresh token string.
 * @returns {string} raw token (sent to client, NEVER stored raw)
 */
const generateRefreshToken = () => crypto.randomBytes(48).toString('hex');

/**
 * SHA-256 hash of a raw refresh token for safe DB storage.
 * @param {string} rawToken
 * @returns {string} hex digest
 */
const hashRefreshToken = (rawToken) =>
  crypto.createHash('sha256').update(rawToken).digest('hex');

/**
 * Calculate the absolute expiry Date for a refresh token.
 * Parses env.JWT_REFRESH_EXPIRES_IN which may be "8h", "1d", etc.
 * @returns {Date}
 */
const refreshTokenExpiresAt = () => {
  const str  = env.JWT_REFRESH_EXPIRES_IN;
  const units = { s: 1000, m: 60_000, h: 3_600_000, d: 86_400_000 };
  const match = str.match(/^(\d+)([smhd])$/);
  if (!match) throw new Error(`Cannot parse JWT_REFRESH_EXPIRES_IN: "${str}"`);
  const ms = parseInt(match[1], 10) * units[match[2]];
  return new Date(Date.now() + ms);
};

module.exports = {
  signAccessToken,
  verifyAccessToken,
  generateRefreshToken,
  hashRefreshToken,
  refreshTokenExpiresAt,
};
