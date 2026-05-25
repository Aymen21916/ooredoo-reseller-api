import { useState, useEffect } from 'react';
import api from '../api/axios';
import {
  X, RefreshCw, Plus, Wallet, Ban, CheckCircle2,
  ArrowDownCircle, ArrowUpCircle, ChevronLeft, ChevronRight,
} from 'lucide-react';

// ─── Constants ─────────────────────────────────────────────────────────────
// Default page size matches Requirement 2.8 / design API contract.
const PAGE_SIZE = 50;
// Amount range mirrors the server-side validator (Requirement 2.2 / 2.3).
const AMOUNT_MIN = 0.01;
const AMOUNT_MAX = 9999999999.99;
// Up to two decimals per design "Field Validation Rules".
const AMOUNT_RE = /^\d+(\.\d{1,2})?$/;
const NOTE_MAX = 500;

const formatDZD = (n) =>
  new Intl.NumberFormat('fr-DZ', { style: 'currency', currency: 'DZD' }).format(
    Number(n) || 0
  );

const formatTimestamp = (iso) => {
  if (!iso) return '—';
  try {
    return new Date(iso).toLocaleString([], {
      year: 'numeric', month: 'short', day: '2-digit',
      hour: '2-digit', minute: '2-digit',
    });
  } catch {
    return iso;
  }
};

/**
 * Cashier-facing advance ledger panel.
 *
 * Renders the cashier's outstanding advance balance, a paginated history list,
 * a "Record advance" inline modal, and a per-row void action constrained to
 * the cashier's currently open session per Requirement 2.11.
 *
 * Props:
 *   - sessionId   number | null  Cashier's currently open session id. Used to
 *                                gate the void button (cashiers can only void
 *                                advance rows whose session_id matches).
 *   - refreshKey  number         Bump from the parent to force a refetch when
 *                                external state changes (e.g. session opened).
 *   - onChange    () => void     Optional callback invoked after a successful
 *                                advance creation or void so the host page can
 *                                re-fetch session totals if it tracks them.
 */
