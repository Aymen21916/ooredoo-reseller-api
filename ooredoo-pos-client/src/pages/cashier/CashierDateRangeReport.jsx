import { useState, useMemo, useCallback } from 'react';
import api from '../../api/axios';
import { useAuth } from '../../hooks/useAuth';
import {
  Calendar, RefreshCw, AlertCircle, CheckCircle2,
  TrendingUp, Coins, Smartphone, Zap, CreditCard, Receipt,
  AlertTriangle, ArrowDownCircle, ArrowUpCircle, Wallet,
  FileText,
} from 'lucide-react';

// ─── Helpers ────────────────────────────────────────────────────────────────

const todayStr = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};

const formatDZD = (amount) =>
  new Intl.NumberFormat('fr-DZ', { style: 'currency', currency: 'DZD', maximumFractionDigits: 2 })
    .format(amount || 0);

const formatNumber = (n) =>
  new Intl.NumberFormat('fr-DZ').format(n || 0);

const formatDateShort = (dateString) =>
  new Date(dateString).toLocaleDateString('en-GB', {
    year: 'numeric', month: 'short', day: '2-digit',
  });

const formatDateTime = (ts) =>
  ts
    ? new Date(ts).toLocaleString('en-GB', {
        year: 'numeric', month: 'short', day: '2-digit',
        hour: '2-digit', minute: '2-digit',
      })
    : '—';

// Map server error codes onto user-facing copy. The server is authoritative
// on the date range rules (see Requirements 4.1/4.2/4.3); the UI just
// surfaces the message inline.
const ERROR_COPY = {
  INVALID_DATE_RANGE: 'The "to" date must be on or after the "from" date.',
  RANGE_TOO_LARGE:    'The selected range is too large (maximum 366 days).',
  FUTURE_DATE:        'Dates cannot be in the future.',
};

// Number of days between two YYYY-MM-DD strings, inclusive on both ends.
// Used purely as a UX hint — the server is still the authority (Req 4.3).
const daysBetweenInclusive = (from, to) => {
  if (!from || !to) return 0;
  const a = new Date(`${from}T00:00:00`);
  const b = new Date(`${to}T00:00:00`);
  if (isNaN(a) || isNaN(b)) return 0;
  return Math.floor((b - a) / 86_400_000) + 1;
};

// ─── Page ───────────────────────────────────────────────────────────────────

