'use strict';

const env      = require('../config/env');
const AppError = require('../utils/AppError');
const logger   = require('../utils/logger');

/**
 * Global Express error handler. Must be registered LAST with app.use().
 * Distinguishes operational errors (AppError) from unexpected bugs.
 */
const errorHandler = (err, req, res, _next) => {
  // ── Operational error (we threw it intentionally) ──────────────────────
  if (err.isOperational) {
    const body = {
      success:    false,
      status:     err.status,
      code:       err.code,
      message:    err.message,
    };
    // Allow callers to attach extra response fields (e.g. current_balance
    // on REPAYMENT_EXCEEDS_BALANCE / INSUFFICIENT_REGISTER_CASH).
    if (err.details && typeof err.details === 'object') {
      Object.assign(body, err.details);
    }
    return res.status(err.statusCode).json(body);
  }

  // ── PostgreSQL constraint violations → map to 4xx ──────────────────────
  if (err.code === '23505') {
    // Unique violation
    return res.status(409).json({
      success: false,
      status:  'fail',
      code:    'DUPLICATE_ENTRY',
      message: 'A record with that value already exists.',
      detail:  env.IS_PROD ? undefined : err.detail,
    });
  }

  if (err.code === '23503') {
    // Foreign key violation
    return res.status(422).json({
      success: false,
      status:  'fail',
      code:    'INVALID_REFERENCE',
      message: 'Referenced record does not exist.',
      detail:  env.IS_PROD ? undefined : err.detail,
    });
  }

  if (err.code === '23514') {
    // Check constraint violation
    return res.status(422).json({
      success: false,
      status:  'fail',
      code:    'CONSTRAINT_VIOLATION',
      message: err.message,
    });
  }

  // ── JWT errors that slipped past authenticate middleware ───────────────
  if (err.name === 'JsonWebTokenError' || err.name === 'TokenExpiredError') {
    return res.status(401).json({
      success: false,
      status:  'fail',
      code:    'TOKEN_INVALID',
      message: 'Invalid or expired token.',
    });
  }

  // ── Express body-parser: payload too large ─────────────────────────────
  if (err.type === 'entity.too.large') {
    return res.status(413).json({
      success: false,
      status:  'fail',
      code:    'PAYLOAD_TOO_LARGE',
      message: 'Request body exceeds the allowed size.',
    });
  }

  // ── Express body-parser: malformed JSON ────────────────────────────────
  if (err.type === 'entity.parse.failed' || err instanceof SyntaxError) {
    return res.status(400).json({
      success: false,
      status:  'fail',
      code:    'INVALID_JSON',
      message: 'Request body is not valid JSON.',
    });
  }

  // ── Unexpected / programmer error ──────────────────────────────────────
  logger.error({
    message: err.message,
    stack:   err.stack,
    url:     req.originalUrl,
    method:  req.method,
    userId:  req.user?.id,
  }, 'Unhandled error');

  // Report to Sentry (no-op if DSN not set)
  try {
    const Sentry = require('@sentry/node');
    Sentry.captureException(err, {
      user: req.user ? { id: req.user.id, username: req.user.username } : undefined,
      extra: { url: req.originalUrl, method: req.method },
    });
  } catch { /* Sentry not configured — skip */ }

  return res.status(500).json({
    success: false,
    status:  'error',
    code:    'INTERNAL_SERVER_ERROR',
    message: env.IS_PROD
      ? 'Something went wrong. Please try again.'
      : err.message,
    stack: env.IS_PROD ? undefined : err.stack,
  });
};

/** 404 fallthrough — register before errorHandler */
const notFoundHandler = (req, res) => {
  res.status(404).json({
    success: false,
    status:  'fail',
    code:    'ROUTE_NOT_FOUND',
    message: `Cannot ${req.method} ${req.originalUrl}`,
  });
};

module.exports = { errorHandler, notFoundHandler };
