'use strict';

/**
 * Wraps an async Express route handler so that thrown errors are forwarded
 * to next() automatically. Eliminates repetitive try/catch boilerplate.
 *
 * Usage:
 *   router.get('/path', asyncHandler(async (req, res) => { ... }));
 *
 * @param {(req, res, next) => Promise<void>} fn
 */
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

// ─── Consistent response formatters ─────────────────────────────────────────

/**
 * Send a successful JSON response.
 * @param {import('express').Response} res
 * @param {any}    data
 * @param {number} [statusCode=200]
 * @param {string} [message]
 */
const sendSuccess = (res, data, statusCode = 200, message) => {
  const body = { success: true };
  if (message) body.message = message;
  if (data !== undefined) body.data = data;
  return res.status(statusCode).json(body);
};

/**
 * Send a created (201) response.
 */
const sendCreated = (res, data, message) => sendSuccess(res, data, 201, message);

module.exports = { asyncHandler, sendSuccess, sendCreated };
