import { useState, useMemo } from 'react';
import api from '../../api/axios';
import {
  Calendar, RefreshCw, AlertCircle, AlertTriangle, TrendingUp, Coins,
  Users, Building2, Receipt, Smartphone, Zap, CreditCard, Wallet,
  FileText, BarChart3, Filter,
} from 'lucide-react';

// ─── Helpers ────────────────────────────────────────────────────────────────

const todayStr = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};

const formatDZD = (amount) =>
  new Intl.NumberFormat('fr-DZ', { style: 'currency', currency: 'DZD', maximumFractionDigits: 2 })
    .format(Number(amount) || 0);

const formatNumber = (n) =>
  new Intl.NumberFormat('fr-DZ').format(Number(n) || 0);

const formatDateShort = (dateString) =>
  new Date(dateString).toLocaleDateString('en-GB', {
    year: 'numeric', month: 'short', day: '2-digit',
  });

const formatDateTime = (ts) =>
  ts ? new Date(ts).toLocaleString('en-GB', {
    year: 'numeric', month: 'short', day: '2-digit',
    hour: '2-digit', minute: '2-digit',
  }) : '—';

// Inclusive day-span between two YYYY-MM-DD strings.
const daysBetween = (from, to) => {
  if (!from || !to) return null;
  const a = new Date(`${from}T00:00:00`);
  const b = new Date(`${to}T00:00:00`);
  if (Number.isNaN(a.getTime()) || Number.isNaN(b.getTime())) return null;
  return Math.round((b - a) / (1000 * 60 * 60 * 24)) + 1;
};

// Map API error codes to inline messages. Anything else falls through to the
// raw `message` from the server.
const ERROR_MESSAGES = {
  INVALID_DATE_RANGE: 'The end date must be on or after the start date.',
  RANGE_TOO_LARGE:    'Please pick a span of 366 days or fewer.',
  FUTURE_DATE:        'Dates cannot be in the future.',
};

const TABS = [
  { id: 'totals',     label: 'Totals',                 icon: BarChart3 },
  { id: 'cashier',    label: 'Per cashier',            icon: Users },
  { id: 'store',      label: 'Per store',              icon: Building2, adminOnly: true },
  { id: 'debts',      label: 'Debts',                  icon: AlertCircle },
  { id: 'advances',   label: 'Advances / repayments',  icon: Wallet },
  { id: 'expenses',   label: 'Expenses by category',   icon: Receipt },
];

// ─── Page ───────────────────────────────────────────────────────────────────