export default function CashierAdvancePanel({
  sessionId = null,
  refreshKey = 0,
  onChange,
}) {
  const [data, setData] = useState({ outstanding_balance: 0, items: [] });
  const [page, setPage] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Internal refresh counter so post-mutation re-fetches don't depend on the
  // parent bumping `refreshKey`.
  const [internalRefresh, setInternalRefresh] = useState(0);

  // ─── Modal state ─────────────────────────────────────────────────────────
  const [showModal, setShowModal] = useState(false);
  const [formAmount, setFormAmount] = useState('');
  const [formNote, setFormNote] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState('');

  // ─── Fetch ───────────────────────────────────────────────────────────────
  // Refetch on mount, on every external `refreshKey`, on internal mutation,
  // and whenever the page changes. The fetch is run from inside an async
  // function declared in the effect so React's hooks lint rule doesn't flag
  // the synchronous setState pattern.
  useEffect(() => {
    let cancelled = false;
    async function load() {
      setLoading(true);
      setError('');
      try {
        const offset = page * PAGE_SIZE;
        const res = await api.get('/advances/me', {
          params: { limit: PAGE_SIZE, offset },
        });
        if (cancelled) return;
        const payload = res.data?.data || { outstanding_balance: 0, items: [] };
        setData({
          outstanding_balance: Number(payload.outstanding_balance) || 0,
          items: Array.isArray(payload.items) ? payload.items : [],
        });
        // We don't have a total count from the API; approximate "has more"
        // by whether the page is full.
        setHasMore((payload.items?.length || 0) === PAGE_SIZE);
      } catch (err) {
        if (!cancelled) {
          setError(err.response?.data?.message || 'Failed to load advance ledger.');
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [page, refreshKey, internalRefresh]);

  const refreshPanel = () => setInternalRefresh((n) => n + 1);

  // ─── Record advance ──────────────────────────────────────────────────────
  const openModal = () => {
    setFormAmount('');
    setFormNote('');
    setFormError('');
    setShowModal(true);
  };

  const closeModal = () => {
    if (submitting) return;
    setShowModal(false);
  };

  const handleSubmitAdvance = async (e) => {
    e.preventDefault();
    setFormError('');

    const raw = String(formAmount).trim();
    if (!raw || !AMOUNT_RE.test(raw)) {
      setFormError('Amount must be a positive number with up to 2 decimal places.');
      return;
    }
    const amount = Number(raw);
    if (!Number.isFinite(amount) || amount < AMOUNT_MIN || amount > AMOUNT_MAX) {
      setFormError(
        `Amount must be between ${formatDZD(AMOUNT_MIN)} and ${formatDZD(AMOUNT_MAX)}.`
      );
      return;
    }

    const noteTrim = formNote.trim();
    if (noteTrim.length > NOTE_MAX) {
      setFormError(`Note must be at most ${NOTE_MAX} characters.`);
      return;
    }

    try {
      setSubmitting(true);
      await api.post('/advances', {
        amount,
        ...(noteTrim ? { note: noteTrim } : {}),
      });
      setShowModal(false);
      // Reset to first page so the new row is visible at the top.
      if (page !== 0) setPage(0);
      else refreshPanel();
      onChange?.();
    } catch (err) {
      setFormError(err.response?.data?.message || 'Failed to record advance.');
    } finally {
      setSubmitting(false);
    }
  };

  // ─── Void row ────────────────────────────────────────────────────────────
  /**
   * Cashiers may only void *advance* rows tied to their currently open
   * session (Requirement 2.11). Repayment rows have session_id = null and
   * are not voidable by cashiers under any circumstance.
   */
  const canVoidRow = (row) =>
    !row.is_voided &&
    row.direction === 'advance' &&
    sessionId != null &&
    row.session_id === sessionId;

  const handleVoid = async (row) => {
    const reason = window.prompt(
      'Reason for voiding this advance? (1–500 characters)'
    );
    if (reason === null) return;
    const trimmed = reason.trim();
    if (trimmed.length < 1 || trimmed.length > 500) {
      alert('Reason must be 1–500 characters after trimming whitespace.');
      return;
    }
    try {
      await api.post(`/advances/${row.id}/void`, { reason: trimmed });
      refreshPanel();
      onChange?.();
    } catch (err) {
      alert(err.response?.data?.message || 'Failed to void advance.');
    }
  };

  // ─── Render ──────────────────────────────────────────────────────────────
  return (
    <div className="bg-white rounded-xl shadow-sm ring-1 ring-gray-200 overflow-hidden">
      {/* Header */}
      <div className="bg-gray-50 px-4 py-3 border-b border-gray-200 flex justify-between items-center">
        <h3 className="font-semibold text-gray-900 flex items-center gap-2">
          <Wallet size={18} className="text-purple-600" /> My Advances
        </h3>
        <button
          onClick={refreshPanel}
          className="text-gray-500 hover:text-purple-600"
          aria-label="Refresh advance ledger"
        >
          <RefreshCw size={16} />
        </button>
      </div>

      {/* Outstanding balance — rendered prominently per Requirement 2.8 */}
      <div className="px-4 py-5 border-b border-gray-100 bg-gradient-to-br from-purple-50 to-white">
        <p className="text-xs font-bold text-gray-500 uppercase tracking-wider mb-1">
          Outstanding Balance
        </p>
        <p className="text-3xl font-extrabold text-gray-900">
          {formatDZD(data.outstanding_balance)}
        </p>
        <button
          onClick={openModal}
          disabled={sessionId == null}
          title={sessionId == null ? 'Open a session to record an advance' : ''}
          className="mt-3 inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold text-white bg-purple-600 rounded-md hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <Plus size={16} /> Record advance
        </button>
      </div>

      {/* Error banner */}
      {error && (
        <div className="px-4 py-2 bg-red-50 border-b border-red-100 text-sm text-red-700">
          {error}
        </div>
      )}

      {/* History list */}
      <div className="p-2 max-h-80 overflow-y-auto">
        {loading ? (
          <div className="flex justify-center py-6">
            <RefreshCw className="animate-spin text-gray-400" />
          </div>
        ) : data.items.length === 0 ? (
          <p className="text-sm text-gray-500 text-center py-6">
            No advance history yet.
          </p>
        ) : (
          <div className="space-y-2">
            {data.items.map((row) => {
              const isAdvance = row.direction === 'advance';
              return (
                <div
                  key={row.id}
                  className={`flex items-center justify-between p-3 rounded-lg border ${
                    row.is_voided
                      ? 'bg-red-50/50 border-red-100 opacity-75'
                      : 'bg-white border-gray-100 hover:bg-gray-50'
                  }`}
                >
                  <div className="flex items-center gap-3 min-w-0">
                    <div
                      className={`p-2 rounded-full ${
                        row.is_voided
                          ? 'bg-red-100'
                          : isAdvance
                          ? 'bg-purple-100'
                          : 'bg-green-100'
                      }`}
                    >
                      {row.is_voided ? (
                        <Ban size={16} className="text-red-500" />
                      ) : isAdvance ? (
                        <ArrowDownCircle size={16} className="text-purple-600" />
                      ) : (
                        <ArrowUpCircle size={16} className="text-green-600" />
                      )}
                    </div>
                    <div className="min-w-0">
                      <p
                        className={`text-sm font-medium ${
                          row.is_voided
                            ? 'text-gray-500 line-through'
                            : 'text-gray-900'
                        }`}
                      >
                        {isAdvance ? 'Advance' : 'Repayment'}
                        {row.note ? (
                          <span className="text-gray-500 font-normal"> — {row.note}</span>
                        ) : null}
                      </p>
                      <p className="text-xs text-gray-400">
                        {formatTimestamp(row.created_at)}
                        {row.is_voided && (
                          <span className="ml-2 inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-semibold bg-red-100 text-red-700 uppercase tracking-wider">
                            Voided
                          </span>
                        )}
                      </p>
                    </div>
                  </div>

                  <div className="flex items-center gap-3 shrink-0">
                    <span
                      className={`font-semibold tabular-nums ${
                        row.is_voided
                          ? 'text-gray-400 line-through'
                          : isAdvance
                          ? 'text-purple-700'
                          : 'text-green-700'
                      }`}
                    >
                      {isAdvance ? '+' : '-'}
                      {formatDZD(row.amount)}
                    </span>

                    {canVoidRow(row) && (
                      <button
                        onClick={() => handleVoid(row)}
                        className="text-xs font-medium text-red-600 hover:text-red-800 bg-red-50 px-2 py-1 rounded"
                      >
                        Void
                      </button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Pagination */}
      {(page > 0 || hasMore) && (
        <div className="px-4 py-2 border-t border-gray-100 flex items-center justify-between text-xs text-gray-600">
          <button
            onClick={() => setPage((p) => Math.max(0, p - 1))}
            disabled={page === 0 || loading}
            className="inline-flex items-center gap-1 px-2 py-1 rounded border border-gray-200 disabled:opacity-40 hover:bg-gray-50"
          >
            <ChevronLeft size={14} /> Prev
          </button>
          <span>Page {page + 1}</span>
          <button
            onClick={() => setPage((p) => p + 1)}
            disabled={!hasMore || loading}
            className="inline-flex items-center gap-1 px-2 py-1 rounded border border-gray-200 disabled:opacity-40 hover:bg-gray-50"
          >
            Next <ChevronRight size={14} />
          </button>
        </div>
      )}

      {/* ─── Inline "Record advance" modal ──────────────────────────────── */}
      {showModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
          <div className="bg-white rounded-xl shadow-xl w-full max-w-md overflow-hidden">
            <div className="flex justify-between items-center p-4 border-b border-gray-100 bg-gray-50">
              <h3 className="font-bold text-lg text-gray-900 flex items-center gap-2">
                <Wallet size={20} className="text-purple-600" /> Record advance
              </h3>
              <button
                onClick={closeModal}
                className="text-gray-400 hover:text-gray-600"
                aria-label="Close"
              >
                <X size={20} />
              </button>
            </div>

            {formError && (
              <div className="mx-4 mt-3 rounded-md bg-red-50 border border-red-200 p-3 text-sm text-red-700">
                {formError}
              </div>
            )}

            <form onSubmit={handleSubmitAdvance} className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Amount (DZD) <span className="text-red-500">*</span>
                </label>
                <input
                  type="number"
                  step="0.01"
                  min={AMOUNT_MIN}
                  max={AMOUNT_MAX}
                  required
                  value={formAmount}
                  onChange={(e) => setFormAmount(e.target.value)}
                  className="w-full rounded-md border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
                  placeholder="0.00"
                  autoFocus
                />
                <p className="mt-1 text-xs text-gray-500">
                  Between {formatDZD(AMOUNT_MIN)} and {formatDZD(AMOUNT_MAX)}.
                </p>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Note <span className="text-gray-400 text-xs">(optional)</span>
                </label>
                <textarea
                  rows={3}
                  maxLength={NOTE_MAX}
                  value={formNote}
                  onChange={(e) => setFormNote(e.target.value)}
                  className="w-full rounded-md border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
                  placeholder="What is this advance for?"
                />
                <p className="mt-1 text-xs text-gray-500 text-right">
                  {formNote.length}/{NOTE_MAX}
                </p>
              </div>

              <div className="flex justify-end gap-3 pt-4 border-t border-gray-100">
                <button
                  type="button"
                  onClick={closeModal}
                  disabled={submitting}
                  className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold text-white bg-purple-600 rounded-md hover:bg-purple-700 disabled:opacity-50"
                >
                  <CheckCircle2 size={16} />
                  {submitting ? 'Recording…' : 'Confirm'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
