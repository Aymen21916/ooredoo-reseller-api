import { useState, useEffect, useMemo } from 'react';
import api from '../../api/axios';
import { Tags, Plus, Trash2, RotateCcw, Trash } from 'lucide-react';

export default function ManageOffers() {
  const [offers, setOffers] = useState([]);
  const [categories, setCategories] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [showInactive, setShowInactive] = useState(false);

  // Form State
  const [isAdding, setIsAdding] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    category_id: '',
    real_price: '',
    selling_price: '',
    commission_amount: '',
    points: '',
    low_stock_threshold: '5',
    sort_order: '0',
  });

  useEffect(() => {
    fetchAll();
  }, []);

  const fetchAll = async () => {
    try {
      setIsLoading(true);
      const [offersRes, catsRes] = await Promise.all([
        api.get('/offers'),
        api.get('/offers/categories'),
      ]);
      setOffers(offersRes.data.data);
      setCategories(catsRes.data.data);
      setError('');
    } catch (err) {
      console.error('Failed to fetch offers', err);
      setError('Failed to load offers.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const payload = {
        name: formData.name,
        category_id: Number(formData.category_id),
        real_price: Number(formData.real_price),
        selling_price: Number(formData.selling_price),
        commission_amount: Number(formData.commission_amount) || 0,
        points: Number(formData.points) || 0,
        low_stock_threshold: Number(formData.low_stock_threshold),
        sort_order: Number(formData.sort_order),
      };
      await api.post('/offers', payload);
      setFormData({
        name: '', category_id: '', real_price: '', selling_price: '',
        commission_amount: '', points: '', low_stock_threshold: '5', sort_order: '0',
      });
      setIsAdding(false);
      fetchAll();
    } catch (err) {
      alert(err.response?.data?.message || 'Failed to create offer');
    }
  };

  const handleDeactivate = async (id, name) => {
    if (!window.confirm(`Deactivate "${name}"? Cashiers will no longer see it.`)) return;
    try {
      await api.delete(`/offers/${id}`);
      fetchAll();
    } catch (err) {
      alert(err.response?.data?.message || 'Failed to deactivate offer');
    }
  };

  const handleRestore = async (id, name) => {
    try {
      await api.post(`/offers/${id}/restore`);
      fetchAll();
    } catch (err) {
      alert(err.response?.data?.message || `Failed to restore "${name}"`);
    }
  };

  const handlePermanentDelete = async (id, name) => {
    if (!window.confirm(
      `PERMANENTLY DELETE "${name}"?\n\nThis cannot be undone. If this offer has any historical sales, the deletion will fail and it must remain deactivated.`
    )) return;
    try {
      await api.delete(`/offers/${id}/permanent`);
      fetchAll();
    } catch (err) {
      alert(err.response?.data?.message || `Failed to delete "${name}"`);
    }
  };

  const formatDZD = (amount) =>
    new Intl.NumberFormat('fr-DZ', { style: 'currency', currency: 'DZD' }).format(amount || 0);

  const visibleOffers = useMemo(
    () => (showInactive ? offers : offers.filter((o) => o.is_active)),
    [offers, showInactive]
  );

  const inactiveCount = offers.filter((o) => !o.is_active).length;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-gray-200 pb-4">
        <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
          <Tags className="text-red-600" /> Manage SIM Offers
        </h1>
        <button
          onClick={() => setIsAdding(!isAdding)}
          className="flex items-center gap-2 rounded-md bg-red-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-red-700"
        >
          <Plus size={16} /> {isAdding ? 'Cancel' : 'Add Offer'}
        </button>
      </div>

      {error && <div className="p-4 bg-red-50 text-red-600 rounded-md border border-red-200">{error}</div>}

      {/* Show-inactive toggle */}
      <label className="inline-flex items-center gap-2 text-sm text-gray-700 select-none cursor-pointer">
        <input
          type="checkbox"
          checked={showInactive}
          onChange={(e) => setShowInactive(e.target.checked)}
          className="rounded border-gray-300 text-red-600 focus:ring-red-500"
        />
        Show inactive offers
        {inactiveCount > 0 && (
          <span className="text-xs text-gray-500">({inactiveCount} hidden)</span>
        )}
      </label>

      {/* Add Offer Form */}
      {isAdding && (
        <div className="rounded-xl bg-white p-6 shadow-sm ring-1 ring-gray-200 mb-6">
          <h2 className="text-lg font-semibold mb-4">Create New SIM Offer</h2>
          <form onSubmit={handleSubmit} className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="md:col-span-2">
              <label className="block text-sm font-medium text-gray-700">Offer Name</label>
              <input required name="name" value={formData.name} onChange={handleInputChange} className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500 sm:text-sm" placeholder="e.g. Ooredoo La Switch 1500" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">Category</label>
              <select required name="category_id" value={formData.category_id} onChange={handleInputChange} className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500 sm:text-sm">
                <option value="">-- Select category --</option>
                {categories.map((c) => (
                  <option key={c.id} value={c.id}>{c.name}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">Buying Price (DZD)</label>
              <input required type="number" min="0" step="0.01" name="real_price" value={formData.real_price} onChange={handleInputChange} className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500 sm:text-sm" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">Selling Price (DZD)</label>
              <input required type="number" min="0" step="0.01" name="selling_price" value={formData.selling_price} onChange={handleInputChange} className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500 sm:text-sm" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">Cashier Commission (DZD)</label>
              <input required type="number" min="0" step="0.01" name="commission_amount" value={formData.commission_amount} onChange={handleInputChange} className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500 sm:text-sm" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">Loyalty Points</label>
              <input type="number" min="0" name="points" value={formData.points} onChange={handleInputChange} className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500 sm:text-sm" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">Low Stock Alert Level</label>
              <input required type="number" min="0" name="low_stock_threshold" value={formData.low_stock_threshold} onChange={handleInputChange} className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500 sm:text-sm" />
            </div>
            <div className="md:col-span-3 flex justify-end mt-2">
              <button type="submit" className="rounded-md bg-green-600 px-6 py-2 text-sm font-semibold text-white shadow-sm hover:bg-green-700">
                Save Offer
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Offers Table */}
      <div className="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-gray-200 overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Offer Name</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Category</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Cost</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Selling</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Commission</th>
              <th className="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200 bg-white">
            {isLoading ? (
              <tr><td colSpan="7" className="px-6 py-4 text-center text-sm text-gray-500">Loading...</td></tr>
            ) : visibleOffers.length === 0 ? (
              <tr><td colSpan="7" className="px-6 py-4 text-center text-sm text-gray-500">
                {showInactive ? 'No offers found.' : 'No active offers. Toggle "Show inactive" to view deactivated offers.'}
              </td></tr>
            ) : (
              visibleOffers.map((o) => (
                <tr key={o.id} className={!o.is_active ? 'bg-gray-50' : ''}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{o.name}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-700">{o.category_name || '—'}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 text-right">{formatDZD(o.real_price)}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-semibold text-gray-900 text-right">{formatDZD(o.selling_price)}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-green-600 font-medium text-right">{formatDZD(o.commission_amount)}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-center">
                    {o.is_active ? (
                      <span className="inline-flex rounded-full bg-green-100 px-2 text-xs font-semibold leading-5 text-green-800">Active</span>
                    ) : (
                      <span className="inline-flex rounded-full bg-gray-200 px-2 text-xs font-semibold leading-5 text-gray-700">Inactive</span>
                    )}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium space-x-3">
                    {o.is_active && (
                      <button
                        onClick={() => handleDeactivate(o.id, o.name)}
                        className="text-red-600 hover:text-red-900 transition-colors"
                        title="Deactivate"
                      >
                        <Trash2 size={18} />
                      </button>
                    )}
                    {!o.is_active && (
                      <>
                        <button
                          onClick={() => handleRestore(o.id, o.name)}
                          className="text-green-600 hover:text-green-900 transition-colors"
                          title="Restore"
                        >
                          <RotateCcw size={18} />
                        </button>
                        <button
                          onClick={() => handlePermanentDelete(o.id, o.name)}
                          className="text-red-700 hover:text-red-900 transition-colors"
                          title="Delete permanently"
                        >
                          <Trash size={18} />
                        </button>
                      </>
                    )}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