export default function DateRangeReports() {
  const today = todayStr();

  // Default to a 30-day window ending today.
  const defaultFrom = (() => {
    const d = new Date();
    d.setDate(d.getDate() - 29);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  })();

  const [from, setFrom] = useState(defaultFrom);
  const [to, setTo]     = useState(today);
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [activeTab, setActiveTab] = useState('totals');

  // Span / future-date hints — server is still the source of truth.
  const span = daysBetween(from, to);

  const clientHint = useMemo(() => {
    if (!from || !to) return '';
    if (to < from)            return ERROR_MESSAGES.INVALID_DATE_RANGE;
    if (span && span > 366)   return ERROR_MESSAGES.RANGE_TOO_LARGE;
    if (from > today || to > today) return ERROR_MESSAGES.FUTURE_DATE;
    return '';
  }, [from, to, span, today]);

  const submit = async () => {
    setError('');
    setLoading(true);
    try {
      const r = await api.get('/reports/range', { params: { from, to } });
      setData(r.data.data);
    } catch (err) {
      const code = err.response?.data?.code;
      const friendly = code && ERROR_MESSAGES[code];
      setError(friendly || err.response?.data?.message || 'Failed to load report.');
      setData(null);
    } finally {
      setLoading(false);
    }
  };

  const isAdmin = data?.scope === 'admin';

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-gray-200 pb-4">
        <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
          <FileText className="text-red-600" /> Date-Range Report
        </h1>
      </div>

      {/* ─── Range picker ───────────────────────────────────────────────── */}
      <section className="bg-white rounded-xl shadow-sm ring-1 ring-gray-200 p-6 space-y-4">
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 items-end">
          <div>
            <label className="text-sm font-semibold text-gray-700 mb-1 flex items-center gap-1">
              <Calendar size={14} /> From
            </label>
            <input
              type="date"
              value={from}
              max={today}
              onChange={(e) => setFrom(e.target.value)}
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-red-500 focus:ring-red-500"
            />
          </div>
          <div>
            <label className="text-sm font-semibold text-gray-700 mb-1 flex items-center gap-1">
              <Calendar size={14} /> To
            </label>
            <input
              type="date"
              value={to}
              max={today}
              min={from || undefined}
              onChange={(e) => setTo(e.target.value)}
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-red-500 focus:ring-red-500"
            />
          </div>
          <button
            onClick={submit}
            disabled={loading || !!clientHint || !from || !to}
            className="inline-flex items-center justify-center gap-2 rounded-md bg-red-600 px-5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? <RefreshCw size={16} className="animate-spin" /> : <Filter size={16} />}
            {loading ? 'Loading…' : 'Run report'}
          </button>
        </div>

        <div className="flex flex-wrap items-center gap-3 text-xs text-gray-500">
          {span != null && <span>Span: {span} day{span === 1 ? '' : 's'} (max 366)</span>}
          {data && (
            <span className="text-gray-500">
              {formatDateShort(data.from)} → {formatDateShort(data.to)} • completed in {data.elapsed_ms} ms
            </span>
          )}
        </div>

        {clientHint && (
          <div className="rounded-md border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800 flex items-start gap-2">
            <AlertTriangle size={16} className="mt-0.5 flex-shrink-0" />
            <span>{clientHint}</span>
          </div>
        )}
        {error && (
          <div className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700 flex items-start gap-2">
            <AlertCircle size={16} className="mt-0.5 flex-shrink-0" />
            <span>{error}</span>
          </div>
        )}
      </section>

      {/* ─── Results ─────────────────────────────────────────────────────── */}
      {loading ? (
        <div className="flex justify-center py-16">
          <RefreshCw className="animate-spin text-red-600" size={28} />
        </div>
      ) : data ? (
        <section className="space-y-4">
          {/* Tabs */}
          <div className="bg-white rounded-xl shadow-sm ring-1 ring-gray-200 overflow-hidden">
            <nav className="flex overflow-x-auto border-b border-gray-200">
              {TABS
                .filter((t) => !t.adminOnly || isAdmin)
                .map((t) => {
                  const Icon = t.icon;
                  const active = activeTab === t.id;
                  return (
                    <button
                      key={t.id}
                      onClick={() => setActiveTab(t.id)}
                      className={`flex items-center gap-2 px-4 py-3 text-sm font-medium whitespace-nowrap transition-colors ${
                        active
                          ? 'border-b-2 border-red-600 text-red-600 bg-red-50'
                          : 'text-gray-600 hover:text-red-600 hover:bg-gray-50'
                      }`}
                    >
                      <Icon size={16} /> {t.label}
                    </button>
                  );
                })}
            </nav>

            <div className="p-6">
              {activeTab === 'totals'   && <TotalsTab    data={data} />}
              {activeTab === 'cashier'  && <PerCashierTab data={data} />}
              {activeTab === 'store'    && isAdmin && <PerStoreTab data={data} />}
              {activeTab === 'debts'    && <DebtsTab     data={data} />}
              {activeTab === 'advances' && <AdvancesTab  data={data} />}
              {activeTab === 'expenses' && <ExpensesTab  data={data} />}
            </div>
          </div>
        </section>
      ) : (
        <div className="rounded-md bg-gray-50 border border-gray-200 p-8 text-center text-sm text-gray-500">
          Pick a date range and click <span className="font-semibold">Run report</span> to load consolidated totals.
        </div>
      )}
    </div>
  );
}

// ─── Tab: Totals ────────────────────────────────────────────────────────────

