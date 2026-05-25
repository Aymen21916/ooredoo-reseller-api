import { useState } from 'react';
import api from '../api/axios';
import {
  X, ChevronLeft, AlertTriangle, CheckCircle2, User, Phone, Briefcase, FileText,
} from 'lucide-react';
import CustomerPicker from './CustomerPicker';

const formatDZD = (n) =>
  new Intl.NumberFormat('fr-DZ', { style: 'currency', currency: 'DZD', maximumFractionDigits: 2 })
    .format(n || 0);

const STEPS = ['customer', 'amount', 'review'];

// Requirement 1.5: amount is a strictly positive decimal in [0.01, 9999999999.99]
// with at most two decimal places; description is 0..1000 chars after trim.
const AMOUNT_MIN = 0.01;
const AMOUNT_MAX = 9999999999.99;
const DESCRIPTION_MAX = 1000;

// Two decimals or fewer, optional, with a single optional decimal point.
const AMOUNT_PATTERN = /^\d+(\.\d{1,2})?$/;

// Map server-side error codes (Requirement 1.x) to user-facing strings.
const ERROR_MESSAGES = {
  CUSTOMER_REQUIRED:  'A customer must be selected before recording a debt.',
  NO_OPEN_SESSION:    'You have no open session. Open the register to record a debt.',
  VALIDATION_ERROR:   'Some fields are invalid. Please review the amount and description.',
  CUSTOMER_NOT_FOUND: 'The selected customer no longer exists. Pick another customer.',
};

const mapApiError = (err) => {
  if (!err) return 'Failed to record debt.';
  const data = err.response?.data;
  if (data?.code && ERROR_MESSAGES[data.code]) return ERROR_MESSAGES[data.code];
  return data?.message || 'Failed to record debt.';
};

/**
 * Three-step modal for recording a client debt, mirroring SimSaleModal.
 *
 * Flow: customer (CustomerPicker) → amount + description → review/confirm.
 * On confirm, POSTs { session_id, customer_id, amount, description } to
 * /api/sales/debt and calls onComplete(persisted) on success.
 */
export default function DebtModal({ sessionId, onClose, onComplete }) {
  const [step, setStep] = useState('customer');
  const [error, setError] = useState('');

  const [customer, setCustomer] = useState(null);
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [fieldErrors, setFieldErrors] = useState({});

  const [submitting, setSubmitting] = useState(false);

  const goBack = () => {
    setError('');
    setFieldErrors({});
    if (step === 'amount') {
      setStep('customer');
      setCustomer(null);
    } else if (step === 'review') {
      setStep('amount');
    }
  };

  // ── Step 2 client-side validation (Requirement 1.5) ──────────────────────
  const validateAmountAndDescription = () => {
    const errs = {};
    const trimmedAmount = String(amount).trim();
    if (!trimmedAmount) {
      errs.amount = 'Amount is required.';
    } else if (!AMOUNT_PATTERN.test(trimmedAmount)) {
      errs.amount = 'Amount must be a number with at most two decimal places.';
    } else {
      const num = Number(trimmedAmount);
      if (!Number.isFinite(num)) {
        errs.amount = 'Amount must be a valid number.';
      } else if (num < AMOUNT_MIN) {
        errs.amount = `Amount must be at least ${AMOUNT_MIN.toFixed(2)} DZD.`;
      } else if (num > AMOUNT_MAX) {
        errs.amount = `Amount must not exceed ${AMOUNT_MAX.toFixed(2)} DZD.`;
      }
    }

    const trimmedDescription = description.trim();
    if (trimmedDescription.length > DESCRIPTION_MAX) {
      errs.description = `Description must be at most ${DESCRIPTION_MAX} characters.`;
    }

    setFieldErrors(errs);
    return Object.keys(errs).length === 0;
  };

  const handleAmountSubmit = (e) => {
    e.preventDefault();
    if (!validateAmountAndDescription()) return;
    setError('');
    setStep('review');
  };

  const handleConfirm = async () => {
    setSubmitting(true);
    setError('');
    try {
      const trimmedDescription = description.trim();
      const payload = {
        session_id:  sessionId,
        customer_id: customer.id,
        amount:      Number(amount),
        description: trimmedDescription.length === 0 ? null : trimmedDescription,
      };
      const r = await api.post('/sales/debt', payload);
      onComplete?.(r.data.data);
    } catch (err) {
      setError(mapApiError(err));
    } finally {
      setSubmitting(false);
    }
  };

  const stepNumber = STEPS.indexOf(step) + 1;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-2xl max-h-[92vh] flex flex-col">
        <div className="flex items-center justify-between p-4 border-b border-gray-100 bg-gray-50">
          <div className="flex items-center gap-2">
            {step !== 'customer' && (
              <button onClick={goBack} className="p-1 rounded-full hover:bg-gray-200 text-gray-500" aria-label="Back">
                <ChevronLeft size={18} />
              </button>
            )}
            <h3 className="font-bold text-lg text-gray-900 flex items-center gap-2">
              <AlertTriangle size={20} className="text-red-600" /> Record Client Debt
            </h3>
            <span className="ml-2 text-xs text-gray-500">Step {stepNumber} of {STEPS.length}</span>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600" aria-label="Close">
            <X size={20} />
          </button>
        </div>

        {error && (
          <div className="mx-4 mt-3 rounded-md bg-red-50 border border-red-200 p-3 text-sm text-red-700">
            {error}
          </div>
        )}

        <div className="p-6 overflow-y-auto flex-1">
          {step === 'customer' ? (
            <>
              <h4 className="font-semibold text-gray-900 mb-1">Find or register the customer</h4>
              <p className="text-xs text-gray-500 mb-3">
                Every debt must be linked to a customer so the admin can follow up later.
              </p>
              <CustomerPicker
                onConfirm={(c) => { setCustomer(c); setError(''); setStep('amount'); }}
                onError={setError}
              />
            </>
          ) : step === 'amount' ? (
            <AmountStep
              customer={customer}
              amount={amount}
              description={description}
              fieldErrors={fieldErrors}
              onAmountChange={setAmount}
              onDescriptionChange={setDescription}
              onSubmit={handleAmountSubmit}
              onCancel={onClose}
            />
          ) : step === 'review' ? (
            <ReviewStep
              customer={customer}
              amount={Number(amount)}
              description={description.trim()}
              submitting={submitting}
              onConfirm={handleConfirm}
              onCancel={onClose}
            />
          ) : null}
        </div>
      </div>
    </div>
  );
}

