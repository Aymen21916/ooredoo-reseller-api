'use strict';

// ─── AppError ───────────────────────────────────────────────────────────────

/**
 * Operational (expected) error with HTTP status code.
 * The global error handler formats these differently from unexpected errors.
 */
class AppError extends Error {
  /**
   * @param {string} message   - Human-readable message sent to client
   * @param {number} statusCode - HTTP status code (4xx / 5xx)
   * @param {string} [code]    - Machine-readable error code for client logic
   * @param {object} [details] - Extra fields merged into the JSON response
   *                             body (e.g. `{ current_balance: 12.34 }`).
   */
  constructor(message, statusCode, code, details) {
    super(message);
    this.statusCode  = statusCode;
    this.status      = statusCode >= 500 ? 'error' : 'fail';
    this.code        = code || `HTTP_${statusCode}`;
    this.details     = details && typeof details === 'object' ? details : null;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }

  /**
   * Attach extra response payload fields and return `this` for chaining.
   *
   *   throw AppError.badRequest('Repayment exceeds balance.',
   *                             'REPAYMENT_EXCEEDS_BALANCE')
   *                 .withDetails({ current_balance: 12.34 });
   *
   * @param {object} details
   */
  withDetails(details) {
    if (details && typeof details === 'object') {
      this.details = { ...(this.details || {}), ...details };
    }
    return this;
  }

  // ── Convenience factories ──────────────────────────────────────────────

  static badRequest(msg, code, details)    { return new AppError(msg, 400, code || 'BAD_REQUEST',   details); }
  static unauthorized(msg, code, details)  { return new AppError(msg, 401, code || 'UNAUTHORIZED',  details); }
  static forbidden(msg, code, details)     { return new AppError(msg, 403, code || 'FORBIDDEN',     details); }
  static notFound(msg, code, details)      { return new AppError(msg, 404, code || 'NOT_FOUND',     details); }
  static conflict(msg, code, details)      { return new AppError(msg, 409, code || 'CONFLICT',      details); }
  static unprocessable(msg, code, details) { return new AppError(msg, 422, code || 'UNPROCESSABLE', details); }
  static internal(msg, code, details)      { return new AppError(msg, 500, code || 'INTERNAL',      details); }
}

module.exports = AppError;
