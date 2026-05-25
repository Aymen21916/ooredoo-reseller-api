import { useState, useEffect, useCallback } from 'react';
import {
  Receipt, Building2, Tag, Calendar, Filter, Plus, EyeOff,
  RefreshCw, X, AlertCircle, CheckCircle2, ChevronLeft, ChevronRight,
  Trash2,
} from 'lucide-react';
import api from '../../api/axios';
import RegisterExpenseModal from '../../components/RegisterExpenseModal.jsx';

// ─── Helpers ────────────────────────────────────────────────────────────────

const formatDZD = (n) =>
  new Intl.NumberFormat('fr-DZ', {
    style: 'currency',
    currency: 'DZD',
    maximumFractionDigits: 2,
  }).format(n || 0);

const formatDateShort = (s) =>
  s ? new Date(s).toLocaleDateString('en-GB', { year: 'numeric', month: 'short', day: '2-digit' }) : '—';

const formatDateTime = (s) =>
  s
    ? new Date(s).toLocaleString('en-GB', {
        year: 'numeric', month: 'short', day: '2-digit',
        hour: '2-digit', minute: '2-digit',
      })
    : '—';

const todayStr = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};

const CATEGORY_OPTIONS = [
  { value: '',          label: 'All categories' },
  { value: 'utility',   label: 'Utility' },
  { value: 'inventory', label: 'Inventory' },
  { value: 'other',     label: 'Other' },
];

const VOIDED_OPTIONS = [
  { value: 'false', label: 'Active only' },
  { value: 'true',  label: 'Voided only' },
  { value: 'all',   label: 'All' },
];

const PAGE_SIZE = 50;

const CATEGORY_BADGE = {
  utility:   'bg-blue-100 text-blue-700',
  inventory: 'bg-purple-100 text-purple-700',
  other:     'bg-gray-100 text-gray-700',
};

// ─── Page ───────────────────────────────────────────────────────────────────

