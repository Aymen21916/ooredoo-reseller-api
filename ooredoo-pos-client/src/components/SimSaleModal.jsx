import { useState, useEffect, useMemo } from 'react';
import api from '../api/axios';
import {
  X, ChevronLeft, Smartphone, Tag, CheckCircle2,
  RefreshCw, AlertTriangle,
} from 'lucide-react';
import CustomerPicker from './CustomerPicker';

const formatDZD = (n) =>
  new Intl.NumberFormat('fr-DZ', { style: 'currency', currency: 'DZD', maximumFractionDigits: 0 })
    .format(n || 0);

const STEPS = ['category', 'offer', 'customer', 'review'];

export default function SimSaleModal({ sessionId, stock, onClose, onComplete }) {
  const [step, setStep] = useState('category');
  const [categories, setCategories] = useState([]);
  const [offers, setOffers]         = useState([]);
  const [loading, setLoading]       = useState(true);
  const [error, setError]           = useState('');

  const [selectedCategory, setSelectedCategory] = useState(null);
  const [selectedOffer, setSelectedOffer]       = useState(null);
  const [customer, setCustomer]                 = useState(null);

  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    Promise.all([api.get('/offers/categories'), api.get('/offers')])
      .then(([catsRes, offersRes]) => {
        setCategories(catsRes.data.data);
        setOffers(offersRes.data.data.filter((o) => o.is_active));
      })
      .catch((err) => setError(err.response?.data?.message || 'Failed to load offers.'))
      .finally(() => setLoading(false));
  }, []);

  const visibleCategories = useMemo(() => {
    const counts = new Map();
    for (const o of offers) counts.set(o.category_id, (counts.get(o.category_id) || 0) + 1);
    return categories
      .filter((c) => counts.has(c.id))
      .map((c) => ({ ...c, offer_count: counts.get(c.id) }));
  }, [categories, offers]);

  const offersInCategory = useMemo(() => {
    if (!selectedCategory) return [];
    return offers
      .filter((o) => o.category_id === selectedCategory.id)
      .sort((a, b) => Number(a.selling_price) - Number(b.selling_price));
  }, [offers, selectedCategory]);

  const handleConfirmSale = async () => {
    setSubmitting(true);
    setError('');
    try {
      await api.post('/sales/sim', {
        session_id: sessionId,
        offer_id:    selectedOffer.id,
        customer_id: customer.id,
      });
      onComplete?.();
    } catch (err) {
      setError(err.response?.data?.message || 'Sale failed.');
    } finally {
      setSubmitting(false);
    }
  };

  const goBack = () => {
    setError('');
    if (step === 'offer')         setStep('category');
    else if (step === 'customer') { setStep('offer'); setCustomer(null); }
    else if (step === 'review')   setStep('customer');
  };

  const stepNumber = STEPS.indexOf(step) + 1;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-2xl max-h-[92vh] flex flex-col">
        <div className="flex items-center justify-between p-4 border-b border-gray-100 bg-gray-50">
          <div className="flex items-center gap-2">
            {step !== 'category' && (
              <button onClick={goBack} className="p-1 rounded-full hover:bg-gray-200 text-gray-500" aria-label="Back">
                <ChevronLeft size={18} />
              </button>
            )}
            <h3 className="font-bold text-lg text-gray-900 flex items-center gap-2">
              <Smartphone size={20} className="text-red-600" /> Sell SIM Card
            </h3>
            <span className="ml-2 text-xs text-gray-500">Step {stepNumber} of {STEPS.length}</span>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600"><X size={20} /></button>
        </div>

        {(!stock || stock.available_count === 0) && (
          <div className="px-4 py-2 bg-red-50 text-red-700 text-sm flex items-center gap-2 border-b border-red-100">
            <AlertTriangle size={16} /> No SIM cards in inventory. Ask the admin to assign more.
          </div>
        )}
        {stock?.next_serial && (
          <div className="px-4 py-2 bg-blue-50 text-blue-800 text-xs flex items-center justify-between border-b border-blue-100">
            <span>Next serial to be sold:</span>
            <span className="font-mono font-semibold">{stock.next_serial}</span>
          </div>
        )}

        {error && (
          <div className="mx-4 mt-3 rounded-md bg-red-50 border border-red-200 p-3 text-sm text-red-700">
            {error}
          </div>
        )}

        <div className="p-6 overflow-y-auto flex-1">
          {loading ? (
            <div className="flex justify-center py-12"><RefreshCw className="animate-spin text-red-600" /></div>
          ) : step === 'category' ? (
            <>
              <h4 className="font-semibold text-gray-900 mb-3">Choose a category</h4>
              {visibleCategories.length === 0 ? (
                <div className="text-center text-gray-500 py-8">No active offers available.</div>
              ) : (
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                  {visibleCategories.map((c) => (
                    <button
                      key={c.id}
                      onClick={() => { setSelectedCategory(c); setStep('offer'); }}
                      className="p-4 rounded-xl border-2 border-gray-200 hover:border-red-400 hover:bg-red-50 transition-colors text-left"
                    >
                      <div className="flex items-center justify-between mb-1">
                        <Tag size={18} className="text-red-600" />
                        <span className="text-xs text-gray-500">{c.offer_count} offer{c.offer_count > 1 ? 's' : ''}</span>
                      </div>
                      <div className="font-bold text-gray-900">{c.name}</div>
                    </button>
                  ))}
                </div>
              )}
            </>
          ) : step === 'offer' ? (
            <>
              <h4 className="font-semibold text-gray-900 mb-1">{selectedCategory?.name}</h4>
              <p className="text-xs text-gray-500 mb-4">Pick the offer for this sale.</p>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                {offersInCategory.map((o) => (
                  <button
                    key={o.id}
                    onClick={() => { setSelectedOffer(o); setStep('customer'); setCustomer(null); }}
                    className="p-4 rounded-xl border-2 border-gray-200 hover:border-red-400 hover:bg-red-50 transition-colors text-left"
                  >
                    <div className="text-2xl font-extrabold text-gray-900">{formatDZD(o.selling_price)}</div>
                    <div className="text-sm text-gray-700 mt-1 truncate" title={o.name}>{o.name}</div>
                  </button>
                ))}
              </div>
            </>
          ) : step === 'customer' ? (
            <>
              <h4 className="font-semibold text-gray-900 mb-3">Find or register the customer</h4>
              <CustomerPicker
                onConfirm={(c) => { setCustomer(c); setStep('review'); }}
                onError={setError}
              />
            </>
          ) : step === 'review' ? (
            <ReviewStep
              offer={selectedOffer}
              category={selectedCategory}
              customer={customer}
              stock={stock}
              submitting={submitting}
              onConfirm={handleConfirmSale}
              onCancel={onClose}
            />
          ) : null}
        </div>
      </div>
    </div>
  );
}

