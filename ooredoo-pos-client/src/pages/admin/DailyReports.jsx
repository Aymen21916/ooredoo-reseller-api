import { useState, useEffect, useCallback } from 'react';
import api from '../../api/axios';
import {
  FileText, Calendar, Eye, X, RefreshCw, AlertTriangle,
  CheckCircle2, Building2, Wallet, TrendingUp, AlertCircle, Lock,
  Smartphone, Zap, CreditCard, Receipt, Coins,
} from 'lucide-react';

const todayStr = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};

const formatDZD = (amount) =>
  new Intl.NumberFormat('fr-DZ', { style: 'currency', currency: 'DZD', maximumFractionDigits: 2 })
    .format(amount || 0);

const formatDateLong = (dateString) =>
  new Date(dateString).toLocaleDateString('en-GB', {
    weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
  });

const formatDateShort = (dateString) =>
  new Date(dateString).toLocaleDateString('en-GB', {
    year: 'numeric', month: 'short', day: '2-digit',
  });

const formatTime = (ts) => (ts ? new Date(ts).toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' }) : '—');

export default function DailyReports() {
  const today = todayStr();

  const [selectedDate, setSelectedDate] = useState(today);
  const [preview, setPreview]           = useState(null);
  const [previewLoading, setPreviewLoading] = useState(false);
  const [reports, setReports]           = useState([]);
  const [reportsLoading, setReportsLoading] = useState(true);
  const [generating, setGenerating]     = useState(false);
  const [error, setError]               = useState('');
  const [success, setSuccess]           = useState('');

  // Detail modal
  const [openReport, setOpenReport] = useState(null);
  const [detailLoading, setDetailLoading] = useState(false);

  // ─── Data loading ─────────────────────────────────────────────────────────

  const loadPreview = useCallback(async (date) => {
    setPreviewLoading(true);
    setError('');
    try {
      const r = await api.get('/reports/preview', { params: { date } });
      setPreview(r.data.data);
    } catch (err) {
      setPreview(null);
      setError(err.response?.data?.message || 'Failed to load preview.');
    } finally {
      setPreviewLoading(false);
    }
  }, []);

  const loadReports = useCallback(async () => {
    setReportsLoading(true);
    try {
      const r = await api.get('/reports', { params: { limit: 100 } });
      setReports(r.data.data);
    } catch (err) {
      console.error(err);
    } finally {
      setReportsLoading(false);
    }
  }, []);

  useEffect(() => {
    loadReports();
  }, [loadReports]);

  useEffect(() => {
    loadPreview(selectedDate);
  }, [selectedDate, loadPreview]);

  // ─── Generate ─────────────────────────────────────────────────────────────

  const handleGenerate = async () => {
    if (!preview?.can_generate) return;

    const summary = preview.stores_summary
      .filter((s) => !s.already_generated && s.sessions_included > 0)
      .map((s) => `• ${s.store_name}: ${s.sessions_included} session(s), revenue ${formatDZD(s.total_revenue)}`)
      .join('\n');

    if (!window.confirm(`Generate end-of-day report(s) for ${selectedDate}?\n\n${summary}\n\nThis is permanent — reports cannot be edited after creation.`)) {
      return;
    }

    setGenerating(true);
    setError('');
    setSuccess('');
    try {
      const r = await api.post('/reports/generate', { date: selectedDate });
      const generatedCount = r.data.data.generated.length;
      setSuccess(`Generated ${generatedCount} report(s) for ${selectedDate}.`);
      await Promise.all([loadPreview(selectedDate), loadReports()]);
      setTimeout(() => setSuccess(''), 5000);
    } catch (err) {
      // Handle blocking-open-sessions case
      if (err.response?.data?.code === 'OPEN_SESSIONS_BLOCKING') {
        const force = window.confirm(`${err.response.data.message}\n\nForce-close those sessions now and continue?`);
        if (force) {
          try {
            const r = await api.post('/reports/generate', { date: selectedDate, force_close_open_sessions: true });
            setSuccess(`Generated ${r.data.data.generated.length} report(s) for ${selectedDate} (force-closed open sessions).`);
            await Promise.all([loadPreview(selectedDate), loadReports()]);
            setTimeout(() => setSuccess(''), 5000);
          } catch (err2) {
            setError(err2.response?.data?.message || 'Failed to generate.');
          }
        }
      } else {
        setError(err.response?.data?.message || 'Failed to generate.');
      }
    } finally {
      setGenerating(false);
    }
  };

  // ─── Detail view ─────────────────────────────────────────────────────────

  const openDetail = async (report) => {
    setDetailLoading(true);
    setOpenReport({ ...report, snapshot: null }); // open modal optimistically
    try {
      const r = await api.get(`/reports/${report.id}`);
      setOpenReport(r.data.data);
    } catch (err) {
      console.error(err);
      setOpenReport(null);
    } finally {
      setDetailLoading(false);
    }
  };

  // ─── Render ──────────────────────────────────────────────────────────────

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-gray-200 pb-4">
        <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
          <FileText className="text-red-600" /> End-of-Day Reports
        </h1>
      </div>

      {/* Status banners */}
      {error && (
        <div className="rounded-md border border-red-200 bg-red-50 p-4 text-sm text-red-700 flex items-start gap-2">
          <AlertCircle size={18} className="mt-0.5 flex-shrink-0" />
          <span>{error}</span>
        </div>
      )}
      {success && (
        <div className="rounded-md border border-green-200 bg-green-50 p-4 text-sm text-green-700 flex items-start gap-2">
          <CheckCircle2 size={18} className="mt-0.5 flex-shrink-0" />
          <span>{success}</span>
        </div>
      )}

      {/* ─── Generate panel ──────────────────────────────────────────────── */}
      <section className="bg-white rounded-xl shadow-sm ring-1 ring-gray-200 p-6 space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-1 flex items-center gap-1">
              <Calendar size={14} /> Report date
            </label>
            <input
              type="date"
              value={selectedDate}
              max={today}
              onChange={(e) => setSelectedDate(e.target.value)}
              className="rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-red-500 focus:ring-red-500"
            />
            <p className="mt-1 text-xs text-gray-500">
              {selectedDate === today ? 'Generating for today.' : `Back-dated to ${formatDateShort(selectedDate)}.`}
            </p>
          </div>

          <button
            onClick={handleGenerate}
            disabled={generating || previewLoading || !preview?.can_generate}
            className="inline-flex items-center gap-2 rounded-md bg-red-600 px-5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {generating ? <RefreshCw size={16} className="animate-spin" /> : <Lock size={16} />}
            {generating ? 'Generating...' : 'Generate Report(s)'}
          </button>
        </div>

        {/* Preview */}
        {previewLoading ? (
          <div className="flex justify-center py-6">
            <RefreshCw className="animate-spin text-red-600" />
          </div>
        ) : preview ? (
          <PreviewPanel preview={preview} />
        ) : null}
      </section>

      {/* ─── Past reports table ──────────────────────────────────────────── */}
      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
          <FileText size={20} className="text-gray-600" /> Past reports
        </h2>

        <div className="bg-white rounded-xl shadow-sm ring-1 ring-gray-200 overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Date</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Store</th>
                <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">SIM units</th>
                <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Revenue</th>
                <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Profit</th>
                <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Margin</th>
                <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Debts</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">By</th>
                <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {reportsLoading ? (
                <tr><td colSpan="9" className="px-4 py-8 text-center"><RefreshCw className="inline animate-spin text-red-600" /></td></tr>
              ) : reports.length === 0 ? (
                <tr><td colSpan="9" className="px-4 py-8 text-center text-gray-500">No reports generated yet.</td></tr>
              ) : (
                reports.map((r) => (
                  <tr key={r.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3 whitespace-nowrap text-sm font-medium text-gray-900">{formatDateShort(r.report_date)}</td>
                    <td className="px-4 py-3 whitespace-nowrap text-sm text-gray-700">{r.store_name}</td>
                    <td className="px-4 py-3 whitespace-nowrap text-sm text-right text-gray-700">{r.total_sim_units}</td>
                    <td className="px-4 py-3 whitespace-nowrap text-sm text-right font-medium text-gray-900">{formatDZD(r.total_revenue)}</td>
                    <td className={`px-4 py-3 whitespace-nowrap text-sm text-right font-bold ${r.gross_profit >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                      {formatDZD(r.gross_profit)}
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap text-sm text-right text-gray-600">
                      {r.margin_pct.toFixed(1)}%
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap text-sm text-right text-red-600">{formatDZD(r.total_debts)}</td>
                    <td className="px-4 py-3 whitespace-nowrap text-sm text-gray-500">@{r.generated_by}</td>
                    <td className="px-4 py-3 whitespace-nowrap text-right">
                      <button
                        onClick={() => openDetail(r)}
                        className="inline-flex items-center gap-1 text-red-600 hover:text-red-900 text-sm font-medium"
                      >
                        <Eye size={16} /> View
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      {/* ─── Detail modal ───────────────────────────────────────────────── */}
      {openReport && (
        <DetailModal
          report={openReport}
          loading={detailLoading}
          onClose={() => setOpenReport(null)}
        />
      )}
    </div>
  );
}

// ─── Preview Panel ──────────────────────────────────────────────────────────

function PreviewPanel({ preview }) {
  const totals = preview.stores_summary.reduce(
    (acc, s) => {
      if (!s.already_generated) {
        acc.revenue += s.total_revenue;
        acc.profit  += s.gross_profit;
        acc.sim     += s.total_sim_units;
      }
      return acc;
    },
    { revenue: 0, profit: 0, sim: 0 }
  );

  return (
    <div className="space-y-4 border-t border-gray-100 pt-4">
      {/* Open-session warning */}
      {preview.blocking_open_sessions > 0 && (
        <div className="rounded-md bg-amber-50 border border-amber-200 p-3 flex items-start gap-2 text-sm text-amber-800">
          <AlertTriangle size={18} className="mt-0.5 flex-shrink-0" />
          <div>
            <div className="font-semibold">{preview.blocking_open_sessions} open session(s) on this date.</div>
            <ul className="mt-1 ml-4 list-disc text-xs">
              {preview.open_sessions.map((s) => (
                <li key={s.session_id}>
                  {s.cashier_name} ({s.store_name})
                </li>
              ))}
            </ul>
            <div className="mt-1 text-xs">Either ask cashiers to close them, or generate to be prompted to force-close.</div>
          </div>
        </div>
      )}

      {/* Aggregate totals */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <KpiTile icon={<Receipt size={18} />} label="Closed sessions" value={preview.closed_sessions} />
        <KpiTile icon={<Smartphone size={18} />} label="SIM units" value={totals.sim} />
        <KpiTile icon={<TrendingUp size={18} />} label="Revenue" value={formatDZD(totals.revenue)} />
        <KpiTile
          icon={<Coins size={18} />}
          label="Gross profit"
          value={formatDZD(totals.profit)}
          color={totals.profit >= 0 ? 'green' : 'red'}
        />
      </div>

      {/* Per-store cards */}
      {preview.stores_summary.length === 0 ? (
        <div className="rounded-md bg-gray-50 border border-gray-200 p-4 text-sm text-gray-600 text-center">
          No closed sessions and no existing reports for this date.
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {preview.stores_summary.map((s) => (
            <StorePreviewCard key={s.store_id} store={s} />
          ))}
        </div>
      )}
    </div>
  );
}

function KpiTile({ icon, label, value, color = 'gray' }) {
  const colors = {
    gray:  'text-gray-900',
    green: 'text-green-600',
    red:   'text-red-600',
  };
  return (
    <div className="rounded-lg border border-gray-200 bg-gray-50 p-3">
      <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-gray-500">
        {icon} {label}
      </div>
      <div className={`mt-1 text-xl font-bold ${colors[color]}`}>{value}</div>
    </div>
  );
}

function StorePreviewCard({ store }) {
  return (
    <div
      className={`rounded-lg border p-4 ${
        store.already_generated
          ? 'bg-gray-50 border-gray-200'
          : 'bg-white border-gray-200'
      }`}
    >
      <div className="flex items-center justify-between mb-2">
        <div className="font-semibold text-gray-900 flex items-center gap-2">
          <Building2 size={16} className="text-red-600" /> {store.store_name}
        </div>
        {store.already_generated ? (
          <span className="inline-flex items-center gap-1 rounded-full bg-gray-200 px-2 py-0.5 text-xs font-semibold text-gray-700">
            <Lock size={11} /> Generated
          </span>
        ) : store.sessions_included === 0 ? (
          <span className="inline-flex rounded-full bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-700">
            No closed sessions
          </span>
        ) : (
          <span className="inline-flex rounded-full bg-green-100 px-2 py-0.5 text-xs font-semibold text-green-700">
            Ready
          </span>
        )}
      </div>
      {store.sessions_included > 0 && (
        <div className="grid grid-cols-2 gap-x-4 gap-y-1 text-sm">
          <div className="text-gray-500">Sessions</div>
          <div className="text-right font-medium">{store.sessions_included}</div>

          <div className="text-gray-500">SIM units</div>
          <div className="text-right font-medium">{store.total_sim_units}</div>

          <div className="text-gray-500">Revenue</div>
          <div className="text-right font-medium">{formatDZD(store.total_revenue)}</div>

          <div className="text-gray-500">Profit</div>
          <div className={`text-right font-bold ${store.gross_profit >= 0 ? 'text-green-600' : 'text-red-600'}`}>
            {formatDZD(store.gross_profit)}
          </div>
        </div>
      )}
    </div>
  );
}

// ─── Detail Modal ───────────────────────────────────────────────────────────

function DetailModal({ report, loading, onClose }) {
  const snapshot = report?.snapshot || {};
  const sessions = snapshot.sessions || [];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-5xl max-h-[92vh] flex flex-col">
        <div className="flex items-center justify-between p-4 border-b border-gray-100 bg-gray-50">
          <div>
            <h3 className="font-bold text-lg text-gray-900 flex items-center gap-2">
              <FileText className="text-red-600" size={20} />
              {report.store_name} — {formatDateLong(report.report_date)}
            </h3>
            <p className="text-xs text-gray-500 mt-0.5">
              Generated by @{report.generated_by} on {formatDateShort(report.created_at)} {formatTime(report.created_at)}
            </p>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600"><X size={20} /></button>
        </div>

        <div className="p-6 overflow-y-auto space-y-8">
          {loading ? (
            <div className="flex justify-center py-12"><RefreshCw className="animate-spin text-red-600" size={28} /></div>
          ) : (
            <>
              {/* Top KPIs */}
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                <Kpi label="Total revenue" value={formatDZD(report.total_revenue)} />
                <Kpi label="SIM cost"      value={formatDZD(report.total_real_price)} />
                <Kpi
                  label="Gross profit"
                  value={formatDZD(report.gross_profit)}
                  color={report.gross_profit >= 0 ? 'green' : 'red'}
                  sub={`${(report.margin_pct ?? 0).toFixed(1)}% margin`}
                />
                <Kpi label="Cashier commissions" value={formatDZD(report.total_commissions)} />

                <Kpi label="SIM revenue"   value={formatDZD(report.total_selling_price)} sub={`${report.total_sim_units} units`} />
                <Kpi label="Storm revenue" value={formatDZD(report.total_storm)} />
                <Kpi label="Accessories"   value={formatDZD(report.total_accessories)} />
                <Kpi label="Debts issued"  value={formatDZD(report.total_debts)} color="red" />
              </div>

              {/* Pool & register */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div className="rounded-lg border border-gray-200 p-4 bg-gray-50">
                  <div className="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-2 flex items-center gap-1">
                    <Wallet size={14} /> Global pool snapshot
                  </div>
                  <div className="grid grid-cols-3 gap-2 text-sm">
                    <div>
                      <div className="text-gray-500">Balance</div>
                      <div className="font-bold">{formatDZD(snapshot.global_pool?.available_balance)}</div>
                    </div>
                    <div>
                      <div className="text-gray-500">Bonus</div>
                      <div className="font-bold">{formatDZD(snapshot.global_pool?.available_bonus)}</div>
                    </div>
                    <div>
                      <div className="text-gray-500">Points</div>
                      <div className="font-bold">{(snapshot.global_pool?.available_points || 0).toLocaleString()}</div>
                    </div>
                  </div>
                </div>
                <div className="rounded-lg border border-gray-200 p-4 bg-gray-50">
                  <div className="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-2 flex items-center gap-1">
                    <Building2 size={14} /> Register cash
                  </div>
                  <div className="text-2xl font-bold text-gray-900">
                    {formatDZD(snapshot.register?.cash_amount ?? snapshot.register_cash?.cash_amount)}
                  </div>
                </div>
              </div>

              {/* Per-session breakdown */}
              <div>
                <h4 className="font-bold text-gray-900 mb-3 border-b border-gray-100 pb-2">
                  Sessions ({sessions.length})
                </h4>
                <div className="space-y-3">
                  {sessions.map((s) => (
                    <SessionCard key={s.session_id} session={s} />
                  ))}
                </div>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

function Kpi({ label, value, sub, color = 'gray' }) {
  const colors = { gray: 'text-gray-900', green: 'text-green-600', red: 'text-red-600' };
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-3">
      <div className="text-xs font-semibold uppercase tracking-wider text-gray-500">{label}</div>
      <div className={`mt-1 text-xl font-bold ${colors[color]}`}>{value}</div>
      {sub && <div className="text-xs text-gray-500 mt-0.5">{sub}</div>}
    </div>
  );
}

function SessionCard({ session }) {
  const [expanded, setExpanded] = useState(false);

  const sim   = session.sim_sales || [];
  const storm = session.storm_entries || [];
  const acc   = session.accessory_sales || [];
  const debts = session.debts || [];

  const voidedCount =
    sim.filter((x) => x.is_voided).length +
    storm.filter((x) => x.is_voided).length +
    acc.filter((x) => x.is_voided).length +
    debts.filter((x) => x.is_voided).length;

  return (
    <div className="border border-gray-200 rounded-lg bg-white">
      <button
        onClick={() => setExpanded((e) => !e)}
        className="w-full flex items-center justify-between p-4 hover:bg-gray-50 text-left"
      >
        <div>
          <div className="font-semibold text-gray-900">{session.cashier_name}</div>
          <div className="text-xs text-gray-500 mt-0.5">{session.store_name}</div>
        </div>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-x-4 text-sm">
          <SmallStat label="SIM" value={`${session.sim_units_sold}`} />
          <SmallStat label="Revenue" value={formatDZD(session.sim_total_selling_price + session.storm_total + session.accessories_total)} />
          <SmallStat label="Cash exp." value={formatDZD(session.expected_register_cash)} />
          <SmallStat
            label="Voids"
            value={voidedCount}
            color={voidedCount > 0 ? 'red' : 'gray'}
          />
        </div>
      </button>

      {expanded && (
        <div className="border-t border-gray-100 p-4 space-y-4 bg-gray-50">
          {/* Numbers row */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-sm">
            <KvRow label="Opening cash" value={formatDZD(session.opening_cash)} />
            <KvRow label="SIM revenue" value={formatDZD(session.sim_total_selling_price)} sub={`Cost ${formatDZD(session.sim_total_real_price)}`} />
            <KvRow label="Storm" value={formatDZD(session.storm_total)} />
            <KvRow label="Accessories" value={formatDZD(session.accessories_total)} />
            <KvRow label="Debts" value={formatDZD(session.debt_total)} color="red" />
            <KvRow label="Commissions" value={formatDZD(session.total_cashier_benefit)} />
            <KvRow label="Points generated" value={(session.sim_total_points || 0).toLocaleString()} />
            <KvRow label="Expected cash" value={formatDZD(session.expected_register_cash)} color="green" />
          </div>

          {/* Line items */}
          {sim.length > 0   && <LineItemList icon={<Smartphone size={14} />} title="SIM sales"        items={sim}   columns={['serial_number_snapshot', 'offer_name_snapshot', 'selling_price_snapshot']} headers={['Serial', 'Offer', 'Price']} />}
          {storm.length > 0 && <LineItemList icon={<Zap size={14} />}        title="Storm/Bundle"     items={storm} columns={['note', 'amount']} headers={['Note', 'Amount']} />}
          {acc.length > 0   && <LineItemList icon={<CreditCard size={14} />} title="Accessory sales"  items={acc}   columns={['product_name_snapshot', 'category_name_snapshot', 'price_snapshot']} headers={['Product', 'Category', 'Price']} />}
          {debts.length > 0 && <LineItemList icon={<AlertCircle size={14} />} title="Debts" items={debts} columns={['description', 'amount']} headers={['Description', 'Amount']} />}
        </div>
      )}
    </div>
  );
}

function SmallStat({ label, value, color = 'gray' }) {
  const colors = { gray: 'text-gray-900', red: 'text-red-600' };
  return (
    <div className="text-right">
      <div className="text-xs text-gray-500">{label}</div>
      <div className={`font-semibold ${colors[color]}`}>{value}</div>
    </div>
  );
}

function KvRow({ label, value, sub, color = 'gray' }) {
  const colors = { gray: 'text-gray-900', green: 'text-green-600', red: 'text-red-600' };
  return (
    <div>
      <div className="text-xs text-gray-500">{label}</div>
      <div className={`font-semibold ${colors[color]}`}>{value}</div>
      {sub && <div className="text-xs text-gray-400">{sub}</div>}
    </div>
  );
}

function LineItemList({ icon, title, items, columns, headers }) {
  const isMoneyCol = (key) => /price|amount|snapshot/.test(key) && !/serial|name|category/.test(key);

  const renderCell = (item, key) => {
    const val = item[key];
    if (val == null) return '—';
    if (isMoneyCol(key) && typeof val === 'number') return formatDZD(val);
    if (key === 'amount' || key === 'price_snapshot' || key === 'selling_price_snapshot') return formatDZD(val);
    return String(val);
  };

  return (
    <div>
      <div className="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-1 flex items-center gap-1">
        {icon} {title} ({items.length})
      </div>
      <div className="bg-white rounded-md border border-gray-200 overflow-x-auto">
        <table className="min-w-full text-xs">
          <thead className="bg-gray-50 text-gray-500">
            <tr>
              {headers.map((h, i) => (
                <th key={i} className={`px-2 py-1.5 text-left font-medium ${i === headers.length - 1 ? 'text-right' : ''}`}>{h}</th>
              ))}
              <th className="px-2 py-1.5 text-right font-medium">Time</th>
              <th className="px-2 py-1.5 text-center font-medium">Status</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {items.map((item) => (
              <tr key={item.id} className={item.is_voided ? 'bg-red-50/50 line-through text-gray-400' : ''}>
                {columns.map((col, i) => (
                  <td key={i} className={`px-2 py-1.5 ${i === columns.length - 1 ? 'text-right font-medium text-gray-900' : 'text-gray-700'}`}>
                    {renderCell(item, col)}
                  </td>
                ))}
                <td className="px-2 py-1.5 text-right text-gray-500 font-mono">
                  {formatTime(item.sold_at || item.entered_at)}
                </td>
                <td className="px-2 py-1.5 text-center">
                  {item.is_voided ? (
                    <span className="inline-flex rounded-full bg-red-100 px-1.5 text-xs font-semibold text-red-700" title={item.void_reason || ''}>
                      Void
                    </span>
                  ) : (
                    <span className="inline-flex rounded-full bg-green-100 px-1.5 text-xs font-semibold text-green-700">
                      OK
                    </span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
