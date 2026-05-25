import { useState, useEffect, useMemo } from 'react';
import api from '../../api/axios';
import {
  PackagePlus, Save, AlertCircle, CheckCircle2, RefreshCw,
  User, Hash, ListOrdered, Boxes,
} from 'lucide-react';

const emptyForm = {
  cashier_id: '',
  first_serial: '',
  count: '',
};

/**
 * Calculate the last serial number in a sequence using BigInt so we don't
 * lose precision on 16+ digit numbers.
 */
function calcLastSerial(firstSerial, count) {
  if (!firstSerial || !count) return '';
  if (!/^\d+$/.test(firstSerial)) return '';
  const n = parseInt(count, 10);
  if (!Number.isFinite(n) || n < 1) return '';
  try {
    const start = BigInt(firstSerial);
    const last = start + BigInt(n - 1);
    return last.toString().padStart(firstSerial.length, '0');
  } catch {
    return '';
  }
}

export default function AssignStock() {
  const [cashiers, setCashiers] = useState([]);
  const [inventory, setInv]     = useState([]);
  const [isLoading, setLoading] = useState(true);

  // Form state
  const [formData, setFormData] = useState(emptyForm);
  const [status, setStatus]     = useState({ type: '', message: '' });
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    loadAll();
  }, []);

  const loadAll = async () => {
    try {
      setLoading(true);
      const [usersRes, invRes] = await Promise.all([
        api.get('/users'),
        api.get('/stock/cashiers'),
      ]);
      setCashiers(usersRes.data.data.filter((u) => u.role === 'cashier' && u.is_active));
      setInv(invRes.data.data);
    } catch (err) {
      console.error('Load failed', err);
      setStatus({ type: 'error', message: 'Failed to load data.' });
    } finally {
      setLoading(false);
    }
  };

  const lastSerial = useMemo(
    () => calcLastSerial(formData.first_serial, formData.count),
    [formData.first_serial, formData.count]
  );

  const handleChange = (e) => {
    setFormData((prev) => ({ ...prev, [e.target.name]: e.target.value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!formData.cashier_id || !formData.first_serial || !formData.count) {
      setStatus({ type: 'error', message: 'All fields are required.' });
      return;
    }

    setSubmitting(true);
    setStatus({ type: '', message: '' });

    try {
      const payload = {
        cashier_id:    Number(formData.cashier_id),
        first_serial:  formData.first_serial.trim(),
        count:         Number(formData.count),
      };
      const r = await api.post('/stock/assign', payload);
      const d = r.data.data;
      setStatus({
        type: 'success',
        message: `Assigned ${d.count} SIM card(s) to ${d.cashier.name} (${d.first_serial} → ${d.last_serial}).`,
      });
      setFormData(emptyForm);
      await loadAll();
      setTimeout(() => setStatus({ type: '', message: '' }), 5000);
    } catch (err) {
      setStatus({ type: 'error', message: err.response?.data?.message || 'Assignment failed.' });
    } finally {
      setSubmitting(false);
    }
  };

  if (isLoading) {
    return (
      <div className="flex justify-center p-10">
        <RefreshCw className="animate-spin text-red-600" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* ─── Header ─────────────────────────────────────────────────── */}
      <div className="flex items-center gap-2 border-b border-gray-200 pb-4">
        <PackagePlus className="text-red-600" size={28} />
        <h1 className="text-2xl font-bold text-gray-900">Assign SIM Stock</h1>
      </div>

      {status.message && (
        <div
          className={`flex items-start gap-2 rounded-md p-4 ${
            status.type === 'error'
              ? 'bg-red-50 text-red-700 border border-red-200'
              : 'bg-green-50 text-green-700 border border-green-200'
          }`}
        >
          {status.type === 'error' ? <AlertCircle size={20} /> : <CheckCircle2 size={20} />}
          <span className="text-sm">{status.message}</span>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">
        {/* ─── Form ──────────────────────────────────────────────────── */}
        <form
          onSubmit={handleSubmit}
          className="lg:col-span-3 bg-white rounded-xl shadow-sm ring-1 ring-gray-200 p-6 space-y-5"
        >
          <h2 className="text-lg font-semibold text-gray-900">New Assignment Batch</h2>

          {/* Cashier */}
          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-1 flex items-center gap-1">
              <User size={14} /> Cashier
            </label>
            <select
              required
              name="cashier_id"
              value={formData.cashier_id}
              onChange={handleChange}
              className="w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500 text-sm"
            >
              <option value="">-- Select cashier --</option>
              {cashiers.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.full_name} {c.store_name ? `— ${c.store_name}` : ''}
                </option>
              ))}
            </select>
          </div>

          {/* First serial + count */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div className="sm:col-span-2">
              <label className="block text-sm font-semibold text-gray-700 mb-1 flex items-center gap-1">
                <Hash size={14} /> First Serial Number
              </label>
              <input
                required
                type="text"
                inputMode="numeric"
                pattern="\d{10,22}"
                name="first_serial"
                value={formData.first_serial}
                onChange={handleChange}
                placeholder="2060051001409551"
                className="w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500 text-sm font-mono tracking-wider"
              />
              <p className="mt-1 text-xs text-gray-500">10-22 digits, numeric only.</p>
            </div>

            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-1 flex items-center gap-1">
                <ListOrdered size={14} /> Count
              </label>
              <input
                required
                type="number"
                min="1"
                max="1000"
                name="count"
                value={formData.count}
                onChange={handleChange}
                placeholder="50"
                className="w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500 text-sm"
              />
            </div>
          </div>

          {/* Computed last serial preview */}
          {lastSerial && (
            <div className="rounded-md bg-blue-50 border border-blue-200 p-3 text-sm">
              <div className="font-semibold text-blue-900 mb-1">Sequence preview</div>
              <div className="font-mono text-blue-800">
                {formData.first_serial} → {lastSerial}
              </div>
              <div className="text-xs text-blue-700 mt-1">
                {formData.count} consecutive cards will be created.
              </div>
            </div>
          )}

          <div className="pt-2 flex justify-end">
            <button
              type="submit"
              disabled={submitting}
              className="flex items-center gap-2 rounded-md bg-red-600 px-6 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-red-700 disabled:opacity-50"
            >
              <Save size={16} />
              {submitting ? 'Assigning...' : 'Confirm Assignment'}
            </button>
          </div>
        </form>

        {/* ─── Current Inventory Summary ──────────────────────────────── */}
        <aside className="lg:col-span-2 bg-white rounded-xl shadow-sm ring-1 ring-gray-200 p-6 space-y-4">
          <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
            <Boxes className="text-red-600" size={20} /> Cashier Inventories
          </h2>

          {inventory.length === 0 ? (
            <p className="text-sm italic text-gray-500">No SIM cards assigned yet.</p>
          ) : (
            <ul className="divide-y divide-gray-100">
              {inventory.map((c) => (
                <li key={c.cashier_id} className="py-3 first:pt-0 last:pb-0">
                  <div className="flex items-center justify-between">
                    <div>
                      <div className="font-semibold text-sm text-gray-800">{c.cashier_name}</div>
                      <div className="text-xs text-gray-500">{c.store_name}</div>
                    </div>
                    <span
                      className={`px-2 py-0.5 rounded-full text-xs font-bold ${
                        c.is_low_stock
                          ? 'bg-red-100 text-red-700'
                          : 'bg-green-100 text-green-800'
                      }`}
                    >
                      {c.available_count} available
                    </span>
                  </div>
                  {c.next_serial && (
                    <div className="mt-1 text-xs text-gray-500 font-mono">
                      Next: {c.next_serial}
                      {c.last_serial && c.last_serial !== c.next_serial && ` … ${c.last_serial}`}
                    </div>
                  )}
                </li>
              ))}
            </ul>
          )}
        </aside>
      </div>
    </div>
  );
}