function ReviewStep({ offer, category, customer, stock, submitting, onConfirm, onCancel }) {
  return (
    <>
      <h4 className="font-semibold text-gray-900 mb-3">Review and confirm</h4>
      <div className="space-y-3">
        <div className="rounded-lg border border-gray-200 p-4">
          <div className="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-2">Offer</div>
          <div className="flex items-center justify-between">
            <div>
              <div className="font-bold text-gray-900">{offer.name}</div>
              <div className="text-xs text-gray-500">{category.name}</div>
            </div>
            <div className="text-2xl font-extrabold text-gray-900">{formatDZD(offer.selling_price)}</div>
          </div>
        </div>

        <div className="rounded-lg border border-gray-200 p-4">
          <div className="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-2">Customer</div>
          <div className="font-bold text-gray-900">{customer.first_name} {customer.last_name}</div>
          <div className="text-sm text-gray-600">{customer.phone_number} · {customer.profession}</div>
          <div className="text-xs text-gray-500 mt-1">{customer.address}</div>
        </div>

        <div className="rounded-lg border border-gray-200 p-4">
          <div className="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-2">SIM card to consume</div>
          <div className="font-mono text-lg text-gray-900">{stock?.next_serial || '—'}</div>
          <div className="text-xs text-gray-500 mt-1">FIFO — the lowest serial in your inventory.</div>
        </div>
      </div>
      <div className="mt-6 flex justify-between gap-3 border-t border-gray-100 pt-4">
        <button onClick={onCancel} className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50">Cancel</button>
        <button
          onClick={onConfirm}
          disabled={submitting || !stock?.next_serial}
          className="flex items-center gap-2 px-6 py-2 text-sm font-semibold text-white bg-green-600 rounded-md hover:bg-green-700 disabled:opacity-50"
        >
          <CheckCircle2 size={16} /> {submitting ? 'Recording sale...' : 'Confirm sale'}
        </button>
      </div>
    </>
  );
}
