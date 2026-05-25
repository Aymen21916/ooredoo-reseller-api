import { useState } from 'react';
import api from '../api/axios';
import { X, ChevronLeft, Zap, CheckCircle2 } from 'lucide-react';
import CustomerPicker from './CustomerPicker';

const formatDZD = (n) =>
  new Intl.NumberFormat('fr-DZ', { style: 'currency', currency: 'DZD', maximumFractionDigits: 0 })
    .format(n || 0);

const STEPS = ['amount', 'customer', 'review'];

export default function StormSaleModal({ sessionId, onClose, onComplete }) {
  const [step, setStep] = useState('amount');
  const [amount, setAmount] = useState('');
  const [note, setNote]     = useState('');
  const [customer, setCustomer] = useState(null);
  const [error, setError]   = useState('');
  const [submitting, setSubmitting] = useState(false);

  const handleAmount = (e) => {
    e.preventDefault();
    if (!amount || Number(amount) <= 0) return;
    setError('');
    setStep('customer');
  };

  const handleConfirm = async () => {
    setSubmitting(true);
    setError('');
    try {
      await api.post('/sales/storm', {
        session_id:  sessionId,
        amount:      Number(amount),
        note:        note || null,
        customer_id: customer.id,
      });
      onComplete?.();
    } catch (err) {
      setError(err.response?.data?.message || 'Storm entry failed.');
    } finally {
      setSubmitting(false);
    }
  };

  const goBack = () => {
    setError('');
    if (step === 'customer') { setStep('amount'); setCustomer(null); }
    else if (step === 'review') setStep('customer');
  };

  const stepNumber = STEPS.indexOf(step) + 1;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-xl max-h-[92vh] flex flex-col">
        <div className="flex items-center justify-between p-4 border-b border-gray-100 bg-gray-50">
          <div className="flex items-center gap-2">
            {step !== 'amount' && (
              <button onClick={goBack} className="p-1 rounded-full hover:bg-gray-200 text-gray-500" aria-label="Back">
                <ChevronLeft size={18} />
              </button>
            )}
            <h3 className="font-bold text-lg text-gray-900 flex items-center gap-2">
              <Zap size={20} className="text-orange-600" /> Storm / Bundle
            </h3>
            <span className="ml-2 text-xs text-gray-500">Step {stepNumber} of {STEPS.length}</span>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600"><X size={20} /></button>
        </div>

        {error && (
          <div className="mx-4 mt-3 rounded-md bg-red-50 border border-red-200 p-3 text-sm text-red-700">{error}</div>
        )}

        <div className="p-6 overflow-y-auto flex-1">
          {step === 'amount' ? (
            <form onSubmit={handleAmount} className="space-y-4">
              <h4 className="font-semibold text-gray-900">Storm/Bundle details</h4>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Amount (DZD)</label>
                <input
                  required type="number" min="1" step="0.01"
                  value={amount} onChange={(e) => setAmount(e.target.value)}
                  className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-red-500 focus:ring-red-500"
                  placeholder="e.g. 150"
                  autoFocus
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Phone topped up / note (optional)</label>
                <input
                  type="text" value={note} onChange={(e) => setNote(e.target.value)}
                  maxLength={500}
                  className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-red-500 focus:ring-red-500"
                  placeholder="e.g. 0555..."
                />
              </div>
              <div className="flex justify-end pt-2">
                <button
                  type="submit"
                  disabled={!amount || Number(amount) <= 0}
                  className="px-4 py-2 text-sm font-semibold text-white bg-red-600 rounded-md hover:bg-red-700 disabled:opacity-50"
                >
                  Continue
                </button>
              </div>
            </form>
          ) : step === 'customer' ? (
            <>
              <h4 className="font-semibold text-gray-900 mb-3">Find or register the customer</h4>
              <CustomerPicker
                onConfirm={(c) => { setCustomer(c); setStep('review'); }}
                onError={setError}
              />
            </>
          ) : step === 'review' ? (
            <>
              <h4 className="font-semibold text-gray-900 mb-3">Review and confirm</h4>
              <div className="space-y-3">
                <div className="rounded-lg border border-gray-200 p-4">
                  <div className="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-2">Storm / Bundle</div>
                  <div className="text-2xl font-extrabold text-gray-900">{formatDZD(amount)}</div>
                  {note && <div className="text-sm text-gray-600 mt-1">{note}</div>}
                </div>
                <div className="rounded-lg border border-gray-200 p-4">
                  <div className="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-2">Customer</div>
                  <div className="font-bold text-gray-900">{customer.first_name} {customer.last_name}</div>
                  <div className="text-sm text-gray-600">{customer.phone_number} · {customer.profession}</div>
                </div>
              </div>
              <div className="mt-6 flex justify-between gap-3 border-t border-gray-100 pt-4">
                <button onClick={onClose} className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50">Cancel</button>
                <button
                  onClick={handleConfirm}
                  disabled={submitting}
                  className="flex items-center gap-2 px-6 py-2 text-sm font-semibold text-white bg-green-600 rounded-md hover:bg-green-700 disabled:opacity-50"
                >
                  <CheckCircle2 size={16} /> {submitting ? 'Recording…' : 'Confirm'}
                </button>
              </div>
            </>
          ) : null}
        </div>
      </div>
    </div>
  );
}
