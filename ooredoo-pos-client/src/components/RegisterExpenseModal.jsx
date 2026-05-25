import { useState, useEffect, useMemo } from 'react';
import api from '../api/axios';
import {
  X, Receipt, CheckCircle2, AlertTriangle, AlertCircle,
  Building2, Tag, Calendar, RefreshCw,
} from 'lucide-react';

// ─── Helpers ────────────────────────────────────────────────────────────────

const formatDZD = (n) =>
  new Intl.NumberFormat('fr-DZ', {
    style: 'currency',
    currency: 'DZD',
    maximumFractionDigits: 2,
  }).format(n || 0);

const todayStr = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};

// Validation constants — must mirror the server-side rules in
// `src/utils/validators.js` (Requirements 3.7).
const AMOUNT_MIN = 0.01;
const AMOUNT_MAX = 9_999_999.99;
const DESC_MIN   = 1;
const DESC_MAX   = 500;

const CATEGORY_OPTIONS = [
  { value: 'utility',   label: 'Utility' },
  { value: 'inventory', label: 'Inventory' },
  { value: 'other',     label: 'Other' },
];

// ─── Component ──────────────────────────────────────────────────────────────
//
//   Props:
//     mode:       'cashier' | 'admin'
//     sessionId?: number  (cashier; informational, server derives from auth)
//     storeId?:   number  (admin; preselected store in the dropdown)
//     onClose:    () => void
//     onComplete: (createdExpense) => void
//

