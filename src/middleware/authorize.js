'use strict';

const AppError = require('../utils/AppError');

/**
 * Role-based access control middleware factory.
 *
 * Usage:
 *   router.get('/admin-only', authenticate, authorize('admin'), handler);
 *   router.get('/staff',      authenticate, authorize('admin', 'cashier'), handler);
 *
 * @param {...string} roles - Allowed roles
 */
const authorize = (...roles) => (req, res, next) => {
  if (!req.user) {
    // Defensive: authenticate should always run first
    return next(AppError.unauthorized('Not authenticated.', 'NOT_AUTHENTICATED'));
  }

  if (!roles.includes(req.user.role)) {
    return next(
      AppError.forbidden(
        `Access denied. Required role(s): ${roles.join(', ')}.`,
        'INSUFFICIENT_ROLE'
      )
    );
  }

  next();
};

/**
 * Assert the authenticated user owns the resource or is an admin.
 * The `resourceOwnerId` is the user_id of the resource being accessed.
 *
 * @param {number} resourceOwnerId
 * @param {import('express').Request} req
 */
const assertOwnerOrAdmin = (resourceOwnerId, req) => {
  if (req.user.role === 'admin') return;
  if (req.user.id !== resourceOwnerId) {
    throw AppError.forbidden(
      'You do not have permission to access this resource.',
      'INSUFFICIENT_OWNERSHIP'
    );
  }
};

module.exports = { authorize, assertOwnerOrAdmin };