function TotalsTab({ data }) {
  const t = data.totals;
  return (
    <div className="space-y-6">
      {/* Headline KPIs */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kpi
          icon={<TrendingUp size={16} />}
          label="Gross profit"
          value={formatDZD(t.gross_profit)}
          color={t.gross_profit >= 0 ? 'green' : 'red'}
        />
        <Kpi
          icon={<Smartphone size={16} />}
          label="SIM units"
          value={formatNumber(t.sim_units_sold)}
          sub={`Revenue ${formatDZD(t.sim_total_selling_price)}`}
        />
        <Kpi
          icon={<Zap size={16} />}
          label="Storm / bundles"
          value={formatDZD(t.storm_total)}
        />
        <Kpi
          icon={<CreditCard size={16} />}
          label="Accessories"
          value={formatDZD(t.accessories_total_selling)}
          sub={`Cost ${formatDZD(t.accessories_total_real)}`}
        />
      </div>

      {/* Profit decomposition */}
      <div className="rounded-lg border border-gray-200 bg-gray-50 p-4">
        <div className="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-3 flex items-center gap-1">
          <Coins size={14} /> Profit breakdown
        </div>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
          <KvRow label="SIM profit"        value={formatDZD(t.sim_profit)} />
          <KvRow label="Accessory profit"  value={formatDZD(t.accessory_profit)} />
          <KvRow label="Storm contribution" value={formatDZD(t.storm_total)} />
          <KvRow
            label="Register expenses"
            value={`− ${formatDZD(t.register_expense_total)}`}
            color="red"
          />
        </div>
      </div>

      {/* Sales / debts / cash flow */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        <div className="rounded-lg border border-gray-200 p-4 bg-white">
          <div className="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-3 flex items-center gap-1">
            <Smartphone size={14} /> SIM details
          </div>
          <div className="grid grid-cols-2 gap-2 text-sm">
            <KvRow label="Real cost"      value={formatDZD(t.sim_total_real_price)} />
            <KvRow label="Selling price"  value={formatDZD(t.sim_total_selling_price)} />
            <KvRow label="Points"         value={formatNumber(t.sim_total_points)} />
            <KvRow label="Commissions"    value={formatDZD(t.sim_total_commission)} />
          </div>
        </div>
        <div className="rounded-lg border border-gray-200 p-4 bg-white">
          <div className="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-3 flex items-center gap-1">
            <Wallet size={14} /> Cash flow
          </div>
          <div className="grid grid-cols-2 gap-2 text-sm">
            <KvRow label="Debts issued"   value={formatDZD(t.debt_total)} color="red" />
            <KvRow label="Advances"       value={formatDZD(t.cashier_advance_total)} color="red" />
            <KvRow label="Repayments"     value={formatDZD(t.cashier_repayment_total)} color="green" />
            <KvRow label="Expenses"       value={formatDZD(t.register_expense_total)} color="red" />
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── Tab: Per cashier ──────────────────────────────────────────────────────

function PerCashierTab({ data }) {
  const rows = data.per_cashier || [];
  if (rows.length === 0) {
    return <EmptyState message="No cashier had activity in this range." />;
  }
  return (
    <div className="overflow-x-auto">
      <table className="min-w-full divide-y divide-gray-200 text-sm">
        <thead className="bg-gray-50">
          <tr>
            <Th>Cashier</Th>
            <Th>Store</Th>
            <Th align="right">SIM units</Th>
            <Th align="right">SIM revenue</Th>
            <Th align="right">Storm</Th>
            <Th align="right">Accessories</Th>
            <Th align="right">Debts</Th>
            <Th align="right">Advances</Th>
            <Th align="right">Repayments</Th>
            <Th align="right">Expenses</Th>
            <Th align="right">Profit</Th>
          </tr>
        </thead>
        <tbody className="bg-white divide-y divide-gray-100">
          {rows.map((r) => (
            <tr key={r.cashier_id} className="hover:bg-gray-50">
              <Td className="font-medium text-gray-900">{r.cashier_full_name || `#${r.cashier_id}`}</Td>
              <Td className="text-gray-600">{r.store_name || '—'}</Td>
              <Td align="right">{formatNumber(r.sim_units_sold)}</Td>
              <Td align="right">{formatDZD(r.sim_total_selling_price)}</Td>
              <Td align="right">{formatDZD(r.storm_total)}</Td>
              <Td align="right">{formatDZD(r.accessories_total_selling)}</Td>
              <Td align="right" className="text-red-600">{formatDZD(r.debt_total)}</Td>
              <Td align="right" className="text-red-600">{formatDZD(r.cashier_advance_total)}</Td>
              <Td align="right" className="text-green-600">{formatDZD(r.cashier_repayment_total)}</Td>
              <Td align="right" className="text-red-600">{formatDZD(r.register_expense_total)}</Td>
              <Td
                align="right"
                className={`font-bold ${r.gross_profit >= 0 ? 'text-green-600' : 'text-red-600'}`}
              >
                {formatDZD(r.gross_profit)}
              </Td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// ─── Tab: Per store ────────────────────────────────────────────────────────

function PerStoreTab({ data }) {
  const rows = data.per_store || [];
  if (rows.length === 0) {
    return <EmptyState message="No store activity in this range." />;
  }
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
      {rows.map((s) => (
        <div key={s.store_id} className="rounded-lg border border-gray-200 bg-white p-5">
          <div className="flex items-center justify-between mb-3 pb-3 border-b border-gray-100">
            <div className="font-semibold text-gray-900 flex items-center gap-2">
              <Building2 size={16} className="text-red-600" /> {s.store_name || `Store #${s.store_id}`}
            </div>
            <div className={`text-lg font-bold ${s.gross_profit >= 0 ? 'text-green-600' : 'text-red-600'}`}>
              {formatDZD(s.gross_profit)}
            </div>
          </div>
          <div className="grid grid-cols-2 gap-y-2 gap-x-4 text-sm">
            <KvRow label="SIM units"     value={formatNumber(s.sim_units_sold)} />
            <KvRow label="SIM revenue"   value={formatDZD(s.sim_total_selling_price)} />
            <KvRow label="Storm"         value={formatDZD(s.storm_total)} />
            <KvRow label="Accessories"   value={formatDZD(s.accessories_total_selling)} />
            <KvRow label="Debts"         value={formatDZD(s.debt_total)} color="red" />
            <KvRow label="Expenses"      value={formatDZD(s.register_expense_total)} color="red" />
            <KvRow label="SIM profit"    value={formatDZD(s.sim_profit)} />
            <KvRow label="Acc. profit"   value={formatDZD(s.accessory_profit)} />
          </div>
        </div>
      ))}
    </div>
  );
}

// ─── Tab: Debts ────────────────────────────────────────────────────────────

function DebtsTab({ data }) {
  const rows = data.debts || [];
  const total = rows.reduce((sum, d) => sum + (Number(d.amount) || 0), 0);
  if (rows.length === 0) {
    return <EmptyState message="No debts recorded in this range." />;
  }
  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between text-sm">
        <span className="text-gray-500">{rows.length} debt{rows.length === 1 ? '' : 's'} in range</span>
        <span className="font-semibold text-red-600">Total {formatDZD(total)}</span>
      </div>
      <div className="overflow-x-auto rounded-lg border border-gray-200">
        <table className="min-w-full divide-y divide-gray-200 text-sm">
          <thead className="bg-gray-50">
            <tr>
              <Th>Date</Th>
              <Th>Customer</Th>
              <Th>Phone</Th>
              <Th>Profession</Th>
              <Th>Description</Th>
              <Th align="right">Amount</Th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-100">
            {rows.map((d) => (
              <tr key={d.id} className="hover:bg-gray-50">
                <Td className="text-gray-500 whitespace-nowrap">{formatDateTime(d.created_at)}</Td>
                <Td className="font-medium text-gray-900">{d.customer?.full_name || '—'}</Td>
                <Td className="text-gray-600 font-mono text-xs">{d.customer?.phone_number || '—'}</Td>
                <Td className="text-gray-600">{d.customer?.profession || '—'}</Td>
                <Td className="text-gray-700">{d.description || '—'}</Td>
                <Td align="right" className="text-red-600 font-semibold">{formatDZD(d.amount)}</Td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

// ─── Tab: Advances / repayments ─────────────────────────────────────────────

function AdvancesTab({ data }) {
  const rows = data.advances || [];
  if (rows.length === 0) {
    return <EmptyState message="No advances or repayments in this range." />;
  }
  const totals = rows.reduce(
    (acc, r) => ({
      adv: acc.adv + (Number(r.advance_total) || 0),
      rep: acc.rep + (Number(r.repayment_total) || 0),
      out: acc.out + (Number(r.outstanding_balance) || 0),
    }),
    { adv: 0, rep: 0, out: 0 },
  );
  return (
    <div className="space-y-3">
      <div className="grid grid-cols-3 gap-3">
        <Kpi label="Advances"            value={formatDZD(totals.adv)} color="red" />
        <Kpi label="Repayments"          value={formatDZD(totals.rep)} color="green" />
        <Kpi label="Outstanding (range)" value={formatDZD(totals.out)} />
      </div>
      <div className="overflow-x-auto rounded-lg border border-gray-200">
        <table className="min-w-full divide-y divide-gray-200 text-sm">
          <thead className="bg-gray-50">
            <tr>
              <Th>Cashier</Th>
              <Th align="right">Advances taken</Th>
              <Th align="right">Repayments</Th>
              <Th align="right">Outstanding (in range)</Th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-100">
            {rows.map((r) => (
              <tr key={r.cashier_id} className="hover:bg-gray-50">
                <Td className="font-medium text-gray-900">{r.cashier_full_name || `#${r.cashier_id}`}</Td>
                <Td align="right" className="text-red-600">{formatDZD(r.advance_total)}</Td>
                <Td align="right" className="text-green-600">{formatDZD(r.repayment_total)}</Td>
                <Td align="right" className="font-semibold">{formatDZD(r.outstanding_balance)}</Td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="text-xs text-gray-500">
        Outstanding shown here is computed from this range only. The live overall outstanding balance per
        cashier is available on the Advances admin page.
      </p>
    </div>
  );
}

// ─── Tab: Expenses by category ─────────────────────────────────────────────

function ExpensesTab({ data }) {
  const cat = data.expenses_by_category || { utility: 0, inventory: 0, other: 0 };
  const total = (Number(cat.utility) || 0) + (Number(cat.inventory) || 0) + (Number(cat.other) || 0);

  if (total === 0) {
    return <EmptyState message="No register expenses recorded in this range." />;
  }

  const pct = (n) => (total > 0 ? Math.round((Number(n) / total) * 100) : 0);

  const rows = [
    { key: 'utility',   label: 'Utility',   amount: cat.utility   },
    { key: 'inventory', label: 'Inventory', amount: cat.inventory },
    { key: 'other',     label: 'Other',     amount: cat.other     },
  ];

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        {rows.map((r) => (
          <div key={r.key} className="rounded-lg border border-gray-200 bg-white p-4">
            <div className="text-xs font-semibold uppercase tracking-wider text-gray-500">
              {r.label}
            </div>
            <div className="mt-1 text-2xl font-bold text-gray-900">{formatDZD(r.amount)}</div>
            <div className="mt-2 h-1.5 bg-gray-100 rounded-full overflow-hidden">
              <div className="h-full bg-red-600" style={{ width: `${pct(r.amount)}%` }} />
            </div>
            <div className="mt-1 text-xs text-gray-500">{pct(r.amount)}% of total</div>
          </div>
        ))}
      </div>
      <div className="rounded-lg border border-gray-200 bg-gray-50 p-4 flex items-center justify-between text-sm">
        <span className="text-gray-600 font-medium">Total register expenses in range</span>
        <span className="text-lg font-bold text-red-600">{formatDZD(total)}</span>
      </div>
    </div>
  );
}

// ─── Shared display primitives ─────────────────────────────────────────────

function Kpi({ icon, label, value, sub, color = 'gray' }) {
  const colors = { gray: 'text-gray-900', green: 'text-green-600', red: 'text-red-600' };
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-3">
      <div className="text-xs font-semibold uppercase tracking-wider text-gray-500 flex items-center gap-1">
        {icon} {label}
      </div>
      <div className={`mt-1 text-xl font-bold ${colors[color]}`}>{value}</div>
      {sub && <div className="text-xs text-gray-500 mt-0.5">{sub}</div>}
    </div>
  );
}

function KvRow({ label, value, color = 'gray' }) {
  const colors = { gray: 'text-gray-900', green: 'text-green-600', red: 'text-red-600' };
  return (
    <div>
      <div className="text-xs text-gray-500">{label}</div>
      <div className={`font-semibold ${colors[color]}`}>{value}</div>
    </div>
  );
}

function Th({ children, align = 'left' }) {
  const alignCls = align === 'right' ? 'text-right' : 'text-left';
  return (
    <th className={`px-4 py-2 text-xs font-medium text-gray-500 uppercase tracking-wider ${alignCls}`}>
      {children}
    </th>
  );
}

function Td({ children, align = 'left', className = '' }) {
  const alignCls = align === 'right' ? 'text-right' : 'text-left';
  return (
    <td className={`px-4 py-2 whitespace-nowrap ${alignCls} ${className}`}>
      {children}
    </td>
  );
}

function EmptyState({ message }) {
  return (
    <div className="rounded-md bg-gray-50 border border-gray-200 p-8 text-center text-sm text-gray-500">
      {message}
    </div>
  );
}
