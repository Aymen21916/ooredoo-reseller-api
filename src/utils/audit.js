'use strict';

const { pool } = require('../config/db');
const logger   = require('./logger');

/**
 * Append a row to audit_logs. Intentionally fire-and-forget — a logging
 * failure must never break the primary request flow.
 *
 * @param {object} params
 * @param {number}      params.userId     - authenticated user performing the action
 * @param {string}      params.action     - audit_action enum value
 * @param {string}      [params.table]    - affected table name
 * @param {number}      [params.recordId] - affected row id
 * @param {object}      [params.oldValues]
 * @param {object}      [params.newValues]
 * @param {string}      [params.description]
 * @param {string}      [params.ip]       - client IP address
 */
const audit = ({ userId, action, table, recordId, oldValues, newValues, description, ip }) => {
  // Run asynchronously — do not await
  pool.query(
    `INSERT INTO audit_logs
       (user_id, action, table_name, record_id,
        old_values, new_values, description, ip_address)
     VALUES ($1, $2, $3, $4, $5::jsonb, $6::jsonb, $7, $8::inet)`,
    [
      userId,
      action,
      table       || null,
      recordId    || null,
      oldValues   ? JSON.stringify(oldValues)  : null,
      newValues   ? JSON.stringify(newValues)  : null,
      description || null,
      ip          || null,
    ]
  ).catch((err) => {
    // Silently log — never throw
    logger.error({ err }, 'Failed to write audit log');
  });
};

module.exports = { audit };
