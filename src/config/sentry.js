'use strict';

/**
 * Sentry initialisation. Loaded at the very top of server.js so it can
 * instrument Express and Node internals. If SENTRY_DSN is not set, Sentry
 * is a no-op — perfect for local development.
 */

const Sentry = require('@sentry/node');
const env    = require('./env');

if (env.SENTRY_DSN) {
  Sentry.init({
    dsn: env.SENTRY_DSN,
    environment: env.NODE_ENV,
    tracesSampleRate: env.IS_PROD ? 0.1 : 0,
    // Only report 5xx errors and unexpected exceptions
    beforeSend(event, hint) {
      const err = hint?.originalException;
      if (err && err.isOperational && err.statusCode < 500) {
        return null; // drop 4xx operational errors
      }
      return event;
    },
  });
}

module.exports = Sentry;