export default function RegisterExpenseModal({
  mode = 'cashier',
  sessionId,
  storeId,
  onClose,
  onComplete,
}) {
  // ─── Form state ─────────────────────────────────────────────────────────
  const [amount, setAmount]           = useState('');
  const [description, setDescription] = useState('');
  const [category, setCategory]       = useState('utility');
  const [expenseDate, setExpenseDate] = useState(todayStr());
  const [selectedStore, setSelectedStore] = useState(storeId ? String(storeId) : '');

  // ─── Admin-only: store list ─────────────────────────────────────────────
  const [stores, setStores]           = useState([]);
  // Default to "loading" in admin mode so we don't trigger a synchronous
  // setState inside the effect body (eslint react-hooks/set-state-in-effect).
  const [storesLoading, setStoresLoading] = useState(mode === 'admin');

  // ─── Submission state ───────────────────────────────────────────────────
  const [submitting, setSubmitting]                       = useState(false);
  const [error, setError]                                 = useState('');
  const [insufficientBalance, setInsufficientBalance]     = useState(null);

  // Fetch the list of active stores when in admin mode. The cashier
  // path doesn't show a store picker — the server resolves it from the
  // authenticated user's `users.store_id` (Requirement 3.2).
  useEffect(() => {
    if (mode !== 'admin') return;
    let cancelled = false;
    api.get('/finances/registers')
      .then((r) => {
        if (cancelled) return;
        const list = r.data.data || [];
        setStores(list);
        if (!storeId && list.length > 0) {
          setSelectedStore(String(list[0].id));
        }
      })
      .catch(() => {
        if (!cancelled) setStores([]);
      })
      .finally(() => {
        if (!cancelled) setStoresLoading(false);
      });
    return () => { cancelled = true; };
  }, [mode, storeId]);

  // ─── Client-side validation (mirrors server) ────────────────────────────
  const validationError = useMemo(() => {
    const trimmedDesc = description.trim();
    const num = Number(amount);

    if (amount === '' || Number.isNaN(num)) {
      return 'Amount is required.';
    }
    if (!Number.isFinite(num) || num < AMOUNT_MIN || num > AMOUNT_MAX) {
      return `Amount must be between ${formatDZD(AMOUNT_MIN)} and ${formatDZD(AMOUNT_MAX)}.`;
    }
    // Reject more than 2 decimal places.
    if (!/^-?\d+(\.\d{1,2})?$/.test(String(amount).trim())) {
      return 'Amount can have at most two decimal places.';
    }
    if (trimmedDesc.length < DESC_MIN || trimmedDesc.length > DESC_MAX) {
      return `Description must be ${DESC_MIN}–${DESC_MAX} characters.`;
    }
    if (!CATEGORY_OPTIONS.some((c) => c.value === category)) {
      return 'Category must be utility, inventory, or other.';
    }
    if (mode === 'admin') {
      if (!selectedStore) return 'Please choose a store.';
      if (!expenseDate)   return 'Please choose an expense date.';
      if (expenseDate > todayStr()) {
        return 'Expense date cannot be in the future.';
      }
    }
    return '';
  }, [amount, description, category, mode, selectedStore, expenseDate]);

  // ─── Submit handler ─────────────────────────────────────────────────────
  const handleSubmit = async (e) => {
    e?.preventDefault?.();
    setError('');
    setInsufficientBalance(null);

    if (validationError) {
      setError(validationError);
      return;
    }

    const payload = {
      amount: Number(amount),
      description: description.trim(),
      category,
    };

    if (mode === 'admin') {
      payload.store_id = parseInt(selectedStore, 10);
      // Only send expense_date when the admin picked something other than today
      // (server defaults it to today otherwise — Requirement 3.5).
      if (expenseDate) payload.expense_date = expenseDate;
    }

    setSubmitting(true);
    try {
      const r = await api.post('/finances/expenses', payload);
      onComplete?.(r.data.data || r.data);
    } catch (err) {
      const data = err.response?.data || {};
      const code = data.code;

      if (code === 'INSUFFICIENT_REGISTER_CASH') {
        // Surface the current register balance returned by the server so the
        // user can see exactly how much cash is on hand (Requirement 3.9).
        setInsufficientBalance(
          typeof data.current_balance === 'number'
            ? data.current_balance
            : Number(data.current_balance) || 0
        );
        setError('');
      } else if (code === 'NO_OPEN_SESSION') {
        setError('You have no open session. Open one before recording expenses.');
      } else if (code === 'BACKDATE_FORBIDDEN') {
        setError('Cashiers cannot backdate register expenses.');
      } else if (code === 'FUTURE_DATE') {
        setError('Expense date cannot be in the future.');
      } else if (code === 'VALIDATION_ERROR') {
        setError(data.message || 'Some fields are invalid. Please check and try again.');
      } else {
        setError(data.message || 'Failed to record expense.');
      }
    } finally {
      setSubmitting(false);
    }
  };

  // ─── Render ─────────────────────────────────────────────────────────────
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <form
        onSubmit={handleSubmit}
        className="bg-white rounded-xl shadow-xl w-full max-w-lg max-h-[92vh] flex flex-col"
      >
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-gray-100 bg-gray-50">
          <h3 className="font-bold text-lg text-gray-900 flex items-center gap-2">
            <Receipt size={20} className="text-red-600" />
            Record register expense
          </h3>
          <button
            type="button"
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600"
            aria-label="Close"
          >
            <X size={20} />
          </button>
        </div>

        {/* Insufficient-balance banner (Requirement 3.9) */}
        {insufficientBalance !== null && (
          <div className="mx-4 mt-3 rounded-md bg-amber-50 border border-amber-200 p-3 text-sm text-amber-800 flex items-start gap-2">
            <AlertTriangle size={16} className="mt-0.5 flex-shrink-0" />
            <div>
              <div className="font-semibold">Not enough cash in the register.</div>
              <div className="mt-0.5">
                Current balance:{' '}
                <span className="font-mono font-semibold">{formatDZD(insufficientBalance)}</span>.
                Reduce the amount or wait for more inflow.
              </div>
            </div>
          </div>
        )}

        {/* Generic error banner */}
        {error && (
          <div className="mx-4 mt-3 rounded-md bg-red-50 border border-red-200 p-3 text-sm text-red-700 flex items-start gap-2">
            <AlertCircle size={16} className="mt-0.5 flex-shrink-0" />
            <span>{error}</span>
          </div>
        )}

        {/* Body */}
        <div className="p-6 overflow-y-auto flex-1 space-y-4">
          {/* Admin-only: store picker */}
          {mode === 'admin' && (
            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-gray-500 mb-1">
                <Building2 size={12} className="inline mr-1 -mt-0.5" />
                Store
              </label>
              {storesLoading ? (
                <div className="flex items-center gap-2 text-sm text-gray-500 py-2">
                  <RefreshCw size={14} className="animate-spin" /> Loading stores…
                </div>
              ) : (
                <select
                  value={selectedStore}
                  onChange={(e) => setSelectedStore(e.target.value)}
                  className="block w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-red-500 focus:ring-red-500"
                  required
                >
                  <option value="" disabled>Select a store…</option>
                  {stores.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.name}{s.location ? ` — ${s.location}` : ''}
                      {typeof s.current_cash === 'number'
                        ? ` (cash: ${formatDZD(s.current_cash)})`
                        : ''}
                    </option>
                  ))}
                </select>
              )}
            </div>
          )}

          {/* Admin-only: expense date */}
          {mode === 'admin' && (
            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-gray-500 mb-1">
                <Calendar size={12} className="inline mr-1 -mt-0.5" />
                Expense date
              </label>
              <input
                type="date"
                value={expenseDate}
                max={todayStr()}
                onChange={(e) => setExpenseDate(e.target.value)}
                className="block w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-red-500 focus:ring-red-500"
                required
              />
              <p className="mt-1 text-xs text-gray-500">
                Cannot be in the future. Defaults to today.
              </p>
            </div>
          )}

          {/* Amount */}
          <div>
            <label className="block text-xs font-semibold uppercase tracking-wider text-gray-500 mb-1">
              Amount (DZD)
            </label>
            <input
              type="number"
              inputMode="decimal"
              step="0.01"
              min={AMOUNT_MIN}
              max={AMOUNT_MAX}
              value={amount}
              onChange={(e) => {
                setAmount(e.target.value);
                setInsufficientBalance(null);
              }}
              placeholder="0.00"
              className="block w-full rounded-md border border-gray-300 px-3 py-2 text-base font-mono focus:border-red-500 focus:ring-red-500"
              required
            />
          </div>

          {/* Category */}
          <div>
            <label className="block text-xs font-semibold uppercase tracking-wider text-gray-500 mb-1">
              <Tag size={12} className="inline mr-1 -mt-0.5" />
              Category
            </label>
            <select
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              className="block w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-red-500 focus:ring-red-500"
              required
            >
              {CATEGORY_OPTIONS.map((c) => (
                <option key={c.value} value={c.value}>{c.label}</option>
              ))}
            </select>
          </div>

          {/* Description */}
          <div>
            <label className="block text-xs font-semibold uppercase tracking-wider text-gray-500 mb-1">
              Description
            </label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={3}
              maxLength={DESC_MAX}
              placeholder="What was this expense for?"
              className="block w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-red-500 focus:ring-red-500"
              required
            />
            <div className="mt-1 flex justify-between text-xs text-gray-500">
              <span>{DESC_MIN}–{DESC_MAX} characters.</span>
              <span>{description.trim().length}/{DESC_MAX}</span>
            </div>
          </div>

          {/* Cashier hint */}
          {mode === 'cashier' && (
            <div className="rounded-md bg-blue-50 border border-blue-200 p-3 text-xs text-blue-800">
              Store and date are filled in automatically from your open session.
              {sessionId ? <> Session #{sessionId}.</> : null}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex justify-between gap-3 border-t border-gray-100 p-4 bg-gray-50">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={submitting || !!validationError}
            className="flex items-center gap-2 px-6 py-2 text-sm font-semibold text-white bg-red-600 rounded-md hover:bg-red-700 disabled:opacity-50"
          >
            <CheckCircle2 size={16} />
            {submitting ? 'Recording…' : 'Record expense'}
          </button>
        </div>
      </form>
    </div>
  );
}
