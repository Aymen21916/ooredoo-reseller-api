'use strict';

const pino = require('pino');
const env  = require('../config/env');

const logger = pino({
  level: env.IS_PROD ? 'info' : 'debug',
  timestamp: pino.stdTimeFunctions.isoTime,
});

module.exports = logger;
