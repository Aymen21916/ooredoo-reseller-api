import { useState, useEffect, useMemo } from 'react';
import api from '../../api/axios';
import {
  UsersRound, Plus, Pencil, Trash2, X, Search, RefreshCw,
  Phone, MapPin, Briefcase, User, Smartphone, Zap, CreditCard,
  ShoppingBag, History, CheckCircle2, AlertCircle,
} from 'lucide-react';

const emptyForm = {
  phone_number: '',
  first_name: '',
  last_name: '',
  address: '',
  profession: '',
  notes: '',
};

const formatDZD = (n) =>
  new Intl.NumberFormat('fr-DZ', { style: 'currency', currency: 'DZD', maximumFractionDigits: 0 })
    .format(n || 0);

const formatDate = (s) =>
  s ? new Date(s).toLocaleDateString('en-GB', { year: 'numeric', month: 'short', day: '2-digit' }) : '—';

const formatDateTime = (s) =>
  s ? new Date(s).toLocaleString('en-GB', { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' }) : '—';

const formatRelativeDate = (s) => {
  if (!s) return '—';
  const d = new Date(s);
  const days = Math.floor((Date.now() - d.getTime()) / (1000 * 60 * 60 * 24));
  if (days === 0) return 'Today';
  if (days === 1) return 'Yesterday';
  if (days < 30) return `${days} days ago`;
  return formatDate(s);
};

export default function ManageCustomers() {
  const [customers, setCustomers] = useState([]);
  const [loading, setLoading]     = useState(true);
  const [error, setError]         = useState('');
  const [success, setSuccess]     = useState('');
  const [search, setSearch]       = useState('');

  // Modal state: null | 'create' | 'edit' | 'view'
  const [modal, setModal]         = useState(null);
  const [editing, setEditing]     = useState(null);
  const [formData, setFormData]   = useState(emptyForm);
  const [submitting, setSubmitting] = useState(false);
  const [details, setDetails]     = useState(null);
  const [historyTab, setHistoryTab] = useState('sim');
  const [historyRows, setHistoryRows] = useState([]);
  const [historyLoading, setHistoryLoading] = useState(false);

  useEffect(() => {
    fetchCustomers();
  }, []);

  const fetchCustomers = async (q = '') => {
    try {
      setLoading(true);
      setError('');
      const r = await api.get('/customers', { params: { limit: 200, ...(q ? { q } : {}) } });
      setCustomers(r.data.data);
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to load customers.');
    } finally {
      setLoading(false);
    }
  };

  // Debounced search
  useEffect(() => {
    const id = setTimeout(() => fetchCustomers(search.trim()), 300);
    return () => clearTimeout(id);
  }, [search]);

  // ─── Modal handlers ───────────────────────────────────────────────────────

  const openCreate = () => {
    setFormData(emptyForm);
    setEditing(null);
    setModal('create');
  };

  const openEdit = (customer) => {
    setFormData({
      phone_number: customer.phone_number || '',
      first_name:   customer.first_name   || '',
      last_name:    customer.last_name    || '',
      address:      customer.address      || '',
      profession:   customer.profession   || '',
      notes:        customer.notes        || '',
    });
    setEditing(customer.id);
    setModal('edit');
  };

  const openView = async (customer, initialTab = 'sim') => {
    setEditing(customer.id);
    setDetails(null);
    setHistoryRows([]);
    setHistoryTab(initialTab);
    setModal('view');
    try {
      const r = await api.get(`/customers/${customer.id}`);
      setDetails(r.data.data);
      loadHistory(customer.id, initialTab);
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to load customer details.');
      setModal(null);
    }
  };

  const loadHistory = async (customerId, type) => {
    setHistoryLoading(true);
    setHistoryTab(type);
    try {
      const r = await api.get(`/customers/${customerId}/purchases`, { params: { type } });
      setHistoryRows(r.data.data);
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to load history.');
    } finally {
      setHistoryLoading(false);
    }
  };

  const closeModal = () => {
    setModal(null);
    setEditing(null);
    setFormData(emptyForm);
    setDetails(null);
    setHistoryRows([]);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    setError('');
    try {
      if (modal === 'create') {
        await api.post('/customers', formData);
        setSuccess(`Customer "${formData.first_name} ${formData.last_name}" created.`);
      } else if (modal === 'edit') {
        await api.patch(`/customers/${editing}`, formData);
        setSuccess(`Customer "${formData.first_name} ${formData.last_name}" updated.`);
      }
      setTimeout(() => setSuccess(''), 3500);
      closeModal();
      fetchCustomers(search.trim());
    } catch (err) {
      setError(err.response?.data?.message || 'Save failed.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = async (customer) => {
    const totalSales = (customer.sim_count || 0) + (customer.storm_count || 0) + (customer.accessory_count || 0);
    const warning = totalSales > 0
      ? `\n\nThis customer has ${totalSales} historical sale(s). The records will be preserved but lose the link.`
      : '';
    if (!window.confirm(
      `Delete "${customer.first_name} ${customer.last_name}" (${customer.phone_number})?${warning}\n\nThis cannot be undone.`
    )) return;

    try {
      const r = await api.delete(`/customers/${customer.id}`);
      setSuccess(r.data.message);
      setTimeout(() => setSuccess(''), 3500);
      fetchCustomers(search.trim());
    } catch (err) {
      setError(err.response?.data?.message || 'Delete failed.');
    }
  };

  // ─── Aggregate KPI strip ──────────────────────────────────────────────────
  const kpis = useMemo(() => {
    const total = customers.length;
    const withPurchases = customers.filter(
      (c) => (c.sim_count || 0) + (c.storm_count || 0) + (c.accessory_count || 0) > 0
    ).length;
    const totalSpent = customers.reduce((s, c) => s + (c.total_spent || 0), 0);
    const totalSims = customers.reduce((s, c) => s + (c.sim_count || 0), 0);
    return { total, withPurchases, totalSpent, totalSims };
  }, [customers]);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between border-b border-gray-200 pb-4">
        <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
          <UsersRound className="text-red-600" /> Manage Customers
        </h1>
        <button
          onClick={openCreate}
          className="flex items-center gap-2 rounded-md bg-red-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-red-700"
        >
          <Plus size={16} /> Add Customer
        </button>
      </div>

      {error && (
        <div className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700 flex items-start gap-2">
          <AlertCircle size={18} className="mt-0.5 flex-shrink-0" />
          <span>{error}</span>
        </div>
      )}
      {success && (
        <div className="rounded-md border border-green-200 bg-green-50 p-3 text-sm text-green-700 flex items-start gap-2">
          <CheckCircle2 size={18} className="mt-0.5 flex-shrink-0" />
          <span>{success}</span>
        </div>
      )}

      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <KpiCard icon={<UsersRound size={18} />}  label="Total customers" value={kpis.total} />
        <KpiCard icon={<ShoppingBag size={18} />} label="With purchases" value={kpis.withPurchases} />
        <KpiCard icon={<Smartphone size={18} />}  label="Total SIMs"     value={kpis.totalSims} />
        <KpiCard icon={<History size={18} />}     label="Total spent"   value={formatDZD(kpis.totalSpent)} />
      </div>

      {/* Search */}
      <div className="relative max-w-md">
        <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
        <input
          type="text"
          placeholder="Search by name, phone, or profession..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full rounded-md border border-gray-300 pl-9 pr-3 py-2 text-sm focus:border-red-500 focus:ring-red-500"
        />
      </div>

      {/* Table */}
      <div className="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-gray-200 overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Customer</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Phone</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Profession</th>
              <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">SIMs</th>
              <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Storm</th>
              <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Accessories</th>
              <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Total spent</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Last</th>
              <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200 bg-white">
            {loading ? (
              <tr><td colSpan="9" className="px-4 py-8 text-center"><RefreshCw className="inline animate-spin text-red-600" /></td></tr>
            ) : customers.length === 0 ? (
              <tr><td colSpan="9" className="px-4 py-8 text-center text-sm text-gray-500">
                {search ? 'No customers match your search.' : 'No customers yet. Add one to get started.'}
              </td></tr>
            ) : (
              customers.map((c) => (
                <tr key={c.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 whitespace-nowrap">
                    <div className="font-medium text-gray-900">{c.first_name} {c.last_name}</div>
                    <div className="text-xs text-gray-500 truncate max-w-[14rem]">{c.address}</div>
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap text-sm font-mono text-gray-700">{c.phone_number}</td>
                  <td className="px-4 py-3 whitespace-nowrap text-sm text-gray-600">{c.profession}</td>
                  <td className="px-4 py-3 whitespace-nowrap text-sm text-right">
                    <CountBtn count={c.sim_count} icon={<Smartphone size={14} />} onClick={() => openView(c, 'sim')} />
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap text-sm text-right">
                    <CountBtn count={c.storm_count} icon={<Zap size={14} />} onClick={() => openView(c, 'storm')} />
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap text-sm text-right">
                    <CountBtn count={c.accessory_count} icon={<CreditCard size={14} />} onClick={() => openView(c, 'accessory')} />
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap text-sm text-right font-medium text-gray-900">
                    {formatDZD(c.total_spent)}
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap text-sm text-gray-600">{formatRelativeDate(c.last_purchase_at)}</td>
                  <td className="px-4 py-3 whitespace-nowrap text-right text-sm font-medium space-x-3">
                    <button onClick={() => openView(c, 'sim')} className="text-blue-600 hover:text-blue-900" title="View profile">
                      <History size={18} />
                    </button>
                    <button onClick={() => openEdit(c)} className="text-blue-600 hover:text-blue-900" title="Edit">
                      <Pencil size={18} />
                    </button>
                    <button onClick={() => handleDelete(c)} className="text-red-600 hover:text-red-900" title="Delete">
                      <Trash2 size={18} />
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {(modal === 'create' || modal === 'edit') && (
        <FormModal
          mode={modal}
          formData={formData}
          setFormData={setFormData}
          submitting={submitting}
          onSubmit={handleSubmit}
          onClose={closeModal}
        />
      )}
      {modal === 'view' && (
        <ViewModal
          customer={details}
          loading={!details}
          onClose={closeModal}
          onEdit={() => details && openEdit(details)}
          historyTab={historyTab}
          historyRows={historyRows}
          historyLoading={historyLoading}
          onChangeTab={(t) => details && loadHistory(details.id, t)}
        />
      )}
    </div>
  );
}

function CountBtn({ count, icon, onClick }) {
  if (!count || count === 0) {
    return <span className="text-xs text-gray-400 inline-flex items-center gap-1">{icon} 0</span>;
  }
  return (
    <button
      onClick={onClick}
      className="inline-flex items-center gap-1 rounded-full bg-blue-50 hover:bg-blue-100 text-blue-700 px-2 py-0.5 text-xs font-semibold transition-colors"
      title="View history"
    >
      {icon} {count}
    </button>
  );
}

function KpiCard({ icon, label, value }) {
  return (
    <div className="rounded-lg bg-white border border-gray-200 p-3 flex items-center gap-3">
      <div className="text-red-600">{icon}</div>
      <div>
        <div className="text-xs text-gray-500 uppercase tracking-wider">{label}</div>
        <div className="text-xl font-bold text-gray-900">{value}</div>
      </div>
    </div>
  );
}

function FormModal({ mode, formData, setFormData, submitting, onSubmit, onClose }) {
  const setField = (name) => (e) => setFormData((f) => ({ ...f, [name]: e.target.value }));

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-lg overflow-hidden">
        <div className="flex items-center justify-between border-b border-gray-100 bg-gray-50 p-4">
          <h3 className="font-bold text-lg text-gray-900">
            {mode === 'create' ? 'Add new customer' : 'Edit customer'}
          </h3>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600"><X size={20} /></button>
        </div>

        <form onSubmit={onSubmit} className="p-6 space-y-3">
          <Field icon={<Phone size={14} />} label="Phone number" required value={formData.phone_number} onChange={setField('phone_number')} placeholder="0555..." />
          <div className="grid grid-cols-2 gap-3">
            <Field icon={<User size={14} />} label="First name" required value={formData.first_name} onChange={setField('first_name')} />
            <Field icon={<User size={14} />} label="Last name"  required value={formData.last_name}  onChange={setField('last_name')} />
          </div>
          <Field icon={<MapPin size={14} />}    label="Address"    required value={formData.address}    onChange={setField('address')} />
          <Field icon={<Briefcase size={14} />} label="Profession" required value={formData.profession} onChange={setField('profession')} />
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Notes (optional)</label>
            <textarea
              value={formData.notes}
              onChange={setField('notes')}
              rows={2}
              maxLength={1000}
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-red-500 focus:ring-red-500"
              placeholder="Any extra info..."
            />
          </div>

          <div className="flex justify-end gap-3 pt-4 border-t border-gray-100">
            <button type="button" onClick={onClose} className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50">Cancel</button>
            <button type="submit" disabled={submitting} className="px-4 py-2 text-sm font-semibold text-white bg-red-600 rounded-md hover:bg-red-700 disabled:opacity-50">
              {submitting ? 'Saving...' : mode === 'create' ? 'Create' : 'Save changes'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

function Field({ icon, label, required, value, onChange, placeholder }) {
  return (
    <div>
      <label className="block text-sm font-medium text-gray-700 mb-1 flex items-center gap-1">
        {icon} {label}
      </label>
      <input
        type="text" required={required} value={value} onChange={onChange}
        placeholder={placeholder} autoComplete="off"
        className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-red-500 focus:ring-red-500"
      />
    </div>
  );
}

function ViewModal({ customer, loading, onClose, onEdit, historyTab, historyRows, historyLoading, onChangeTab }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-3xl max-h-[92vh] flex flex-col">
        <div className="flex items-center justify-between border-b border-gray-100 bg-gray-50 p-4">
          <h3 className="font-bold text-lg text-gray-900 flex items-center gap-2">
            <UsersRound className="text-red-600" size={20} /> Customer profile
          </h3>
          <div className="flex items-center gap-2">
            {customer && (
              <button onClick={onEdit} className="inline-flex items-center gap-1 text-sm text-blue-600 hover:text-blue-900 px-2 py-1">
                <Pencil size={14} /> Edit
              </button>
            )}
            <button onClick={onClose} className="text-gray-400 hover:text-gray-600"><X size={20} /></button>
          </div>
        </div>

        <div className="p-6 overflow-y-auto space-y-6">
          {loading || !customer ? (
            <div className="flex justify-center py-12"><RefreshCw className="animate-spin text-red-600" size={28} /></div>
          ) : (
            <>
              {/* Identity */}
              <div className="space-y-1">
                <div className="text-2xl font-bold text-gray-900">{customer.first_name} {customer.last_name}</div>
                <div className="text-sm text-gray-600 flex flex-wrap gap-x-4 gap-y-1">
                  <span className="flex items-center gap-1 font-mono"><Phone size={14} /> {customer.phone_number}</span>
                  <span className="flex items-center gap-1"><Briefcase size={14} /> {customer.profession}</span>
                </div>
                <div className="text-sm text-gray-600 flex items-center gap-1">
                  <MapPin size={14} /> {customer.address}
                </div>
                {customer.notes && (
                  <div className="text-sm text-gray-700 mt-2 pt-2 border-t border-gray-100">
                    <span className="text-xs uppercase tracking-wider text-gray-500">Notes:</span> {customer.notes}
                  </div>
                )}
              </div>

              {/* Stats */}
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                <KpiCard icon={<Smartphone size={18} />} label="SIM cards"   value={customer.stats?.sim_count || 0} />
                <KpiCard icon={<Zap size={18} />}        label="Storm/Bundle" value={customer.stats?.storm_count || 0} />
                <KpiCard icon={<CreditCard size={18} />} label="Accessories" value={customer.stats?.accessory_count || 0} />
                <KpiCard icon={<History size={18} />}    label="Total spent" value={formatDZD(customer.stats?.total_spent)} />
              </div>

              {/* History tabs */}
              <div>
                <div className="flex gap-2 border-b border-gray-200">
                  <TabBtn active={historyTab === 'sim'}       onClick={() => onChangeTab('sim')}       icon={<Smartphone size={14} />} label={`SIM cards (${customer.stats?.sim_count || 0})`} />
                  <TabBtn active={historyTab === 'storm'}     onClick={() => onChangeTab('storm')}     icon={<Zap size={14} />}        label={`Storm/Bundle (${customer.stats?.storm_count || 0})`} />
                  <TabBtn active={historyTab === 'accessory'} onClick={() => onChangeTab('accessory')} icon={<CreditCard size={14} />} label={`Accessories (${customer.stats?.accessory_count || 0})`} />
                </div>

                <div className="mt-3">
                  {historyLoading ? (
                    <div className="flex justify-center py-8"><RefreshCw className="animate-spin text-red-600" /></div>
                  ) : historyRows.length === 0 ? (
                    <div className="text-sm text-gray-500 italic py-4">No purchases of this type.</div>
                  ) : (
                    <HistoryTable type={historyTab} rows={historyRows} />
                  )}
                </div>
              </div>

              <div className="text-xs text-gray-400 pt-4 border-t border-gray-100">
                Created {formatDate(customer.created_at)} · last updated {formatDate(customer.updated_at)}
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

function TabBtn({ active, onClick, icon, label }) {
  return (
    <button
      onClick={onClick}
      className={`flex items-center gap-1 px-3 py-2 text-sm font-medium border-b-2 -mb-px transition-colors ${
        active
          ? 'border-red-600 text-red-600'
          : 'border-transparent text-gray-600 hover:text-gray-900'
      }`}
    >
      {icon} {label}
    </button>
  );
}

function HistoryTable({ type, rows }) {
  return (
    <div className="rounded-md border border-gray-200 overflow-x-auto">
      <table className="min-w-full text-xs">
        <thead className="bg-gray-50 text-gray-500">
          <tr>
            <th className="px-2 py-1.5 text-left font-medium">Date</th>
            {type === 'sim' && <th className="px-2 py-1.5 text-left font-medium">Serial</th>}
            <th className="px-2 py-1.5 text-left font-medium">{type === 'storm' ? 'Note' : type === 'accessory' ? 'Product' : 'Offer'}</th>
            {type === 'accessory' && <th className="px-2 py-1.5 text-left font-medium">Category</th>}
            <th className="px-2 py-1.5 text-right font-medium">Amount</th>
            <th className="px-2 py-1.5 text-left font-medium">Cashier · Store</th>
            <th className="px-2 py-1.5 text-center font-medium">Status</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-100">
          {rows.map((r) => (
            <tr key={r.id} className={r.is_voided ? 'bg-red-50/50 line-through text-gray-400' : ''}>
              <td className="px-2 py-1.5 text-gray-600 whitespace-nowrap">{formatDateTime(r.at)}</td>
              {type === 'sim' && <td className="px-2 py-1.5 font-mono">{r.serial}</td>}
              <td className="px-2 py-1.5">{r.label || '—'}</td>
              {type === 'accessory' && <td className="px-2 py-1.5 text-gray-600">{r.category || '—'}</td>}
              <td className="px-2 py-1.5 text-right font-medium">{formatDZD(r.amount)}</td>
              <td className="px-2 py-1.5 text-gray-600 whitespace-nowrap">{r.cashier_name} · {r.store_name}</td>
              <td className="px-2 py-1.5 text-center">
                {r.is_voided ? (
                  <span className="inline-flex rounded-full bg-red-100 px-1.5 text-xs font-semibold text-red-700" title={r.void_reason || ''}>Void</span>
                ) : (
                  <span className="inline-flex rounded-full bg-green-100 px-1.5 text-xs font-semibold text-green-700">OK</span>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