function AmountStep({
  customer, amount, description, fieldErrors,
  onAmountChange, onDescriptionChange, onSubmit, onCancel,
}) {
  return (
    <>
      <h4 className="font-semibold text-gray-900 mb-1">Debt details</h4>
      <p className="text-xs text-gray-500 mb-4">
        Recording a debt for{' '}
        <span className="font-semibold text-gray-700">
          {customer.first_name} {customer.last_name}
        </span>{' '}
        ({customer.phone_number}).
      </p>

      <form onSubmit={onSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Debt amount (DZD)
          </label>
          <input
            type="text"
            inputMode="decimal"
            value={amount}
            onChange={(e) => onAmountChange(e.target.value)}
            placeholder="e.g. 1500.00"
            autoFocus
            className={`w-full rounded-md border px-3 py-2 text-sm focus:ring-red-500 focus:border-red-500 ${
              fieldErrors.amount ? 'border-red-400' : 'border-gray-300'
            }`}
          />
          {fieldErrors.amount && (
            <p className="mt-1 text-xs text-red-600">{fieldErrors.amount}</p>
          )}
          <p className="mt-1 text-xs text-gray-500">
            Between {AMOUNT_MIN.toFixed(2)} and {AMOUNT_MAX.toFixed(2)} DZD, two decimals max.
          </p>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1 flex items-center gap-1">
            <FileText size={14} /> Description (optional)
          </label>
          <textarea
            rows={3}
            value={description}
            onChange={(e) => onDescriptionChange(e.target.value)}
            placeholder="e.g. Took 2 SIMs without paying, will pay tomorrow"
            maxLength={DESCRIPTION_MAX + 50}
            className={`w-full rounded-md border px-3 py-2 text-sm focus:ring-red-500 focus:border-red-500 ${
              fieldErrors.description ? 'border-red-400' : 'border-gray-300'
            }`}
          />
          <div className="mt-1 flex items-center justify-between">
            {fieldErrors.description ? (
              <p className="text-xs text-red-600">{fieldErrors.description}</p>
            ) : (
              <span className="text-xs text-gray-500">Up to {DESCRIPTION_MAX} characters.</span>
            )}
            <span className="text-xs text-gray-400">
              {description.trim().length}/{DESCRIPTION_MAX}
            </span>
          </div>
        </div>

        <div className="mt-6 flex justify-between gap-3 border-t border-gray-100 pt-4">
          <button
            type="button"
            onClick={onCancel}
            className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            type="submit"
            className="flex items-center gap-2 px-6 py-2 text-sm font-semibold text-white bg-red-600 rounded-md hover:bg-red-700"
          >
            Continue to review
          </button>
        </div>
      </form>
    </>
  );
}

function ReviewStep({ customer, amount, description, submitting, onConfirm, onCancel }) {
  return (
    <>
      <h4 className="font-semibold text-gray-900 mb-3">Review and confirm</h4>
      <div className="space-y-3">
        <div className="rounded-lg border border-gray-200 p-4">
          <div className="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-2">
            Customer
          </div>
          <div className="grid grid-cols-2 gap-x-4 gap-y-1 text-sm">
            <Kv icon={<User size={14} />}      label="Name"       value={`${customer.first_name} ${customer.last_name}`} />
            <Kv icon={<Phone size={14} />}     label="Phone"      value={customer.phone_number} />
            <Kv icon={<Briefcase size={14} />} label="Profession" value={customer.profession} />
          </div>
        </div>

        <div className="rounded-lg border border-gray-200 p-4">
          <div className="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-2">
            Debt amount
          </div>
          <div className="text-3xl font-extrabold text-red-700">{formatDZD(amount)}</div>
        </div>

        <div className="rounded-lg border border-gray-200 p-4">
          <div className="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-2">
            Description
          </div>
          <div className="text-sm text-gray-800 whitespace-pre-wrap">
            {description.length > 0 ? description : <span className="text-gray-400">—</span>}
          </div>
        </div>
      </div>

      <div className="mt-6 flex justify-between gap-3 border-t border-gray-100 pt-4">
        <button
          onClick={onCancel}
          disabled={submitting}
          className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50"
        >
          Cancel
        </button>
        <button
          onClick={onConfirm}
          disabled={submitting}
          className="flex items-center gap-2 px-6 py-2 text-sm font-semibold text-white bg-green-600 rounded-md hover:bg-green-700 disabled:opacity-50"
        >
          <CheckCircle2 size={16} /> {submitting ? 'Recording debt...' : 'Confirm debt'}
        </button>
      </div>
    </>
  );
}

function Kv({ icon, label, value }) {
  return (
    <div>
      <div className="text-xs text-gray-500 flex items-center gap-1">{icon} {label}</div>
      <div className="font-medium text-gray-900">{value || '—'}</div>
    </div>
  );
}
