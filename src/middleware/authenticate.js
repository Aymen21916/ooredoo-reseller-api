'use strict';

const { verifyAccessToken } = require('../utils/jwt');
const AppError              = require('../utils/AppError');

/**
 * Verifies the Authorization: Bearer <token> header.
 * On success, attaches the decoded payload as `req.user`:
 *   { id, username, role, storeId }
 *
 * On failure, forwards an AppError to the error handler.
 */
const authenticate = (req, res, next) => {
  const header = req.headers.authorization;

  if (!header || !header.startsWith('Bearer ')) {
    return next(
      AppError.unauthorized('No access token provided.', 'TOKEN_MISSING')
    );
  }

  const token = header.slice(7).trim();

  let decoded;
  try {
    decoded = verifyAccessToken(token);
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return next(AppError.unauthorized('Access token has expired.', 'TOKEN_EXPIRED'));
    }
    return next(AppError.unauthorized('Access token is invalid.', 'TOKEN_INVALID'));
  }

  // Attach a normalised user object — controllers rely on this shape.
  req.user = {
    id:       decoded.sub,
    username: decoded.username,
    role:     decoded.role,
    storeId:  decoded.storeId,
  };

  // Convenience: client IP for audit logs
  req.clientIp =
    req.headers['x-forwarded-for']?.split(',')[0]?.trim() ||
    req.socket?.remoteAddress ||
    null;

  next();
};

module.exports = { authenticate };
