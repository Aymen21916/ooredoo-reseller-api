'use strict';

const db       = require('../config/db');
const AppError = require('../utils/AppError');
const logger   = require('../utils/logger');
const { asyncHandler, sendSuccess, sendCreated } = require('../utils/asyncHandler');
const { audit } = require('../utils/audit');
const { parseDate, parseId, validateDateRange } = require('../utils/validators');

// ─── Helpers ─────────────────────────────────────────────────────────────────

/** Today's date in YYYY-MM-DD using the server's local timezone. */
const todayStr = () => {
  const d = new Date();
  const yyyy = d.getFullYear();
  const mm   = String(d.getMonth() + 1).padStart(2, '0');
  const dd   = String(d.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
};

/** Validate a date param: must be YYYY-MM-DD and not in the future. */
const validateReportDate = (raw) => {
  const date = parseDate(raw, 'date');
  if (date > todayStr()) {
    throw AppError.badRequest('Cannot generate a report for a future date.', 'FUTURE_DATE');
  }
  return date;
};

/** Map a single live-totals row into the JSONB snapshot shape. */
const mapSession = (row) => ({
  session_id:                     row.session_id,
  cashier_id:                     row.cashier_id,
  cashier_name:                   row.cashier_name,
  store_id:                       row.store_id,
  store_name:                     row.store_name,
  session_date:                   row.session_date,
  opening_cash:                   parseFloat(row.opening_cash) || 0,
  sim_units_sold:                 parseInt(row.sim_units_sold, 10) || 0,
  sim_total_real_price:           parseFloat(row.sim_total_real_price) || 0,
  sim_total_selling_price:        parseFloat(row.sim_total_selling_price) || 0,
  sim_total_points:               parseInt(row.sim_total_points, 10) || 0,
  sim_total_commission:           parseFloat(row.sim_total_commission) || 0,
  sim_total_profit:               parseFloat(row.sim_total_profit) || 0,
  storm_total:                    parseFloat(row.storm_total) || 0,
  accessories_total:              parseFloat(row.accessories_total) || 0,
  accessories_total_real_price:   parseFloat(row.accessories_total_real_price) || 0,
  accessories_total_commission:   parseFloat(row.accessories_total_commission) || 0,
  accessories_total_profit:       parseFloat(row.accessories_total_profit) || 0,
  debt_total:                     parseFloat(row.debt_total) || 0,
  expected_register_cash:         parseFloat(row.expected_register_cash) || 0,
  total_cashier_benefit:          parseFloat(row.total_cashier_benefit) || 0,
});

/**
 * Decorate a daily_reports row with computed convenience fields (total_revenue)
 * so the UI doesn't have to recompute them.
 */
const decorate = (row) => {
  if (!row) return row;
  const sellingPrice = parseFloat(row.total_selling_price) || 0;
  const storm        = parseFloat(row.total_storm) || 0;
  const accessories  = parseFloat(row.total_accessories) || 0;
  const realPrice    = parseFloat(row.total_real_price) || 0;
  const commissions  = parseFloat(row.total_commissions) || 0;
  const profit       = parseFloat(row.gross_profit) || 0;

  const total_revenue = sellingPrice + storm + accessories;
  const margin_pct    = total_revenue > 0 ? (profit / total_revenue) * 100 : 0;

  return {
    ...row,
    total_real_price:    realPrice,
    total_selling_price: sellingPrice,
    total_storm:         storm,
    total_accessories:   accessories,
    total_commissions:   commissions,
    total_debts:         parseFloat(row.total_debts) || 0,
    gross_profit:        profit,
    total_revenue,
    margin_pct,
  };
};

// ─── GET /api/reports/preview?date=YYYY-MM-DD ───────────────────────────────
// Returns "what will happen if I click Generate":
//   - which sessions would be included (closed ones)
//   - which sessions are still open (blockers)
//   - which stores already have a report on that date
//   - aggregated totals so the admin can sanity-check before committing

const previewDailyReport = asyncHandler(async (req, res) => {
  const date = validateReportDate(req.query.date || todayStr());

  // All sessions for the date, regardless of status
  const { rows: allSessions } = await db.query(
    `SELECT cs.id AS session_id, cs.status, cs.cashier_id, cs.store_id, cs.session_date,
            cs.opening_cash, cs.closed_at,
            u.full_name AS cashier_name,
            s.name      AS store_name
     FROM cashier_sessions cs
     JOIN users  u ON u.id = cs.cashier_id
     JOIN stores s ON s.id = cs.store_id
     WHERE cs.session_date = $1
     ORDER BY cs.store_id, u.full_name`,
    [date]
  );

  // Live totals for closed sessions (so the preview matches what gets snapshotted)
  const { rows: closedSessionTotals } = await db.query(
    `SELECT v.*
     FROM v_session_live_totals v
     JOIN cashier_sessions cs ON cs.id = v.session_id
     WHERE cs.session_date = $1 AND cs.status = 'closed'`,
    [date]
  );

  // Existing reports already generated for this date
  const { rows: existingReports } = await db.query(
    `SELECT store_id FROM daily_reports WHERE report_date = $1`,
    [date]
  );
  const existingByStore = new Set(existingReports.map((r) => r.store_id));

  // Group totals per store for the preview cards
  const storeMap = new Map();
  for (const t of closedSessionTotals) {
    if (!storeMap.has(t.store_id)) {
      storeMap.set(t.store_id, {
        store_id:                t.store_id,
        store_name:              t.store_name,
        already_generated:       existingByStore.has(t.store_id),
        sessions_included:       0,
        total_sim_units:         0,
        total_real_price:        0,
        total_selling_price:     0,
        total_storm:             0,
        total_accessories:       0,
        total_debts:             0,
        total_commissions:       0,
      });
    }
    const s = storeMap.get(t.store_id);
    s.sessions_included     += 1;
    s.total_sim_units       += parseInt(t.sim_units_sold, 10) || 0;
    s.total_real_price      += parseFloat(t.sim_total_real_price) || 0;
    s.total_selling_price   += parseFloat(t.sim_total_selling_price) || 0;
    s.total_storm           += parseFloat(t.storm_total) || 0;
    s.total_accessories     += parseFloat(t.accessories_total) || 0;
    s.total_debts           += parseFloat(t.debt_total) || 0;
    s.total_commissions     += parseFloat(t.total_cashier_benefit) || 0;
  }

  // Add any store rows where reports exist but no closed sessions (so the UI
  // can show "already generated") — and stores that have only open sessions.
  const { rows: stores } = await db.query(`SELECT id, name FROM stores WHERE is_active = TRUE ORDER BY id`);
  for (const s of stores) {
    if (!storeMap.has(s.id) && existingByStore.has(s.id)) {
      storeMap.set(s.id, {
        store_id:           s.id,
        store_name:         s.name,
        already_generated:  true,
        sessions_included:  0,
        total_sim_units:    0,
        total_real_price:   0,
        total_selling_price: 0,
        total_storm:        0,
        total_accessories:  0,
        total_debts:        0,
        total_commissions:  0,
      });
    }
  }

  const stores_summary = Array.from(storeMap.values()).map((s) => ({
    ...s,
    total_revenue: s.total_selling_price + s.total_storm + s.total_accessories,
    gross_profit:  (s.total_selling_price + s.total_storm + s.total_accessories) - s.total_real_price - s.total_commissions,
  }));

  const open_sessions    = allSessions.filter((s) => s.status === 'open');
  const closed_sessions  = allSessions.filter((s) => s.status === 'closed');

  const generatable_stores = stores_summary.filter(
    (s) => !s.already_generated && s.sessions_included > 0
  );

  sendSuccess(res, {
    date,
    today:                   todayStr(),
    open_sessions,
    closed_sessions:         closed_sessions.length,
    blocking_open_sessions:  open_sessions.length,
    stores_summary,
    can_generate:            generatable_stores.length > 0,
    generatable_count:       generatable_stores.length,
    already_generated_count: stores_summary.filter((s) => s.already_generated).length,
  });
});

// ─── POST /api/reports/generate ──────────────────────────────────────────────
// Body: { date?: YYYY-MM-DD, force_close_open_sessions?: boolean }

const generateDailyReport = asyncHandler(async (req, res) => {
  const date = validateReportDate(req.body.date || todayStr());

  const result = await db.withTransaction(async (client) => {
    // 1. Pre-flight: refuse to generate if any session is still open for the
    //    target date — except today's report when force_close_open_sessions
    //    is explicitly true (admin acknowledges they're closing them now).
    const { rows: openSessions } = await client.query(
      `SELECT cs.id, u.full_name AS cashier_name, s.name AS store_name
       FROM cashier_sessions cs
       JOIN users  u ON u.id = cs.cashier_id
       JOIN stores s ON s.id = cs.store_id
       WHERE cs.session_date = $1 AND cs.status = 'open'`,
      [date]
    );

    if (openSessions.length > 0) {
      if (!req.body.force_close_open_sessions) {
        const list = openSessions.map((s) => `${s.cashier_name} (${s.store_name})`).join(', ');
        throw AppError.conflict(
          `Cannot generate report: ${openSessions.length} session(s) still open — ${list}.`,
          'OPEN_SESSIONS_BLOCKING'
        );
      }
      // Force-close the open sessions
      await client.query(
        `UPDATE cashier_sessions SET status = 'closed', closed_at = NOW()
         WHERE session_date = $1 AND status = 'open'`,
        [date]
      );
      for (const s of openSessions) {
        audit({
          userId:      req.user.id,
          action:      'SESSION_CLOSE',
          table:       'cashier_sessions',
          recordId:    s.id,
          description: `Force-closed during report generation for ${date}`,
          ip:          req.clientIp,
        });
      }
    }

    // 2. Pull closed-session live totals for the target date
    const { rows: sessionTotals } = await client.query(
      `SELECT v.*
       FROM v_session_live_totals v
       JOIN cashier_sessions cs ON cs.id = v.session_id
       WHERE cs.session_date = $1 AND cs.status = 'closed'`,
      [date]
    );

    if (sessionTotals.length === 0) {
      throw AppError.badRequest(
        `No closed sessions exist for ${date}. Nothing to report.`,
        'NO_SESSIONS'
      );
    }

    // 3. Snapshot current pool & per-store register state
    const { rows: poolRows } = await client.query(
      `SELECT available_balance, available_bonus, available_points, updated_at
       FROM global_pool_state ORDER BY id DESC LIMIT 1`
    );
    const globalPool = poolRows[0] || {
      available_balance: 0, available_bonus: 0, available_points: 0,
    };

    // 4. For each session, fetch line-level details (sales, voids) so the
    //    snapshot is rich enough to support drill-down without re-joining.
    const sessionIds = sessionTotals.map((s) => s.session_id);

    const [
      { rows: simSales },
      { rows: stormEntries },
      { rows: accessorySales },
      { rows: debts },
    ] = await Promise.all([
      client.query(
        `SELECT id, session_id, offer_id, offer_name_snapshot, real_price_snapshot,
                selling_price_snapshot, points_snapshot, commission_snapshot,
                serial_number_snapshot, is_voided, void_reason, sold_at
         FROM session_sim_sales WHERE session_id = ANY($1::int[])
         ORDER BY sold_at`,
        [sessionIds]
      ),
      client.query(
        `SELECT id, session_id, amount, note, is_voided, void_reason, entered_at
         FROM session_storm_entries WHERE session_id = ANY($1::int[])
         ORDER BY entered_at`,
        [sessionIds]
      ),
      client.query(
        `SELECT id, session_id, product_id, product_name_snapshot, category_name_snapshot,
                price_snapshot, commission_snapshot, is_voided, void_reason, sold_at
         FROM session_accessory_sales WHERE session_id = ANY($1::int[])
         ORDER BY sold_at`,
        [sessionIds]
      ),
      client.query(
        `SELECT id, session_id, amount, description, is_voided, void_reason, entered_at
         FROM session_debts WHERE session_id = ANY($1::int[])
         ORDER BY entered_at`,
        [sessionIds]
      ),
    ]);

    // Group line items by session
    const groupBy = (rows) => {
      const map = new Map();
      for (const r of rows) {
        if (!map.has(r.session_id)) map.set(r.session_id, []);
        map.get(r.session_id).push(r);
      }
      return map;
    };
    const simBySession = groupBy(simSales);
    const stormBySession = groupBy(stormEntries);
    const accBySession = groupBy(accessorySales);
    const debtBySession = groupBy(debts);

    // 5. Group sessions by store
    const sessionsByStore = new Map();
    for (const s of sessionTotals) {
      if (!sessionsByStore.has(s.store_id)) sessionsByStore.set(s.store_id, []);
      sessionsByStore.get(s.store_id).push(s);
    }

    // 6. Generate (or skip if already generated) one report per store
    const generated = [];
    const skipped   = [];

    for (const [storeId, sList] of sessionsByStore) {
      const { rows: existing } = await client.query(
        `SELECT id FROM daily_reports WHERE report_date = $1 AND store_id = $2`,
        [date, storeId]
      );
      if (existing[0]) {
        skipped.push({ store_id: storeId, reason: 'already_generated' });
        continue;
      }

      // Aggregate totals for this store
      let total_sim_units = 0, total_real_price = 0, total_selling_price = 0;
      let total_points = 0, total_storm = 0, total_accessories = 0;
      let total_accessories_real = 0;
      let total_debts = 0, total_commissions = 0;
      let total_sim_profit = 0, total_accessory_profit = 0;

      const enrichedSessions = sList.map((s) => {
        total_sim_units        += parseInt(s.sim_units_sold, 10) || 0;
        total_real_price       += parseFloat(s.sim_total_real_price) || 0;
        total_selling_price    += parseFloat(s.sim_total_selling_price) || 0;
        total_points           += parseInt(s.sim_total_points, 10) || 0;
        total_storm            += parseFloat(s.storm_total) || 0;
        total_accessories      += parseFloat(s.accessories_total) || 0;
        total_accessories_real += parseFloat(s.accessories_total_real_price) || 0;
        total_debts            += parseFloat(s.debt_total) || 0;
        total_commissions      += parseFloat(s.total_cashier_benefit) || 0;
        total_sim_profit       += parseFloat(s.sim_total_profit) || 0;
        total_accessory_profit += parseFloat(s.accessories_total_profit) || 0;

        return {
          ...mapSession(s),
          sim_sales:        simBySession.get(s.session_id)   || [],
          storm_entries:    stormBySession.get(s.session_id) || [],
          accessory_sales:  accBySession.get(s.session_id)   || [],
          debts:            debtBySession.get(s.session_id) || [],
        };
      });

      // New formulas:
      //   SIM profit       = points + selling - real      (per unit, summed in view)
      //   Accessory profit = selling - real
      //   Storm profit     = amount (no cost basis)
      // Then subtract cashier commissions to get the store's gross profit.
      const gross_profit =
        total_sim_profit + total_accessory_profit + total_storm - total_commissions;

      // Latest register cash for this store
      const { rows: registerRows } = await client.query(
        `SELECT cash_amount, updated_at
         FROM store_register_state
         WHERE store_id = $1 ORDER BY id DESC LIMIT 1`,
        [storeId]
      );
      const register = registerRows[0] || { cash_amount: 0 };

      const snapshot = {
        sessions:    enrichedSessions,
        global_pool: globalPool,
        register,
      };

      const { rows: reportRows } = await client.query(
        `INSERT INTO daily_reports
           (report_date, store_id, created_by,
            total_sim_units, total_real_price, total_selling_price,
            total_points, total_storm, total_accessories,
            total_debts, total_commissions, gross_profit, snapshot)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
         RETURNING *`,
        [
          date, storeId, req.user.id,
          total_sim_units, total_real_price, total_selling_price,
          total_points, total_storm, total_accessories,
          total_debts, total_commissions, gross_profit,
          JSON.stringify(snapshot),
        ]
      );

      audit({
        userId:    req.user.id,
        action:    'REPORT_GENERATE',
        table:     'daily_reports',
        recordId:  reportRows[0].id,
        newValues: { date, store_id: storeId, total_revenue: total_selling_price + total_storm + total_accessories, gross_profit },
        ip:        req.clientIp,
      });

      generated.push(reportRows[0]);
    }

    if (generated.length === 0) {
      throw AppError.conflict(
        `Reports for ${date} have already been generated for all stores with activity.`,
        'ALREADY_GENERATED'
      );
    }

    return { date, generated: generated.map(decorate), skipped };
  });

  sendCreated(res, result, 'Daily reports generated successfully.');
});

// ─── GET /api/reports ────────────────────────────────────────────────────────
// Query params: from, to, store_id, limit, offset

const getReports = asyncHandler(async (req, res) => {
  const conditions = [];
  const params     = [];

  if (req.query.from) {
    params.push(parseDate(req.query.from, 'from'));
    conditions.push(`d.report_date >= $${params.length}`);
  }
  if (req.query.to) {
    params.push(parseDate(req.query.to, 'to'));
    conditions.push(`d.report_date <= $${params.length}`);
  }
  if (req.query.store_id) {
    params.push(parseId(req.query.store_id, 'store_id'));
    conditions.push(`d.store_id = $${params.length}`);
  }
  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

  const limit  = Math.min(Math.max(parseInt(req.query.limit  || '100', 10), 1), 500);
  const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
  params.push(limit, offset);

  const { rows } = await db.query(
    `SELECT d.id, d.report_date, d.store_id, d.created_by, d.created_at,
            d.total_sim_units, d.total_real_price, d.total_selling_price,
            d.total_points, d.total_storm, d.total_accessories,
            d.total_debts, d.total_commissions, d.gross_profit,
            s.name     AS store_name,
            u.username AS generated_by,
            u.full_name AS generated_by_name
     FROM daily_reports d
     JOIN stores s ON s.id = d.store_id
     JOIN users  u ON u.id = d.created_by
     ${where}
     ORDER BY d.report_date DESC, d.store_id ASC
     LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params
  );

  sendSuccess(res, rows.map(decorate));
});

// ─── GET /api/reports/:id ────────────────────────────────────────────────────

const getReportById = asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const { rows } = await db.query(
    `SELECT d.*,
            s.name AS store_name,
            u.username AS generated_by,
            u.full_name AS generated_by_name
     FROM daily_reports d
     JOIN stores s ON s.id = d.store_id
     JOIN users  u ON u.id = d.created_by
     WHERE d.id = $1`,
    [id]
  );
  if (!rows[0]) throw AppError.notFound('Report not found.');
  sendSuccess(res, decorate(rows[0]));
});

// ─── GET /api/reports/range?from=YYYY-MM-DD&to=YYYY-MM-DD ────────────────────
//
// On-demand consolidated report over `[from, to]`. Cashiers see only their
// own data; admins see all cashiers and all stores. The report reads from
// live tables (no dependency on `daily_reports` snapshots) and rolls up the
// per-(cashier, store) cells returned by the database into per-cashier rows
// (one per cashier_id, per Requirement 4.7), per-store rows (admin only,
// Requirement 4.8), and grand totals (Requirement 4.6) in application code.

/** Zero-valued template for every numeric metric in the report. */
const ZERO_METRICS = () => ({
  sim_units_sold:                  0,
  sim_total_real_price:            0,
  sim_total_selling_price:         0,
  sim_total_points:                0,
  sim_total_commission:            0,
  storm_total:                     0,
  accessories_total_selling:       0,
  accessories_total_real:          0,
  accessories_total_commission:    0,
  debt_total:                      0,
  cashier_advance_total:           0,
  cashier_repayment_total:         0,
  register_expense_total:          0,
  register_expense_by_category:    { utility: 0, inventory: 0, other: 0 },
  sim_profit:                      0,
  accessory_profit:                0,
  gross_profit:                    0,
});

/**
 * Add the metric values from `src` into `dst` in place. `register_expense_by_category`
 * is added per-key. Derived fields (sim_profit, accessory_profit, gross_profit)
 * are NOT recomputed here — call `finalizeProfit()` after the rollup is done.
 */
const accumulate = (dst, src) => {
  dst.sim_units_sold               += src.sim_units_sold;
  dst.sim_total_real_price         += src.sim_total_real_price;
  dst.sim_total_selling_price      += src.sim_total_selling_price;
  dst.sim_total_points             += src.sim_total_points;
  dst.sim_total_commission         += src.sim_total_commission;
  dst.storm_total                  += src.storm_total;
  dst.accessories_total_selling    += src.accessories_total_selling;
  dst.accessories_total_real       += src.accessories_total_real;
  dst.accessories_total_commission += src.accessories_total_commission;
  dst.debt_total                   += src.debt_total;
  dst.cashier_advance_total        += src.cashier_advance_total;
  dst.cashier_repayment_total      += src.cashier_repayment_total;
  dst.register_expense_total       += src.register_expense_total;
  dst.register_expense_by_category.utility   += src.register_expense_by_category.utility;
  dst.register_expense_by_category.inventory += src.register_expense_by_category.inventory;
  dst.register_expense_by_category.other     += src.register_expense_by_category.other;
};

/**
 * Compute the derived profit fields per Requirement 4.6:
 *   sim_profit       = sim_total_points + sim_total_selling_price - sim_total_real_price
 *   accessory_profit = accessories_total_selling - accessories_total_real
 *   gross_profit     = sim_profit + accessory_profit + storm_total - register_expense_total
 */
const finalizeProfit = (m) => {
  m.sim_profit       = m.sim_total_points + m.sim_total_selling_price - m.sim_total_real_price;
  m.accessory_profit = m.accessories_total_selling - m.accessories_total_real;
  m.gross_profit     = m.sim_profit + m.accessory_profit + m.storm_total - m.register_expense_total;
};

const getDateRangeReport = asyncHandler(async (req, res) => {
  // 1. Parse and validate the date range.
  //    parseDateOnly + validateDateRange enforce the calendar/range/future
  //    rules; INVALID_DATE_RANGE / RANGE_TOO_LARGE / FUTURE_DATE are surfaced
  //    via AppError with the exact codes from the design.
  const { from, to } = validateDateRange(req.query.from, req.query.to);

  const isAdmin   = req.user.role === 'admin';
  const cashierId = isAdmin ? null : req.user.id;

  // 2. Single CTE-based query: one CTE per sale-bearing source table keyed on
  //    `(cashier_id, store_id)`, then a UNION of those keys is LEFT JOIN'ed
  //    to all four CTEs to project a per-(cashier, store) cell. The cashier
  //    scope filter is applied inside each CTE so PostgreSQL does the work.
  //    Advances and expenses come back in their natural grain (cashier_id
  //    only and (store_id, category) respectively) via separate queries —
  //    layering them in JS avoids double-counting per cashier when a cashier
  //    has activity across multiple stores.
  const cellsSql = `
    WITH
    sim AS (
      SELECT cs.cashier_id, cs.store_id,
             COUNT(*)::int                                  AS sim_units_sold,
             COALESCE(SUM(s.real_price_snapshot),     0)    AS sim_total_real_price,
             COALESCE(SUM(s.selling_price_snapshot),  0)    AS sim_total_selling_price,
             COALESCE(SUM(s.points_snapshot)::int,    0)    AS sim_total_points,
             COALESCE(SUM(s.commission_snapshot),     0)    AS sim_total_commission
        FROM session_sim_sales s
        JOIN cashier_sessions cs ON cs.id = s.session_id
       WHERE s.is_voided = FALSE
         AND s.sold_at::date BETWEEN $1 AND $2
         AND ($3::int IS NULL OR cs.cashier_id = $3)
       GROUP BY cs.cashier_id, cs.store_id
    ),
    storm AS (
      SELECT cs.cashier_id, cs.store_id,
             COALESCE(SUM(se.amount), 0) AS storm_total
        FROM session_storm_entries se
        JOIN cashier_sessions cs ON cs.id = se.session_id
       WHERE se.is_voided = FALSE
         AND se.entered_at::date BETWEEN $1 AND $2
         AND ($3::int IS NULL OR cs.cashier_id = $3)
       GROUP BY cs.cashier_id, cs.store_id
    ),
    acc AS (
      SELECT cs.cashier_id, cs.store_id,
             COALESCE(SUM(sa.price_snapshot),       0) AS accessories_total_selling,
             COALESCE(SUM(sa.real_price_snapshot),  0) AS accessories_total_real,
             COALESCE(SUM(sa.commission_snapshot),  0) AS accessories_total_commission
        FROM session_accessory_sales sa
        JOIN cashier_sessions cs ON cs.id = sa.session_id
       WHERE sa.is_voided = FALSE
         AND sa.sold_at::date BETWEEN $1 AND $2
         AND ($3::int IS NULL OR cs.cashier_id = $3)
       GROUP BY cs.cashier_id, cs.store_id
    ),
    debts AS (
      SELECT cs.cashier_id, cs.store_id,
             COALESCE(SUM(sd.amount), 0) AS debt_total
        FROM session_debts sd
        JOIN cashier_sessions cs ON cs.id = sd.session_id
       WHERE sd.is_voided = FALSE
         AND sd.entered_at::date BETWEEN $1 AND $2
         AND ($3::int IS NULL OR cs.cashier_id = $3)
       GROUP BY cs.cashier_id, cs.store_id
    ),
    cashier_keys AS (
      SELECT cashier_id, store_id FROM sim
      UNION SELECT cashier_id, store_id FROM storm
      UNION SELECT cashier_id, store_id FROM acc
      UNION SELECT cashier_id, store_id FROM debts
    )
    SELECT ck.cashier_id, ck.store_id,
           u.full_name  AS cashier_full_name,
           st.name      AS store_name,

           COALESCE(sim.sim_units_sold,            0) AS sim_units_sold,
           COALESCE(sim.sim_total_real_price,      0) AS sim_total_real_price,
           COALESCE(sim.sim_total_selling_price,   0) AS sim_total_selling_price,
           COALESCE(sim.sim_total_points,          0) AS sim_total_points,
           COALESCE(sim.sim_total_commission,      0) AS sim_total_commission,

           COALESCE(storm.storm_total,             0) AS storm_total,

           COALESCE(acc.accessories_total_selling,    0) AS accessories_total_selling,
           COALESCE(acc.accessories_total_real,       0) AS accessories_total_real,
           COALESCE(acc.accessories_total_commission, 0) AS accessories_total_commission,

           COALESCE(debts.debt_total,              0) AS debt_total
      FROM cashier_keys ck
      LEFT JOIN users  u  ON u.id  = ck.cashier_id
      LEFT JOIN stores st ON st.id = ck.store_id
      LEFT JOIN sim   ON sim.cashier_id   = ck.cashier_id AND sim.store_id   = ck.store_id
      LEFT JOIN storm ON storm.cashier_id = ck.cashier_id AND storm.store_id = ck.store_id
      LEFT JOIN acc   ON acc.cashier_id   = ck.cashier_id AND acc.store_id   = ck.store_id
      LEFT JOIN debts ON debts.cashier_id = ck.cashier_id AND debts.store_id = ck.store_id
     ORDER BY u.full_name NULLS LAST, st.name NULLS LAST
  `;

  const advancesSql = `
    SELECT ca.cashier_id,
           u.full_name AS cashier_full_name,
           u.store_id  AS user_store_id,
           COALESCE(SUM(ca.amount) FILTER (WHERE ca.direction = 'advance'),   0) AS cashier_advance_total,
           COALESCE(SUM(ca.amount) FILTER (WHERE ca.direction = 'repayment'), 0) AS cashier_repayment_total
      FROM cashier_advances ca
      JOIN users u ON u.id = ca.cashier_id
     WHERE ca.is_voided = FALSE
       AND ca.created_at::date BETWEEN $1 AND $2
       AND ($3::int IS NULL OR ca.cashier_id = $3)
     GROUP BY ca.cashier_id, u.full_name, u.store_id
  `;

  const expensesSql = `
    SELECT re.store_id, re.category, COALESCE(SUM(re.amount), 0) AS amt
      FROM register_expenses re
     WHERE re.is_voided = FALSE
       AND re.expense_date BETWEEN $1 AND $2
       AND ($3::int IS NULL OR re.store_id IN (
            -- Cashier scope: limit to stores where this cashier has had a
            -- session. Admin scope ($3 = NULL) returns every store.
            SELECT DISTINCT cs.store_id FROM cashier_sessions cs
             WHERE cs.cashier_id = $3
       ))
     GROUP BY re.store_id, re.category
  `;

  const debtsSql = `
    SELECT sd.id, sd.session_id, sd.amount, sd.description, sd.entered_at,
           c.id           AS customer_id,
           (c.first_name || ' ' || c.last_name) AS full_name,
           c.phone_number,
           c.profession
      FROM session_debts sd
      JOIN cashier_sessions cs ON cs.id = sd.session_id
      JOIN customers c         ON c.id  = sd.customer_id
     WHERE sd.is_voided = FALSE
       AND sd.entered_at::date BETWEEN $1 AND $2
       AND ($3::int IS NULL OR cs.cashier_id = $3)
     ORDER BY sd.entered_at DESC, sd.id DESC
  `;

  const storesSql = `SELECT id, name FROM stores`;

  // 3. Issue the queries in parallel and time the round-trip. Anything over
  //    5 seconds emits a structured warning so ops can investigate without
  //    breaking the request (Requirement 4.14).
  const startedAt = Date.now();
  const [
    cellsRes,
    advanceRes,
    expenseRes,
    debtRes,
    storeRes,
  ] = await Promise.all([
    db.query(cellsSql,    [from, to, cashierId]),
    db.query(advancesSql, [from, to, cashierId]),
    db.query(expensesSql, [from, to, cashierId]),
    db.query(debtsSql,    [from, to, cashierId]),
    db.query(storesSql),
  ]);
  const elapsed_ms = Date.now() - startedAt;

  if (elapsed_ms > 5000) {
    logger.warn(
      { from, to, user_id: req.user.id, elapsed_ms },
      'Date-range report query exceeded 5000 ms'
    );
  }

  // 4. Index lookups for downstream rollups.
  const storeNameById = new Map(storeRes.rows.map((s) => [s.id, s.name]));

  // 4a. Per-(store_id, category) expense bucket — fed into per_store and totals.
  const expensesByStore = new Map();
  for (const e of expenseRes.rows) {
    if (!expensesByStore.has(e.store_id)) {
      expensesByStore.set(e.store_id, { utility: 0, inventory: 0, other: 0, total: 0 });
    }
    const bucket = expensesByStore.get(e.store_id);
    const amt    = Number(e.amt) || 0;
    bucket[e.category] = (bucket[e.category] || 0) + amt;
    bucket.total      += amt;
  }

  // 4b. Per-cashier advance totals (already aggregated by SQL).
  const advancesByCashier = new Map();
  for (const a of advanceRes.rows) {
    advancesByCashier.set(a.cashier_id, {
      cashier_id:         a.cashier_id,
      cashier_full_name:  a.cashier_full_name,
      user_store_id:      a.user_store_id,
      advance_total:      parseFloat(a.cashier_advance_total)   || 0,
      repayment_total:    parseFloat(a.cashier_repayment_total) || 0,
    });
  }

  // 5. Cells from the SQL → per-(cashier, store) entries used to drive the
  //    per_cashier rollup AND the per_store rollup. Storing them once and
  //    iterating twice keeps the totals provably consistent.
  const cells = cellsRes.rows.map((r) => {
    const m = ZERO_METRICS();
    m.sim_units_sold               = parseInt(r.sim_units_sold, 10)             || 0;
    m.sim_total_real_price         = parseFloat(r.sim_total_real_price)         || 0;
    m.sim_total_selling_price      = parseFloat(r.sim_total_selling_price)      || 0;
    m.sim_total_points             = parseInt(r.sim_total_points, 10)           || 0;
    m.sim_total_commission         = parseFloat(r.sim_total_commission)         || 0;
    m.storm_total                  = parseFloat(r.storm_total)                  || 0;
    m.accessories_total_selling    = parseFloat(r.accessories_total_selling)    || 0;
    m.accessories_total_real       = parseFloat(r.accessories_total_real)       || 0;
    m.accessories_total_commission = parseFloat(r.accessories_total_commission) || 0;
    m.debt_total                   = parseFloat(r.debt_total)                   || 0;
    return {
      cashier_id:        r.cashier_id,
      cashier_full_name: r.cashier_full_name || null,
      store_id:          r.store_id,
      store_name:        r.store_name || storeNameById.get(r.store_id) || null,
      metrics:           m,
    };
  });

  // 6. Per-cashier rollup (one row per cashier_id, per Requirement 4.7).
  //    Cashiers normally only ever have activity at one store, but the
  //    schema does not preclude multi-store activity, so we aggregate
  //    across the cashier's cells. The row's `store_id` is set to the
  //    cashier's `users.store_id` when known, else the dominant cell store,
  //    else null. Advances are layered in here.
  const cashierMap = new Map();
  const ensureCashier = (cashierId, fullName) => {
    if (!cashierMap.has(cashierId)) {
      cashierMap.set(cashierId, {
        cashier_id:        cashierId,
        cashier_full_name: fullName,
        store_id:          null,
        store_name:        null,
        cell_store_counts: new Map(),
        metrics:           ZERO_METRICS(),
      });
    }
    return cashierMap.get(cashierId);
  };

  for (const cell of cells) {
    if (cell.cashier_id == null) continue;
    const c = ensureCashier(cell.cashier_id, cell.cashier_full_name);
    accumulate(c.metrics, cell.metrics);
    c.cell_store_counts.set(
      cell.store_id,
      (c.cell_store_counts.get(cell.store_id) || 0) + 1
    );
  }

  for (const a of advancesByCashier.values()) {
    const c = ensureCashier(a.cashier_id, a.cashier_full_name);
    c.metrics.cashier_advance_total   += a.advance_total;
    c.metrics.cashier_repayment_total += a.repayment_total;
    if (c.store_id == null && a.user_store_id != null) {
      c.store_id = a.user_store_id;
    }
  }

  const per_cashier = Array.from(cashierMap.values()).map((c) => {
    // Pick a primary store for this cashier: prefer users.store_id (already
    // assigned via the advances pass above); otherwise the only / dominant
    // store from the sale cells; otherwise null.
    let primaryStore = c.store_id;
    if (primaryStore == null && c.cell_store_counts.size > 0) {
      let best = null, bestCount = -1;
      for (const [sid, n] of c.cell_store_counts) {
        if (n > bestCount) { best = sid; bestCount = n; }
      }
      primaryStore = best;
    }
    finalizeProfit(c.metrics);
    return {
      cashier_id:        c.cashier_id,
      cashier_full_name: c.cashier_full_name,
      store_id:          primaryStore,
      store_name:        primaryStore != null ? (storeNameById.get(primaryStore) || null) : null,
      ...c.metrics,
    };
  });

  // 7. Per-store rollup (admin only, Requirement 4.8). Sales/debts come
  //    from the per-(cashier, store) cells; register expenses come from
  //    the per-(store, category) bucket. Advances/repayments have no store
  //    dimension and are intentionally NOT attributed to per_store rows.
  let per_store = [];
  if (isAdmin) {
    const storeMap = new Map();
    const ensureStore = (sid) => {
      if (!storeMap.has(sid)) {
        storeMap.set(sid, {
          store_id:   sid,
          store_name: storeNameById.get(sid) || null,
          metrics:    ZERO_METRICS(),
        });
      }
      return storeMap.get(sid);
    };
    for (const cell of cells) {
      if (cell.store_id == null) continue;
      accumulate(ensureStore(cell.store_id).metrics, cell.metrics);
    }
    for (const [sid, bucket] of expensesByStore) {
      const s = ensureStore(sid);
      s.metrics.register_expense_total                  += bucket.total;
      s.metrics.register_expense_by_category.utility    += bucket.utility   || 0;
      s.metrics.register_expense_by_category.inventory  += bucket.inventory || 0;
      s.metrics.register_expense_by_category.other      += bucket.other     || 0;
    }
    per_store = Array.from(storeMap.values())
      .map((s) => {
        finalizeProfit(s.metrics);
        return { store_id: s.store_id, store_name: s.store_name, ...s.metrics };
      })
      .sort((a, b) => (a.store_id || 0) - (b.store_id || 0));
  }

  // 8. Grand totals: aggregate of all sale cells + all advances + all
  //    register expenses (already scoped by SQL). Building this from the
  //    same sources as per_cashier / per_store keeps Property 23 trivially
  //    true.
  const totals = ZERO_METRICS();
  for (const cell of cells) accumulate(totals, cell.metrics);
  for (const a of advancesByCashier.values()) {
    totals.cashier_advance_total   += a.advance_total;
    totals.cashier_repayment_total += a.repayment_total;
  }
  for (const bucket of expensesByStore.values()) {
    totals.register_expense_total                 += bucket.total;
    totals.register_expense_by_category.utility   += bucket.utility   || 0;
    totals.register_expense_by_category.inventory += bucket.inventory || 0;
    totals.register_expense_by_category.other     += bucket.other     || 0;
  }
  finalizeProfit(totals);

  // 9. Debt rows with linked customer info (Requirement 4.10).
  const debts = debtRes.rows.map((d) => ({
    id:          d.id,
    session_id:  d.session_id,
    amount:      parseFloat(d.amount) || 0,
    description: d.description,
    created_at:  d.entered_at,
    customer: {
      id:           d.customer_id,
      full_name:    d.full_name,
      phone_number: d.phone_number,
      profession:   d.profession,
    },
  }));

  // 10. Per-cashier advances summary (one row per cashier with advance_total,
  //     repayment_total, and the running outstanding_balance for the range).
  const advances = Array.from(advancesByCashier.values()).map((a) => ({
    cashier_id:          a.cashier_id,
    cashier_full_name:   a.cashier_full_name,
    advance_total:       a.advance_total,
    repayment_total:     a.repayment_total,
    outstanding_balance: Math.max(0, a.advance_total - a.repayment_total),
  }));

  // 11. Audit log: REPORT_GENERATE per Requirement 4.15. Fire-and-forget via
  //     the existing helper; the description carries the date range so it
  //     is searchable in `audit_logs.description` directly.
  audit({
    userId:      req.user.id,
    action:      'REPORT_GENERATE',
    table:       'daily_reports',
    description: `Date range report from=${from} to=${to}`,
    newValues:   {
      from,
      to,
      scope: isAdmin ? 'admin' : 'cashier',
      elapsed_ms,
    },
    ip: req.clientIp,
  });

  // 12. Final payload. `per_store` is omitted for cashiers per Requirement
  //     4.12 (server-side scope enforcement). When no rows fall in the range,
  //     totals contain zeros and every array is empty (Requirement 4.16).
  const payload = {
    from,
    to,
    scope:                isAdmin ? 'admin' : 'cashier',
    elapsed_ms,
    totals,
    per_cashier,
    debts,
    advances,
    expenses_by_category: {
      utility:   totals.register_expense_by_category.utility,
      inventory: totals.register_expense_by_category.inventory,
      other:     totals.register_expense_by_category.other,
    },
  };
  if (isAdmin) payload.per_store = per_store;

  sendSuccess(res, payload);
});

module.exports = {
  generateDailyReport,
  previewDailyReport,
  getReports,
  getReportById,
  getDateRangeReport,
};