export default function AdminExpenses() {
  // Filter state
  const [filters, setFilters] = useState({
    store_id: '',
    category: '',
    from:     '',
    to:       '',
    voided:   'false',
  });

  // Data state
  const [stores, setStores]       = useState([]);
  const [expenses, setExpenses]   = useState([]);
  const [offset, setOffset]       = useState(0);
  const [loading, setLoading]     = useState(false);
  const [error, setError]         = useState('');
  const [success, setSuccess]     = useState('');

  // Modal state
  const [createOpen, setCreateOpen] = useState(false);
  const [voidTarget, setVoidTarget] = useState(null);   // expense row to void
  const [voidReason, setVoidReason] = useState('');
  const [voidSubmitting, setVoidSubmitting] = useState(false);

  // ─── Fetch stores once for the filter dropdown ────────────────────────────
  useEffect(() => {
    api.get('/finances/registers')
      .then((r) => setStores(r.data.data || []))
      .catch(() => setStores([]));
  }, []);

  // ─── Fetch expenses whenever filters or pagination changes ────────────────
  const fetchExpenses = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const params = {
        limit:  PAGE_SIZE,
        offset,
      };
      if (filters.store_id) params.store_id = filters.store_id;
      if (filters.category) params.category = filters.category;
      if (filters.from)     params.from     = filters.from;
      if (filters.to)       params.to       = filters.to;
      if (filters.voided)   params.voided   = filters.voided;

      const r = await api.get('/finances/expenses', { params });
      setExpenses(r.data.data || []);
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to load expenses.');
      setExpenses([]);
    } finally {
      setLoading(false);
    }
  }, [filters, offset]);

  useEffect(() => {
    fetchExpenses();
  }, [fetchExpenses]);

  // Reset pagination whenever a filter changes.
  const updateFilter = (patch) => {
    setOffset(0);
    setFilters((f) => ({ ...f, ...patch }));
  };

  const clearFilters = () => {
    setOffset(0);
    setFilters({ store_id: '', category: '', from: '', to: '', voided: 'false' });
  };

  // ─── Create flow ──────────────────────────────────────────────────────────
  const handleCreated = () => {
    setCreateOpen(false);
    setSuccess('Expense recorded.');
    setOffset(0);
    fetchExpenses();
    setTimeout(() => setSuccess(''), 4000);
  };

  // ─── Void flow ────────────────────────────────────────────────────────────
  const openVoid = (row) => {
    setVoidTarget(row);
    setVoidReason('');
  };

  const closeVoid = () => {
    setVoidTarget(null);
    setVoidReason('');
  };

  const submitVoid = async (e) => {
    e.preventDefault();
    const reason = voidReason.trim();
    if (reason.length < 1 || reason.length > 500) {
      setError('Void reason must be 1..500 characters.');
      return;
    }
    setVoidSubmitting(true);
    setError('');
    try {
      await api.post(`/finances/expenses/${voidTarget.id}/void`, { reason });
      closeVoid();
      setSuccess(`Expense #${voidTarget.id} voided.`);
      fetchExpenses();
      setTimeout(() => setSuccess(''), 4000);
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to void expense.');
    } finally {
      setVoidSubmitting(false);
    }
  };

  // ─── Aggregates (current page) ────────────────────────────────────────────
  const pageTotal = expenses
    .filter((e) => !e.is_voided)
    .reduce((sum, e) => sum + Number(e.amount || 0), 0);

  const hasNextPage = expenses.length === PAGE_SIZE;
  const hasPrevPage = offset > 0;

  // ─── Render ───────────────────────────────────────────────────────────────

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-gray-200 pb-4">
        <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
          <Receipt className="text-red-600" /> Register Expenses
        </h1>
        <button
          onClick={() => setCreateOpen(true)}
          className="inline-flex items-center gap-2 rounded-md bg-red-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-red-700"
        >
          <Plus size={16} /> Record expense
        </button>
      </div>

      {/* Status banners */}
      {error && (
        <div className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700 flex items-start gap-2">
          <AlertCircle size={16} className="mt-0.5 flex-shrink-0" />
          <span>{error}</span>
        </div>
      )}
      {success && (
        <div className="rounded-md border border-green-200 bg-green-50 p-3 text-sm text-green-700 flex items-start gap-2">
          <CheckCircle2 size={16} className="mt-0.5 flex-shrink-0" />
          <span>{success}</span>
        </div>
      )}

      {/* ─── Filters ────────────────────────────────────────────────────── */}
      <section className="bg-white rounded-xl shadow-sm ring-1 ring-gray-200 p-4">
        <div className="flex items-center gap-2 mb-3 text-sm font-semibold text-gray-700">
          <Filter size={16} /> Filters
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3">
          {/* Store */}
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1 flex items-center gap-1">
              <Building2 size={12} /> Store
            </label>
            <select
              value={filters.store_id}
              onChange={(e) => updateFilter({ store_id: e.target.value })}
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-red-500 focus:ring-red-500"
            >
              <option value="">All stores</option>
              {stores.map((s) => (
                <option key={s.id} value={s.id}>{s.name}</option>
              ))}
            </select>
          </div>

          {/* Category */}
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1 flex items-center gap-1">
              <Tag size={12} /> Category
            </label>
            <select
              value={filters.category}
              onChange={(e) => updateFilter({ category: e.target.value })}
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-red-500 focus:ring-red-500"
            >
              {CATEGORY_OPTIONS.map((o) => (
                <option key={o.value} value={o.value}>{o.label}</option>
              ))}
            </select>
          </div>

          {/* From date */}
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1 flex items-center gap-1">
              <Calendar size={12} /> From
            </label>
            <input
              type="date"
              value={filters.from}
              max={filters.to || todayStr()}
              onChange={(e) => updateFilter({ from: e.target.value })}
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-red-500 focus:ring-red-500"
            />
          </div>

          {/* To date */}
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1 flex items-center gap-1">
              <Calendar size={12} /> To
            </label>
            <input
              type="date"
              value={filters.to}
              min={filters.from || undefined}
              max={todayStr()}
              onChange={(e) => updateFilter({ to: e.target.value })}
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-red-500 focus:ring-red-500"
            />
          </div>

          {/* Void state */}
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1 flex items-center gap-1">
              <EyeOff size={12} /> Void state
            </label>
            <select
              value={filters.voided}
              onChange={(e) => updateFilter({ voided: e.target.value })}
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-red-500 focus:ring-red-500"
            >
              {VOIDED_OPTIONS.map((o) => (
                <option key={o.value} value={o.value}>{o.label}</option>
              ))}
            </select>
          </div>
        </div>

        <div className="flex justify-end mt-3">
          <button
            onClick={clearFilters}
            className="text-xs font-medium text-gray-600 hover:text-red-600 inline-flex items-center gap-1"
          >
            <X size={12} /> Clear filters
          </button>
        </div>
      </section>

      {/* ─── Table ─────────────────────────────────────────────────────── */}
      <section className="bg-white rounded-xl shadow-sm ring-1 ring-gray-200 overflow-hidden">
        <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100 bg-gray-50">
          <div className="text-sm text-gray-600">
            {loading
              ? 'Loading…'
              : `Showing ${expenses.length} expense(s)` +
                (offset ? ` (page starting at ${offset + 1})` : '')}
          </div>
          <div className="text-sm text-gray-600">
            Page total (active): <span className="font-bold text-gray-900">{formatDZD(pageTotal)}</span>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <Th>Date</Th>
                <Th>Store</Th>
                <Th>Cashier</Th>
                <Th>Category</Th>
                <Th>Description</Th>
                <Th align="right">Amount</Th>
                <Th>Status</Th>
                <Th>Created</Th>
                <Th align="right">Actions</Th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-100">
              {loading ? (
                <tr>
                  <td colSpan="9" className="px-4 py-8 text-center">
                    <RefreshCw className="inline animate-spin text-red-600" />
                  </td>
                </tr>
              ) : expenses.length === 0 ? (
                <tr>
                  <td colSpan="9" className="px-4 py-12 text-center text-sm text-gray-500">
                    No expenses match the current filters.
                  </td>
                </tr>
              ) : (
                expenses.map((e) => (
                  <tr
                    key={e.id}
                    className={`hover:bg-gray-50 ${e.is_voided ? 'bg-red-50/40' : ''}`}
                  >
                    <td className="px-4 py-3 whitespace-nowrap text-sm font-medium text-gray-900">
                      {formatDateShort(e.expense_date)}
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap text-sm text-gray-700">
                      {e.store_name || `#${e.store_id}`}
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap text-sm text-gray-700">
                      {e.cashier_name || (e.session_id ? `#${e.session_id}` : 'Admin')}
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap text-sm">
                      <span className={`inline-flex rounded-full px-2 py-0.5 text-xs font-semibold capitalize ${CATEGORY_BADGE[e.category] || 'bg-gray-100 text-gray-700'}`}>
                        {e.category}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-700 max-w-md truncate" title={e.description}>
                      {e.description || '—'}
                    </td>
                    <td className={`px-4 py-3 whitespace-nowrap text-sm text-right font-bold ${e.is_voided ? 'text-gray-400 line-through' : 'text-gray-900'}`}>
                      {formatDZD(e.amount)}
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap text-sm">
                      {e.is_voided ? (
                        <span
                          className="inline-flex rounded-full bg-red-100 px-2 py-0.5 text-xs font-semibold text-red-700"
                          title={e.void_reason || ''}
                        >
                          Voided
                        </span>
                      ) : (
                        <span className="inline-flex rounded-full bg-green-100 px-2 py-0.5 text-xs font-semibold text-green-700">
                          Active
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap text-sm text-gray-500">
                      {formatDateTime(e.created_at)}
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap text-right">
                      {e.is_voided ? (
                        <span
                          className="text-xs text-gray-400 italic"
                          title={`Voided ${formatDateTime(e.voided_at)}`}
                        >
                          —
                        </span>
                      ) : (
                        <button
                          onClick={() => openVoid(e)}
                          className="inline-flex items-center gap-1 text-red-600 hover:text-red-900 text-sm font-medium"
                        >
                          <Trash2 size={14} /> Void
                        </button>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        <div className="flex items-center justify-between px-4 py-3 border-t border-gray-100 bg-gray-50">
          <div className="text-xs text-gray-500">
            Showing rows {expenses.length === 0 ? 0 : offset + 1} – {offset + expenses.length}
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => setOffset((o) => Math.max(0, o - PAGE_SIZE))}
              disabled={!hasPrevPage || loading}
              className="inline-flex items-center gap-1 rounded-md border border-gray-300 bg-white px-3 py-1.5 text-xs font-medium text-gray-700 shadow-sm hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <ChevronLeft size={14} /> Prev
            </button>
            <button
              onClick={() => setOffset((o) => o + PAGE_SIZE)}
              disabled={!hasNextPage || loading}
              className="inline-flex items-center gap-1 rounded-md border border-gray-300 bg-white px-3 py-1.5 text-xs font-medium text-gray-700 shadow-sm hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Next <ChevronRight size={14} />
            </button>
          </div>
        </div>
      </section>

      {/* ─── Create modal ─────────────────────────────────────────────── */}
      {createOpen && (
        <RegisterExpenseModal
          mode="admin"
          onClose={() => setCreateOpen(false)}
          onComplete={handleCreated}
        />
      )}

      {/* ─── Void modal ───────────────────────────────────────────────── */}
      {voidTarget && (
        <VoidExpenseModal
          expense={voidTarget}
          reason={voidReason}
          onReasonChange={setVoidReason}
          onClose={closeVoid}
          onSubmit={submitVoid}
          submitting={voidSubmitting}
        />
      )}
    </div>
  );
}

// ─── Subcomponents ──────────────────────────────────────────────────────────

function Th({ children, align = 'left' }) {
  return (
    <th
      className={`px-4 py-3 text-${align} text-xs font-medium text-gray-500 uppercase tracking-wider`}
    >
      {children}
    </th>
  );
}

function VoidExpenseModal({ expense, reason, onReasonChange, onClose, onSubmit, submitting }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-md overflow-hidden">
        <div className="flex items-center justify-between p-4 border-b border-gray-100 bg-gray-50">
          <h3 className="font-bold text-lg text-gray-900 flex items-center gap-2">
            <Trash2 size={18} className="text-red-600" /> Void expense #{expense.id}
          </h3>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <X size={20} />
          </button>
        </div>

        <form onSubmit={onSubmit} className="p-6 space-y-4">
          <div className="rounded-md bg-gray-50 border border-gray-200 p-3 text-sm">
            <div className="flex justify-between text-gray-600">
              <span>Store</span>
              <span className="font-medium text-gray-900">{expense.store_name || `#${expense.store_id}`}</span>
            </div>
            <div className="flex justify-between text-gray-600 mt-1">
              <span>Date</span>
              <span className="font-medium text-gray-900">{formatDateShort(expense.expense_date)}</span>
            </div>
            <div className="flex justify-between text-gray-600 mt-1">
              <span>Category</span>
              <span className="font-medium text-gray-900 capitalize">{expense.category}</span>
            </div>
            <div className="flex justify-between text-gray-600 mt-1">
              <span>Amount</span>
              <span className="font-bold text-red-600">{formatDZD(expense.amount)}</span>
            </div>
            <div className="text-gray-600 mt-2">
              <div className="text-xs uppercase tracking-wider mb-0.5">Description</div>
              <div className="text-sm text-gray-900">{expense.description}</div>
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Void reason <span className="text-red-600">*</span>
            </label>
            <textarea
              required
              value={reason}
              onChange={(e) => onReasonChange(e.target.value)}
              maxLength={500}
              rows={3}
              placeholder="Explain why this expense is being voided…"
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-red-500 focus:ring-red-500"
            />
            <div className="text-xs text-gray-500 text-right mt-1">{reason.length} / 500</div>
          </div>

          <div className="rounded-md bg-amber-50 border border-amber-200 p-3 text-xs text-amber-800">
            Voiding refunds the expense amount back into the store's register cash.
          </div>

          <div className="flex justify-end gap-3 pt-2 border-t border-gray-100">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={submitting || reason.trim().length < 1}
              className="px-4 py-2 text-sm font-semibold text-white bg-red-600 rounded-md hover:bg-red-700 disabled:opacity-50 inline-flex items-center gap-2"
            >
              {submitting ? <RefreshCw size={14} className="animate-spin" /> : <Trash2 size={14} />}
              {submitting ? 'Voiding…' : 'Confirm void'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
