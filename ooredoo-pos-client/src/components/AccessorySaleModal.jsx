import { useState, useEffect, useMemo } from 'react';
import api from '../api/axios';
import { X, ChevronLeft, CreditCard, CheckCircle2, RefreshCw, Tag } from 'lucide-react';
import CustomerPicker from './CustomerPicker';

const formatDZD = (n) =>
  new Intl.NumberFormat('fr-DZ', { style: 'currency', currency: 'DZD', maximumFractionDigits: 0 })
    .format(n || 0);

const STEPS = ['category', 'product', 'customer', 'review'];

export default function AccessorySaleModal({ sessionId, onClose, onComplete }) {
  const [step, setStep] = useState('category');
  const [categories, setCategories] = useState([]);
  const [products, setProducts]     = useState([]);
  const [loading, setLoading]       = useState(true);
  const [error, setError]           = useState('');

  const [selectedCategory, setSelectedCategory] = useState(null);
  const [selectedProduct, setSelectedProduct]   = useState(null);
  const [customer, setCustomer]                 = useState(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    Promise.all([api.get('/products/categories'), api.get('/products')])
      .then(([catsRes, prodsRes]) => {
        setCategories(catsRes.data.data);
        setProducts(prodsRes.data.data.filter((p) => p.is_active));
      })
      .catch((err) => setError(err.response?.data?.message || 'Failed to load products.'))
      .finally(() => setLoading(false));
  }, []);

  const visibleCategories = useMemo(() => {
    const counts = new Map();
    for (const p of products) counts.set(p.category_id, (counts.get(p.category_id) || 0) + 1);
    return categories
      .filter((c) => counts.has(c.id))
      .map((c) => ({ ...c, product_count: counts.get(c.id) }));
  }, [categories, products]);

  const productsInCategory = useMemo(() => {
    if (!selectedCategory) return [];
    return products
      .filter((p) => p.category_id === selectedCategory.id)
      .sort((a, b) => Number(a.price) - Number(b.price));
  }, [products, selectedCategory]);

  const handleConfirmSale = async () => {
    setSubmitting(true);
    setError('');
    try {
      await api.post('/sales/accessory', {
        session_id: sessionId,
        product_id: selectedProduct.id,
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
    if (step === 'product')        setStep('category');
    else if (step === 'customer')  { setStep('product'); setCustomer(null); }
    else if (step === 'review')    setStep('customer');
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
              <CreditCard size={20} className="text-blue-600" /> Sell Accessory / Phone
            </h3>
            <span className="ml-2 text-xs text-gray-500">Step {stepNumber} of {STEPS.length}</span>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600"><X size={20} /></button>
        </div>

        {error && (
          <div className="mx-4 mt-3 rounded-md bg-red-50 border border-red-200 p-3 text-sm text-red-700">{error}</div>
        )}

        <div className="p-6 overflow-y-auto flex-1">
          {loading ? (
            <div className="flex justify-center py-12"><RefreshCw className="animate-spin text-red-600" /></div>
          ) : step === 'category' ? (
            <>
              <h4 className="font-semibold text-gray-900 mb-3">Choose a category</h4>
              {visibleCategories.length === 0 ? (
                <div className="text-center text-gray-500 py-8">No active products available.</div>
              ) : (
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                  {visibleCategories.map((c) => (
                    <button
                      key={c.id}
                      onClick={() => { setSelectedCategory(c); setStep('product'); }}
                      className="p-4 rounded-xl border-2 border-gray-200 hover:border-blue-400 hover:bg-blue-50 transition-colors text-left"
                    >
                      <div className="flex items-center justify-between mb-1">
                        <Tag size={18} className="text-blue-600" />
                        <span className="text-xs text-gray-500">{c.product_count}</span>
                      </div>
                      <div className="font-bold text-gray-900">{c.name}</div>
                    </button>
                  ))}
                </div>
              )}
            </>
          ) : step === 'product' ? (
            <>
              <h4 className="font-semibold text-gray-900 mb-1">{selectedCategory?.name}</h4>
              <p className="text-xs text-gray-500 mb-4">Pick the product for this sale.</p>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                {productsInCategory.map((p) => (
                  <button
                    key={p.id}
                    onClick={() => { setSelectedProduct(p); setStep('customer'); setCustomer(null); }}
                    className="p-4 rounded-xl border-2 border-gray-200 hover:border-blue-400 hover:bg-blue-50 transition-colors text-left"
                  >
                    <div className="font-bold text-gray-900 truncate" title={p.name}>{p.name}</div>
                    <div className="text-xl font-extrabold text-gray-900 mt-1">{formatDZD(p.price)}</div>
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
            <>
              <h4 className="font-semibold text-gray-900 mb-3">Review and confirm</h4>
              <div className="space-y-3">
                <div className="rounded-lg border border-gray-200 p-4">
                  <div className="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-2">Product</div>
                  <div className="flex items-center justify-between">
                    <div>
                      <div className="font-bold text-gray-900">{selectedProduct.name}</div>
                      <div className="text-xs text-gray-500">{selectedCategory.name}</div>
                    </div>
                    <div className="text-2xl font-extrabold text-gray-900">{formatDZD(selectedProduct.price)}</div>
                  </div>
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
                  onClick={handleConfirmSale}
                  disabled={submitting}
                  className="flex items-center gap-2 px-6 py-2 text-sm font-semibold text-white bg-green-600 rounded-md hover:bg-green-700 disabled:opacity-50"
                >
                  <CheckCircle2 size={16} /> {submitting ? 'Recording…' : 'Confirm sale'}
                </button>
              </div>
            </>
          ) : null}
        </div>
      </div>
    </div>
  );
}