export default function CashierDateRangeReport() {
  const { user } = useAuth();
  const today = todayStr();

  // Default range: today → today.
  const [fromDate, setFromDate] = useState(today);
  const [toDate, setToDate]     = useState(today);

  const [report, setReport]     = useState(null);
  const [loading, setLoading]   = useState(false);
  const [error, setError]       = useState('');

  const dayCount = useMemo(
    () => daysBetweenInclusive(fromDate, toDate),
    [fromDate, toDate]
  );

  // Client-side guards mirror the server validation (Req 4.1-4.3) and are
  // purely a UX hint. The submit handler still trusts the server response.
  const clientHint = useMemo(() => {
    if (!fromDate || !toDate) return 'Pick both a start and an end date.';
    if (toDate < fromDate)    return ERROR_COPY.INVALID_DATE_RANGE;
    if (toDate > today || fromDate > today) return ERROR_COPY.FUTURE_DATE;
    if (dayCount > 366)       return ERROR_COPY.RANGE_TOO_LARGE;
    return null;
  }, [fromDate, toDate, today, dayCount]);

  const fetchReport = useCallback(async () => {
    setLoading(true);
    setError('');
    setReport(null);
    try {
      const r = await api.get('/reports/range', {
        params: { from: fromDate, to: toDate },
      });
      setReport(r.data.data);
    } catch (err) {
      const code = err.response?.data?.code;
      setError(ERROR_COPY[code] || err.response?.data?.message || 'Failed to load report.');
    } finally {
      setLoading(false);
    }
  }, [fromDate, toDate]);

  const handleSubmit = (e) => {
    e.preventDefault();
    if (clientHint) {
      setError(clientHint);
      return;
    }
    fetchReport();
  };

  // ─── Render ───────────────────────────────────────────────────────────────

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-gray-200 pb-4">
        <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
          <FileText className="text-red-600" /> My Date-Range Report
        </h1>
      </div>

      {/* ─── Date-range picker ─────────────────────────────────────────── */}
      <section className="bg-white rounded-xl shadow-sm ring-1 ring-gray-200 p-6">
        <form
          onSubmit={handleSubmit}
          className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4"
        >
          <div className="flex flex-col sm:flex-row gap-4">
            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-1 flex items-center gap-1">
                <Calendar size={14} /> From
              </label>
              <input
                type="date"
                value={fromDate}
                max={today}
                onChange={(e) => setFromDate(e.target.value)}
                className="rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-red-500 focus:ring-red-500"
                required
              />
            </div>
            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-1 flex items-center gap-1">
                <Calendar size={14} /> To
              </label>
              <input
                type="date"
                value={toDate}
                min={fromDate || undefined}
                max={today}
                onChange={(e) => setToDate(e.target.value)}
                className="rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-red-500 focus:ring-red-500"
                required
              />
              <p className="mt-1 text-xs text-gray-500">
                {dayCount > 0
                  ? `${dayCount} day${dayCount === 1 ? '' : 's'} selected`
                  : ' '}
              </p>
            </div>
          </div>

          <button
            type="submit"
            disabled={loading || !!clientHint}
            className="inline-flex items-center gap-2 rounded-md bg-red-600 px-5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? <RefreshCw size={16} className="animate-spin" /> : <CheckCircle2 size={16} />}
            {loading ? 'Loading…' : 'Run Report'}
          </button>
        </form>

        {/* Inline client-side hint (only when nothing else is shown) */}
        {clientHint && !error && !loading && (
          <p className="mt-3 text-xs text-amber-700 flex items-center gap-1">
            <AlertTriangle size={12} /> {clientHint}
          </p>
        )}
      </section>

      {/* Error banner (server or client) */}
      {error && (
        <div className="rounded-md border border-red-200 bg-red-50 p-4 text-sm text-red-700 flex items-start gap-2">
          <AlertCircle size={18} className="mt-0.5 flex-shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* ─── Report body ──────────────────────────────────────────────── */}
      {loading && !report && (
        <div className="flex justify-center py-12">
          <RefreshCw className="animate-spin text-red-600" size={28} />
        </div>
      )}

      {report && (
        <ReportBody report={report} cashierId={user?.id} />
      )}
    </div>
  );
}

// ─── Report body ────────────────────────────────────────────────────────────

function ReportBody({ report, cashierId }) {
  const totals = report.totals || {};

  // Defensive scope filter: even though the server omits `per_store` and
  // restricts `per_cashier` to the requesting cashier (Req 4.5/4.12),
  // the cashier UI MUST NOT render other cashiers' rows or per-store
  // rollups even if they accidentally appear in the payload.
  const myCashierRow = useMemo(
    () => (report.per_cashier || []).find((r) => r.cashier_id === cashierId) || null,
    [report.per_cashier, cashierId]
  );

  const myDebts = useMemo(
    () => (report.debts || []), // server already scopes to this cashier
    [report.debts]
  );

  const myAdvanceRow = useMemo(
    () => (report.advances || []).find((a) => a.cashier_id === cashierId) || null,
    [report.advances, cashierId]
  );

  const expensesByCategory = report.expenses_by_category || { utility: 0, inventory: 0, other: 0 };

  const isEmpty =
    !myCashierRow &&
    myDebts.length === 0 &&
    !myAdvanceRow &&
    (totals.register_expense_total || 0) === 0;

  return (
    <div className="space-y-6">
      {/* Range summary line */}
      <div className="rounded-md border border-gray-200 bg-gray-50 p-3 text-sm text-gray-700 flex flex-wrap items-center gap-x-4 gap-y-1">
        <span className="flex items-center gap-1 font-medium">
          <Calendar size={14} className="text-gray-500" />
          {formatDateShort(report.from)} → {formatDateShort(report.to)}
        </span>
        {typeof report.elapsed_ms === 'number' && (
          <span className="text-xs text-gray-500">
            generated in {report.elapsed_ms} ms
          </span>
        )}
      </div>

      {isEmpty ? (
        <div className="rounded-md border border-gray-200 bg-white p-10 text-center text-gray-500">
          No activity recorded in this range.
        </div>
      ) : (
        <>
          {/* Totals */}
          <TotalsSection totals={totals} expensesByCategory={expensesByCategory} />

          {/* My per-cashier section (Req 4.7 / 4.12) */}
          <MySectionCard cashierRow={myCashierRow} advanceRow={myAdvanceRow} />

          {/* My debts (Req 4.10) */}
          {myDebts.length > 0 && <DebtsTable debts={myDebts} />}
        </>
      )}
    </div>
  );
}

// ─── Totals section ─────────────────────────────────────────────────────────

function TotalsSection({ totals, expensesByCategory }) {
  return (
    <section className="space-y-3">
      <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
        <TrendingUp size={20} className="text-gray-600" /> Totals
      </h2>

      {/* Headline KPIs */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <Kpi
          icon={<Smartphone size={18} />}
          label="SIM units"
          value={formatNumber(totals.sim_units_sold)}
        />
        <Kpi
          icon={<TrendingUp size={18} />}
          label="SIM revenue"
          value={formatDZD(totals.sim_total_selling_price)}
          sub={`Cost ${formatDZD(totals.sim_total_real_price)}`}
        />
        <Kpi
          icon={<Zap size={18} />}
          label="Storm / Bundle"
          value={formatDZD(totals.storm_total)}
        />
        <Kpi
          icon={<CreditCard size={18} />}
          label="Accessories"
          value={formatDZD(totals.accessories_total_selling)}
          sub={`Cost ${formatDZD(totals.accessories_total_real)}`}
        />
      </div>

      {/* Profit & cash KPIs */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <Kpi
          icon={<Coins size={18} />}
          label="SIM profit"
          value={formatDZD(totals.sim_profit)}
          color={(totals.sim_profit || 0) >= 0 ? 'green' : 'red'}
          sub={`${formatNumber(totals.sim_total_points)} points`}
        />
        <Kpi
          icon={<Coins size={18} />}
          label="Accessory profit"
          value={formatDZD(totals.accessory_profit)}
          color={(totals.accessory_profit || 0) >= 0 ? 'green' : 'red'}
        />
        <Kpi
          icon={<Wallet size={18} />}
          label="Gross profit"
          value={formatDZD(totals.gross_profit)}
          color={(totals.gross_profit || 0) >= 0 ? 'green' : 'red'}
        />
        <Kpi
          icon={<AlertTriangle size={18} />}
          label="Debts"
          value={formatDZD(totals.debt_total)}
          color="red"
        />
      </div>

      {/* Cashier benefit + advances + expenses */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <Kpi
          icon={<CheckCircle2 size={18} />}
          label="My commissions"
          value={formatDZD(
            (totals.sim_total_commission || 0) +
            (totals.accessories_total_commission || 0)
          )}
          color="green"
          sub={`SIM ${formatDZD(totals.sim_total_commission)} + Acc ${formatDZD(totals.accessories_total_commission)}`}
        />
        <Kpi
          icon={<ArrowUpCircle size={18} />}
          label="Advances taken"
          value={formatDZD(totals.cashier_advance_total)}
        />
        <Kpi
          icon={<ArrowDownCircle size={18} />}
          label="Repayments"
          value={formatDZD(totals.cashier_repayment_total)}
          color="green"
        />
        <Kpi
          icon={<Receipt size={18} />}
          label="Register expenses"
          value={formatDZD(totals.register_expense_total)}
          color="red"
          sub={`Util ${formatDZD(expensesByCategory.utility)} • Inv ${formatDZD(expensesByCategory.inventory)} • Other ${formatDZD(expensesByCategory.other)}`}
        />
      </div>
    </section>
  );
}

// ─── My per-cashier card ────────────────────────────────────────────────────

function MySectionCard({ cashierRow, advanceRow }) {
  if (!cashierRow && !advanceRow) return null;

  const row = cashierRow || {};
  const adv = advanceRow || { advance_total: 0, repayment_total: 0, outstanding_balance: 0 };

  return (
    <section className="space-y-3">
      <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
        <Receipt size={20} className="text-gray-600" /> My Activity
      </h2>

      <div className="bg-white rounded-xl shadow-sm ring-1 ring-gray-200 p-6">
        <div className="flex items-center justify-between mb-4 pb-3 border-b border-gray-100">
          <div>
            <div className="text-sm text-gray-500">Cashier</div>
            <div className="font-bold text-gray-900">{row.cashier_full_name || '—'}</div>
          </div>
          <div className="text-right">
            <div className="text-sm text-gray-500">Store</div>
            <div className="font-medium text-gray-700">{row.store_name || '—'}</div>
          </div>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
          <KvRow label="SIM units"           value={formatNumber(row.sim_units_sold)} />
          <KvRow label="SIM revenue"         value={formatDZD(row.sim_total_selling_price)} sub={`Cost ${formatDZD(row.sim_total_real_price)}`} />
          <KvRow label="SIM points"          value={formatNumber(row.sim_total_points)} />
          <KvRow label="SIM commission"      value={formatDZD(row.sim_total_commission)} color="green" />

          <KvRow label="Storm"               value={formatDZD(row.storm_total)} />
          <KvRow label="Accessories"         value={formatDZD(row.accessories_total_selling)} sub={`Cost ${formatDZD(row.accessories_total_real)}`} />
          <KvRow label="Accessory commission" value={formatDZD(row.accessories_total_commission)} color="green" />
          <KvRow label="Debts"               value={formatDZD(row.debt_total)} color="red" />

          <KvRow label="SIM profit"          value={formatDZD(row.sim_profit)}       color={(row.sim_profit || 0) >= 0 ? 'green' : 'red'} />
          <KvRow label="Accessory profit"    value={formatDZD(row.accessory_profit)} color={(row.accessory_profit || 0) >= 0 ? 'green' : 'red'} />
          <KvRow label="Gross profit"        value={formatDZD(row.gross_profit)}     color={(row.gross_profit || 0) >= 0 ? 'green' : 'red'} />
          <KvRow label="Register expenses"   value={formatDZD(row.register_expense_total)} color="red" />
        </div>

        <div className="mt-5 pt-4 border-t border-gray-100">
          <div className="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-2">
            Advances ledger (in range)
          </div>
          <div className="grid grid-cols-3 gap-3 text-sm">
            <KvRow label="Advances taken"       value={formatDZD(adv.advance_total)} />
            <KvRow label="Repayments"           value={formatDZD(adv.repayment_total)} color="green" />
            <KvRow label="Outstanding balance"  value={formatDZD(adv.outstanding_balance)} color={(adv.outstanding_balance || 0) > 0 ? 'red' : 'gray'} />
          </div>
        </div>
      </div>
    </section>
  );
}

// ─── Debts table (Req 4.10) ────────────────────────────────────────────────

function DebtsTable({ debts }) {
  return (
    <section className="space-y-3">
      <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
        <AlertTriangle size={20} className="text-red-600" /> My Debts ({debts.length})
      </h2>

      <div className="bg-white rounded-xl shadow-sm ring-1 ring-gray-200 overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">When</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Customer</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Phone</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Profession</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Description</th>
              <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Amount</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {debts.map((d) => (
              <tr key={d.id} className="hover:bg-gray-50">
                <td className="px-4 py-3 whitespace-nowrap text-sm text-gray-700">{formatDateTime(d.created_at)}</td>
                <td className="px-4 py-3 whitespace-nowrap text-sm font-medium text-gray-900">{d.customer?.full_name || '—'}</td>
                <td className="px-4 py-3 whitespace-nowrap text-sm text-gray-700 font-mono">{d.customer?.phone_number || '—'}</td>
                <td className="px-4 py-3 whitespace-nowrap text-sm text-gray-700">{d.customer?.profession || '—'}</td>
                <td className="px-4 py-3 text-sm text-gray-700">{d.description || '—'}</td>
                <td className="px-4 py-3 whitespace-nowrap text-sm text-right font-semibold text-red-600">
                  {formatDZD(d.amount)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

// ─── Tiny presentational primitives ─────────────────────────────────────────

function Kpi({ icon, label, value, sub, color = 'gray' }) {
  const colors = {
    gray:  'text-gray-900',
    green: 'text-green-600',
    red:   'text-red-600',
  };
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-3">
      <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-gray-500">
        {icon} {label}
      </div>
      <div className={`mt-1 text-xl font-bold ${colors[color]}`}>{value}</div>
      {sub && <div className="text-xs text-gray-500 mt-0.5">{sub}</div>}
    </div>
  );
}

function KvRow({ label, value, sub, color = 'gray' }) {
  const colors = {
    gray:  'text-gray-900',
    green: 'text-green-600',
    red:   'text-red-600',
  };
  return (
    <div>
      <div className="text-xs text-gray-500">{label}</div>
      <div className={`font-semibold ${colors[color]}`}>{value}</div>
      {sub && <div className="text-xs text-gray-400">{sub}</div>}
    </div>
  );
}
