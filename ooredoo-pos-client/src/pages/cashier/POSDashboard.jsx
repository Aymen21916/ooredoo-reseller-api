import { useState, useEffect } from 'react';
import api from '../../api/axios';
import { useAuth } from '../../hooks/useAuth';
import {
  PlayCircle, StopCircle, Smartphone, Zap, CreditCard,
  AlertTriangle, Receipt, RefreshCw,
} from 'lucide-react';
import TransactionLedger from './TransactionLedger';
import SimSaleModal from '../../components/SimSaleModal';
import StormSaleModal from '../../components/StormSaleModal';
import AccessorySaleModal from '../../components/AccessorySaleModal';
import DebtModal from '../../components/DebtModal';
import RegisterExpenseModal from '../../components/RegisterExpenseModal';
import CashierAdvancePanel from '../../components/CashierAdvancePanel';

export default function POSDashboard() {
  const { user } = useAuth();
  const [refreshLedger, setRefreshLedger] = useState(0);

  // Core Data State
  const [session, setSession] = useState(null);
  const [totals, setTotals] = useState(null);
  const [stock, setStock] = useState(null);

  // UI State
  const [isLoading, setIsLoading] = useState(true);
  const [actionStatus, setActionStatus] = useState('');

  // Modal State — 'sim' | 'storm' | 'accessory' | 'debt' | 'expense' | null
  const [activeModal, setActiveModal] = useState(null);

  useEffect(() => {
    fetchCurrentSession();
  }, []);

  const fetchCurrentSession = async () => {
    try {
      setIsLoading(true);
      const response = await api.get('/sessions?status=open');
      const activeSession = response.data.data[0];

      if (activeSession) {
        setSession(activeSession);
        await fetchSessionDetails(activeSession.id);
      } else {
        setSession(null);
        setStock(null);
      }
    } catch (err) {
      console.error('Failed to fetch session', err);
    } finally {
      setIsLoading(false);
    }
  };

  const fetchSessionDetails = async (sessionId) => {
    try {
      const [totalsRes, stockRes] = await Promise.all([
        api.get(`/sessions/${sessionId}/totals`),
        api.get(`/sessions/${sessionId}/stock`)
      ]);
      setTotals(totalsRes.data.data);
      setStock(stockRes.data.data);
    } catch (err) {
      console.error('Failed to fetch details', err);
    }
  };

  const handleOpenSession = async () => {
    try {
      setActionStatus('Opening session...');
      const response = await api.post('/sessions', { cashier_id: user.id });
      setSession(response.data.data);
      await fetchSessionDetails(response.data.data.id);
    } catch (err) {
      alert(err.response?.data?.message || 'Failed to open session');
    } finally {
      setActionStatus('');
    }
  };

  const handleCloseSession = async () => {
    if (!window.confirm('Are you sure you want to end your shift?')) return;
    try {
      setActionStatus('Closing session...');
      await api.post(`/sessions/${session.id}/close`);
      setSession(null); setTotals(null); setStock(null);
    } catch (err) {
      alert(err.response?.data?.message || 'Failed to close session');
    } finally {
      setActionStatus('');
    }
  };

  // ─── MODAL HANDLERS ──────────────────────────────────────────────────────

  const openModal = (type) => setActiveModal(type);
  const closeModal = () => setActiveModal(null);

  const handleModalComplete = async () => {
    setActiveModal(null);
    if (session) await fetchSessionDetails(session.id);
    setRefreshLedger((p) => p + 1);
  };

  const formatDZD = (amount) => {
    return new Intl.NumberFormat('fr-DZ', { style: 'currency', currency: 'DZD' }).format(amount || 0);
  };

  if (isLoading) return <div className="p-6 flex justify-center"><RefreshCw className="animate-spin text-red-600" /></div>;

  if (!session) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] text-center space-y-6">
        <div className="bg-white p-10 rounded-2xl shadow-sm ring-1 ring-gray-200 max-w-md w-full">
          <div className="mx-auto w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mb-6">
            <PlayCircle className="text-red-600 w-8 h-8" />
          </div>
          <h2 className="text-2xl font-bold text-gray-900 mb-2">Ready to start your shift?</h2>
          <button
            onClick={handleOpenSession}
            disabled={actionStatus !== ''}
            className="w-full flex justify-center py-3 px-4 border border-transparent rounded-lg shadow-sm text-sm font-medium text-white bg-red-600 hover:bg-red-700 disabled:opacity-50"
          >
            {actionStatus || 'Open Register & Start Shift'}
          </button>
        </div>
      </div>
    );
  }

  // Requirements 1.6 and 3.3: cashier UI must disable debt / expense triggers
  // when there is no open session. The page already gates rendering on
  // `session`, but we keep the prop explicit for traceability and defence
  // in depth.
  const noOpenSession = !session;

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 relative">

      {/* ─── SIM SALE MODAL (multi-step) ─────────────────────────────── */}
      {activeModal === 'sim' && (
        <SimSaleModal
          sessionId={session.id}
          stock={stock}
          onClose={closeModal}
          onComplete={handleModalComplete}
        />
      )}

      {/* ─── STORM/BUNDLE MODAL ──────────────────────────────────────── */}
      {activeModal === 'storm' && (
        <StormSaleModal
          sessionId={session.id}
          onClose={closeModal}
          onComplete={handleModalComplete}
        />
      )}

      {/* ─── ACCESSORY/PHONE MODAL ───────────────────────────────────── */}
      {activeModal === 'accessory' && (
        <AccessorySaleModal
          sessionId={session.id}
          onClose={closeModal}
          onComplete={handleModalComplete}
        />
      )}

      {/* ─── DEBT MODAL (multi-step, customer-linked) ────────────────── */}
      {activeModal === 'debt' && (
        <DebtModal
          sessionId={session.id}
          onClose={closeModal}
          onComplete={handleModalComplete}
        />
      )}

      {/* ─── REGISTER EXPENSE MODAL (cashier mode) ───────────────────── */}
      {activeModal === 'expense' && (
        <RegisterExpenseModal
          mode="cashier"
          sessionId={session.id}
          onClose={closeModal}
          onComplete={handleModalComplete}
        />
      )}

      {/* ─── LEFT COLUMN: Actions Terminal ──────────────────────────────── */}
      <div className="lg:col-span-2 space-y-6">
        <div className="bg-white rounded-xl shadow-sm ring-1 ring-gray-200 p-6">
          <div className="flex justify-between items-center mb-6 border-b border-gray-100 pb-4">
            <h2 className="text-xl font-bold text-gray-900">Point of Sale</h2>
            <div className="flex items-center gap-2 text-sm">
              <span className="w-3 h-3 rounded-full bg-green-500 animate-pulse"></span>
              <span className="text-gray-600 font-medium">Session Active</span>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <button onClick={() => openModal('sim')} className="flex flex-col items-center justify-center p-8 bg-red-50 hover:bg-red-100 text-red-700 rounded-xl border border-red-200 transition-colors">
              <Smartphone size={32} className="mb-3" />
              <span className="font-bold text-lg">Sell SIM Card</span>
            </button>
            <button onClick={() => openModal('storm')} className="flex flex-col items-center justify-center p-8 bg-orange-50 hover:bg-orange-100 text-orange-700 rounded-xl border border-orange-200 transition-colors">
              <Zap size={32} className="mb-3" />
              <span className="font-bold text-lg">Enter Storm / Bundle</span>
            </button>
            <button onClick={() => openModal('accessory')} className="flex flex-col items-center justify-center p-8 bg-blue-50 hover:bg-blue-100 text-blue-700 rounded-xl border border-blue-200 transition-colors">
              <CreditCard size={32} className="mb-3" />
              <span className="font-bold text-lg">Sell Accessory / Phone</span>
            </button>
            <button
              onClick={() => openModal('debt')}
              disabled={noOpenSession}
              title={noOpenSession ? 'Open a session to record a debt' : ''}
              className="flex flex-col items-center justify-center p-8 bg-gray-50 hover:bg-gray-100 text-gray-700 rounded-xl border border-gray-200 transition-colors disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-gray-50"
            >
              <AlertTriangle size={32} className="mb-3" />
              <span className="font-bold text-lg">Record Client Debt</span>
            </button>
            <button
              onClick={() => openModal('expense')}
              disabled={noOpenSession}
              title={noOpenSession ? 'Open a session to record an expense' : ''}
              className="flex flex-col items-center justify-center p-8 bg-amber-50 hover:bg-amber-100 text-amber-700 rounded-xl border border-amber-200 transition-colors sm:col-span-2 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-amber-50"
            >
              <Receipt size={32} className="mb-3" />
              <span className="font-bold text-lg">Record Register Expense</span>
            </button>
          </div>
        </div>

        <div className="flex gap-4">
          <button onClick={() => fetchSessionDetails(session.id)} className="flex-1 flex items-center justify-center gap-2 py-3 bg-white border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 font-medium">
            <RefreshCw size={18} /> Refresh Totals
          </button>
          <button onClick={handleCloseSession} disabled={actionStatus !== ''} className="flex-1 flex items-center justify-center gap-2 py-3 bg-gray-900 text-white rounded-lg hover:bg-black font-medium disabled:opacity-50">
            <StopCircle size={18} /> {actionStatus || 'End Shift & Close Register'}
          </button>
        </div>
      </div>

      {/* ─── RIGHT COLUMN: Live Ledger & Stock ──────────────────────────── */}
      <div className="space-y-6">
        <div className="bg-white rounded-xl shadow-sm ring-1 ring-gray-200 p-6 border-t-4 border-t-green-500">
          <p className="text-sm font-bold text-gray-500 uppercase tracking-wider mb-1">Expected Register Cash</p>
          <p className="text-4xl font-extrabold text-gray-900">{formatDZD(totals?.expected_register_cash)}</p>
          <div className="mt-4 pt-4 border-t border-gray-100 space-y-2 text-sm">
            <div className="flex justify-between text-gray-600">
              <span>Opening Cash:</span>
              <span className="font-medium">{formatDZD(session.opening_cash)}</span>
            </div>
            <div className="flex justify-between text-gray-600">
              <span>Your Commission:</span>
              <span className="font-medium text-green-600">{formatDZD(totals?.total_cashier_benefit)}</span>
            </div>
            <div className="flex justify-between text-red-600 font-medium">
              <span>Total Debts:</span>
              <span>{formatDZD(totals?.debt_total)}</span>
            </div>
          </div>
        </div>

        {/* ─── Cashier advance ledger (Requirement 2.8) ───────────────── */}
        <CashierAdvancePanel
          sessionId={session.id}
          refreshKey={refreshLedger}
          onChange={() => fetchSessionDetails(session.id)}
        />

        <div>
            <TransactionLedger
                sessionId={session.id}
                refreshTrigger={refreshLedger}
                onVoidSuccess={() => {
                // Refresh totals and stock if a void happens
                fetchSessionDetails(session.id);
                setRefreshLedger(prev => prev + 1);
                }}
            />
        </div>

        <div className="bg-white rounded-xl shadow-sm ring-1 ring-gray-200 overflow-hidden">
          <div className="bg-gray-50 px-4 py-3 border-b border-gray-200">
            <h3 className="font-semibold text-gray-900">Your SIM Stock</h3>
          </div>
          <div className="p-4">
            {!stock || stock.available_count === 0 ? (
              <p className="text-sm text-gray-500 text-center py-4">
                Waiting for admin to assign SIM cards.
              </p>
            ) : (
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-sm text-gray-600">Available</span>
                  <span
                    className={`inline-flex items-center justify-center px-3 py-1 text-sm font-bold rounded-full ${
                      stock.is_low_stock ? 'bg-red-100 text-red-700' : 'bg-green-100 text-green-800'
                    }`}
                  >
                    {stock.available_count}
                  </span>
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-600">Sold</span>
                  <span className="font-medium text-gray-900">{stock.sold_count}</span>
                </div>
                {stock.next_serial && (
                  <div className="pt-3 border-t border-gray-100">
                    <div className="text-xs font-semibold text-gray-500 uppercase tracking-wider">Next serial</div>
                    <div className="mt-1 font-mono text-sm text-gray-900">{stock.next_serial}</div>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </div>

    </div>
  );
}
