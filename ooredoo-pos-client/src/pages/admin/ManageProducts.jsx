import { useState, useEffect, useMemo } from 'react';
import api from '../../api/axios';
import { Package, Plus, Trash2, Pencil, X, Filter, RefreshCw, RotateCcw, Trash } from 'lucide-react';

const emptyForm = {
  name: '',
  price: '',
  real_price: '',
  category_id: '',
  commission_amount: '0',
  sort_order: '0',
};

export default function ManageProducts() {
  const [products, setProducts]       = useState([]);
  const [categories, setCategories]   = useState([]);
  const [isLoading, setIsLoading]     = useState(true);
  const [error, setError]             = useState('');
  const [filterCategory, setFilter]   = useState('all');
  const [showInactive, setShowInactive] = useState(false);

  // Modal state — null | 'create' | 'edit'
  const [modal, setModal]             = useState(null);
  const [editingId, setEditingId]     = useState(null);
  const [formData, setFormData]       = useState(emptyForm);
  const [isSubmitting, setSubmitting] = useState(false);

  useEffect(() => {
    fetchAll();
  }, []);

  const fetchAll = async () => {
    try {
      setIsLoading(true);
      const [pRes, cRes] = await Promise.all([
        api.get('/products'),
        api.get('/products/categories'),
      ]);
      setProducts(pRes.data.data);
      setCategories(cRes.data.data);
      setError('');
    } catch (err) {
      console.error('Failed to load products', err);
      setError('Failed to load products.');
    } finally {
      setIsLoading(false);
    }
  };

  const formatDZD = (amount) =>
    new Intl.NumberFormat('fr-DZ', { style: 'currency', currency: 'DZD' }).format(
      amount || 0
    );

  const filteredProducts = useMemo(() => {
    let list = products;
    if (!showInactive) list = list.filter((p) => p.is_active);
    if (filterCategory !== 'all') list = list.filter((p) => p.category_id === Number(filterCategory));
    return list;
  }, [products, filterCategory, showInactive]);

  const inactiveCount = products.filter((p) => !p.is_active).length;

  const handleInput = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
  };

  const openCreate = () => {
    setFormData({
      ...emptyForm,
      category_id: categories[0]?.id?.toString() || '',
    });
    setEditingId(null);
    setModal('create');
  };

  const openEdit = (product) => {
    setFormData({
      name: product.name,
      price: String(product.price),
      real_price: String(product.real_price ?? ''),
      category_id: String(product.category_id),
      commission_amount: String(product.commission_amount),
      sort_order: String(product.sort_order),
    });
    setEditingId(product.id);
    setModal('edit');
  };

  const closeModal = () => {
    setModal(null);
    setEditingId(null);
    setFormData(emptyForm);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      const payload = {
        name: formData.name.trim(),
        price: Number(formData.price),
        real_price: Number(formData.real_price),
        category_id: Number(formData.category_id),
        commission_amount: Number(formData.commission_amount) || 0,
        sort_order: Number(formData.sort_order) || 0,
      };

      if (modal === 'create') {
        await api.post('/products', payload);
      } else if (modal === 'edit') {
        await api.patch(`/products/${editingId}`, payload);
      }

      closeModal();
      fetchAll();
    } catch (err) {
      console.error('Save failed', err);
      alert(err.response?.data?.message || 'Failed to save product.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = async (product) => {
    if (!window.confirm(`Deactivate "${product.name}"? This hides it from cashiers but preserves history.`)) {
      return;
    }
    try {
      await api.delete(`/products/${product.id}`);
      fetchAll();
    } catch (err) {
      alert(err.response?.data?.message || 'Failed to deactivate product.');
    }
  };

  const handleRestore = async (product) => {
    try {
      await api.post(`/products/${product.id}/restore`);
      fetchAll();
    } catch (err) {
      alert(err.response?.data?.message || `Failed to restore "${product.name}"`);
    }
  };

  const handlePermanentDelete = async (product) => {
    if (!window.confirm(
      `PERMANENTLY DELETE "${product.name}"?\n\nThis cannot be undone. Historical sales rows will keep their snapshot data, but the product itself will be removed forever.`
    )) return;
    try {
      await api.delete(`/products/${product.id}/permanent`);
      fetchAll();
    } catch (err) {
      alert(err.response?.data?.message || `Failed to delete "${product.name}"`);
    }
  };

  return (
    <div className="space-y-6">
      {/* ─── Header ─────────────────────────────────────────────────── */}
      <div className="flex items-center justify-between border-b border-gray-200 pb-4">
        <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
          <Package className="text-red-600" /> Manage Products
        </h1>
        <button
          onClick={openCreate}
          className="flex items-center gap-2 rounded-md bg-red-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-red-700"
        >
          <Plus size={16} /> Add Product
        </button>
      </div>

      {error && (
        <div className="rounded-md border border-red-200 bg-red-50 p-4 text-red-600">
          {error}
        </div>
      )}

      {/* Show-inactive toggle */}
      <label className="inline-flex items-center gap-2 text-sm text-gray-700 select-none cursor-pointer">
        <input
          type="checkbox"
          checked={showInactive}
          onChange={(e) => setShowInactive(e.target.checked)}
          className="rounded border-gray-300 text-red-600 focus:ring-red-500"
        />
        Show inactive products
        {inactiveCount > 0 && (
          <span className="text-xs text-gray-500">({inactiveCount} hidden)</span>
        )}
      </label>

      {/* ─── Category Filter ────────────────────────────────────────── */}
      <div className="flex flex-wrap items-center gap-2">
        <span className="flex items-center gap-1 text-sm font-medium text-gray-600">
          <Filter size={16} /> Filter:
        </span>
        <button
          onClick={() => setFilter('all')}
          className={`rounded-full px-3 py-1 text-xs font-semibold transition-colors ${
            filterCategory === 'all'
              ? 'bg-red-600 text-white'
              : 'bg-white text-gray-700 ring-1 ring-gray-300 hover:bg-gray-50'
          }`}
        >
          All ({(showInactive ? products : products.filter((p) => p.is_active)).length})
        </button>
        {categories.map((c) => {
          const count = (showInactive ? products : products.filter((p) => p.is_active))
            .filter((p) => p.category_id === c.id).length;
          return (
            <button
              key={c.id}
              onClick={() => setFilter(String(c.id))}
              className={`rounded-full px-3 py-1 text-xs font-semibold transition-colors ${
                filterCategory === String(c.id)
                  ? 'bg-red-600 text-white'
                  : 'bg-white text-gray-700 ring-1 ring-gray-300 hover:bg-gray-50'
              }`}
            >
              {c.name} ({count})
            </button>
          );
        })}
      </div>

      {/* ─── Products Table ─────────────────────────────────────────── */}
      <div className="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-gray-200 overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Product</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Category</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Price</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Commission</th>
              <th className="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200 bg-white">
            {isLoading ? (
              <tr>
                <td colSpan="6" className="px-6 py-8 text-center">
                  <RefreshCw className="inline animate-spin text-red-600" />
                </td>
              </tr>
            ) : filteredProducts.length === 0 ? (
              <tr>
                <td colSpan="6" className="px-6 py-4 text-center text-sm text-gray-500">
                  No products in this category. Add one with the button above.
                </td>
              </tr>
            ) : (
              filteredProducts.map((p) => (
                <tr key={p.id} className={!p.is_active ? 'bg-gray-50' : ''}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{p.name}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-600">{p.category_name}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-semibold text-gray-900">
                    {formatDZD(p.price)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium text-green-600">
                    {formatDZD(p.commission_amount)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-center">
                    {p.is_active ? (
                      <span className="inline-flex rounded-full bg-green-100 px-2 text-xs font-semibold leading-5 text-green-800">
                        Active
                      </span>
                    ) : (
                      <span className="inline-flex rounded-full bg-gray-200 px-2 text-xs font-semibold leading-5 text-gray-700">
                        Inactive
                      </span>
                    )}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium space-x-3">
                    {p.is_active && (
                      <>
                        <button
                          onClick={() => openEdit(p)}
                          className="text-blue-600 hover:text-blue-900 transition-colors"
                          title="Edit"
                        >
                          <Pencil size={18} />
                        </button>
                        <button
                          onClick={() => handleDelete(p)}
                          className="text-red-600 hover:text-red-900 transition-colors"
                          title="Deactivate"
                        >
                          <Trash2 size={18} />
                        </button>
                      </>
                    )}
                    {!p.is_active && (
                      <>
                        <button
                          onClick={() => handleRestore(p)}
                          className="text-green-600 hover:text-green-900 transition-colors"
                          title="Restore"
                        >
                          <RotateCcw size={18} />
                        </button>
                        <button
                          onClick={() => handlePermanentDelete(p)}
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

      {/* ─── Modal ──────────────────────────────────────────────────── */}
      {modal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="bg-white rounded-xl shadow-xl w-full max-w-lg overflow-hidden">
            <div className="flex items-center justify-between border-b border-gray-100 bg-gray-50 p-4">
              <h3 className="text-lg font-bold text-gray-900">
                {modal === 'create' ? 'Add New Product' : 'Edit Product'}
              </h3>
              <button onClick={closeModal} className="text-gray-400 hover:text-gray-600">
                <X size={20} />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4 p-6">
              <div>
                <label className="block text-sm font-medium text-gray-700">Name</label>
                <input
                  required
                  name="name"
                  value={formData.name}
                  onChange={handleInput}
                  maxLength={200}
                  className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500 sm:text-sm"
                  placeholder="e.g. iPhone 14 Pro 256GB"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Category</label>
                <select
                  required
                  name="category_id"
                  value={formData.category_id}
                  onChange={handleInput}
                  className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500 sm:text-sm"
                >
                  <option value="">Select a category...</option>
                  {categories.map((c) => (
                    <option key={c.id} value={c.id}>{c.name}</option>
                  ))}
                </select>
              </div>

              <div className="grid grid-cols-3 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700">Buying Price (DZD)</label>
                  <input
                    required
                    type="number"
                    min="0"
                    step="0.01"
                    name="real_price"
                    value={formData.real_price}
                    onChange={handleInput}
                    className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500 sm:text-sm"
                  />
                  <p className="mt-1 text-xs text-gray-500">Cost (used for profit).</p>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700">Selling Price (DZD)</label>
                  <input
                    required
                    type="number"
                    min="0"
                    step="0.01"
                    name="price"
                    value={formData.price}
                    onChange={handleInput}
                    className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500 sm:text-sm"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700">Commission (DZD)</label>
                  <input
                    type="number"
                    min="0"
                    step="0.01"
                    name="commission_amount"
                    value={formData.commission_amount}
                    onChange={handleInput}
                    className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500 sm:text-sm"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Sort Order</label>
                <input
                  type="number"
                  min="0"
                  name="sort_order"
                  value={formData.sort_order}
                  onChange={handleInput}
                  className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500 sm:text-sm"
                />
                <p className="mt-1 text-xs text-gray-500">Lower numbers appear first in the cashier UI.</p>
              </div>

              <div className="flex justify-end gap-3 border-t border-gray-100 pt-4">
                <button
                  type="button"
                  onClick={closeModal}
                  className="rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="rounded-md bg-red-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-red-700 disabled:opacity-50"
                >
                  {isSubmitting ? 'Saving...' : modal === 'create' ? 'Create' : 'Save Changes'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
