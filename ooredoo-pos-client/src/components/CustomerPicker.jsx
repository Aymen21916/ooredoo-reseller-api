import { useState } from 'react';
import api from '../api/axios';
import {
  CheckCircle2, Search, Plus, Phone, User, MapPin, Briefcase,
} from 'lucide-react';

const formatDZD = (n) =>
  new Intl.NumberFormat('fr-DZ', { style: 'currency', currency: 'DZD', maximumFractionDigits: 0 })
    .format(n || 0);

const emptyForm = { phone_number: '', first_name: '', last_name: '', address: '', profession: '' };

/**
 * Reusable customer step. Renders phone lookup → confirm-existing OR fill-form
 * for a new customer → calls onConfirm(customer) when done.
 *
 * Used by the SIM, Storm, and Accessory sale modals.
 */
export default function CustomerPicker({ onConfirm, onError }) {
  const [phoneInput, setPhoneInput] = useState('');
  const [state, setState]           = useState('idle'); // idle|searching|found|not-found
  const [foundCustomer, setFound]   = useState(null);
  const [form, setForm]             = useState(emptyForm);
  const [saving, setSaving]         = useState(false);

  const handleLookup = async (e) => {
    e.preventDefault();
    if (!phoneInput.trim()) return;
    setState('searching');
    try {
      const r = await api.get('/customers/lookup', { params: { phone: phoneInput.trim() } });
      if (r.data.data) {
        setFound(r.data.data);
        setState('found');
      } else {
        setForm({ ...emptyForm, phone_number: phoneInput.trim() });
        setState('not-found');
      }
    } catch (err) {
      onError?.(err.response?.data?.message || 'Lookup failed.');
      setState('idle');
    }
  };

  const handleCreate = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      const r = await api.post('/customers', form);
      onConfirm(r.data.data);
    } catch (err) {
      if (err.response?.data?.code === 'CUSTOMER_PHONE_EXISTS') {
        const lookup = await api.get('/customers/lookup', { params: { phone: form.phone_number } });
        if (lookup.data.data) {
          setFound(lookup.data.data);
          setState('found');
          onError?.('A customer with that phone already exists. Please confirm.');
          setSaving(false);
          return;
        }
      }
      onError?.(err.response?.data?.message || 'Failed to save customer.');
    } finally {
      setSaving(false);
    }
  };

  const reset = () => {
    setState('idle');
    setFound(null);
    setForm(emptyForm);
  };

  if (state === 'found' && foundCustomer) {
    const s = foundCustomer.stats || {};
    return (
      <div>
        <div className="rounded-xl border-2 border-green-200 bg-green-50 p-4 space-y-2">
          <div className="flex items-center gap-2 text-green-800 font-semibold">
            <CheckCircle2 size={18} /> Customer found
          </div>
          <div className="grid grid-cols-2 gap-x-4 gap-y-1 text-sm pt-2">
            <Kv icon={<User size={14} />}      label="Name"       value={`${foundCustomer.first_name} ${foundCustomer.last_name}`} />
            <Kv icon={<Phone size={14} />}     label="Phone"      value={foundCustomer.phone_number} />
            <Kv icon={<MapPin size={14} />}    label="Address"    value={foundCustomer.address} />
            <Kv icon={<Briefcase size={14} />} label="Profession" value={foundCustomer.profession} />
          </div>
          {((s.sim_count || 0) + (s.storm_count || 0) + (s.accessory_count || 0)) > 0 && (
            <div className="pt-3 mt-3 border-t border-green-200 grid grid-cols-3 gap-2 text-xs">
              <Mini label="SIMs" value={s.sim_count || 0} />
              <Mini label="Storm" value={s.storm_count || 0} />
              <Mini label="Accessories" value={s.accessory_count || 0} />
            </div>
          )}
          {(s.total_spent || 0) > 0 && (
            <div className="text-center pt-2 text-xs text-green-800">
              Total spent: <span className="font-bold">{formatDZD(s.total_spent)}</span>
            </div>
          )}
        </div>
        <div className="mt-4 flex justify-between gap-2">
          <button
            onClick={reset}
            className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
          >
            Different customer
          </button>
          <button
            onClick={() => onConfirm(foundCustomer)}
            className="flex items-center gap-2 px-4 py-2 text-sm font-semibold text-white bg-green-600 rounded-md hover:bg-green-700"
          >
            <CheckCircle2 size={16} /> Confirm & continue
          </button>
        </div>
      </div>
    );
  }

  if (state === 'not-found') {
    const setField = (k) => (v) => setForm((f) => ({ ...f, [k]: v }));
    return (
      <div>
        <p className="text-xs text-gray-500 mb-3">
          No customer found with phone <span className="font-mono">{form.phone_number}</span>. Fill in the details to register them.
        </p>
        <form onSubmit={handleCreate} className="space-y-3">
          <Input label="Phone number" icon={<Phone size={14} />} value={form.phone_number} onChange={setField('phone_number')} required />
          <div className="grid grid-cols-2 gap-3">
            <Input label="First name" icon={<User size={14} />} value={form.first_name} onChange={setField('first_name')} required />
            <Input label="Last name"  icon={<User size={14} />} value={form.last_name}  onChange={setField('last_name')}  required />
          </div>
          <Input label="Address"    icon={<MapPin size={14} />}    value={form.address}    onChange={setField('address')}    required />
          <Input label="Profession" icon={<Briefcase size={14} />} value={form.profession} onChange={setField('profession')} required />
          <div className="pt-2 flex justify-between">
            <button type="button" onClick={reset} className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50">Search again</button>
            <button type="submit" disabled={saving} className="flex items-center gap-2 px-4 py-2 text-sm font-semibold text-white bg-red-600 rounded-md hover:bg-red-700 disabled:opacity-50">
              <Plus size={16} /> {saving ? 'Saving...' : 'Create & continue'}
            </button>
          </div>
        </form>
      </div>
    );
  }

  // idle / searching: phone-lookup form
  return (
    <form onSubmit={handleLookup} className="space-y-3">
      <Input
        label="Customer phone number"
        icon={<Phone size={14} />}
        value={phoneInput}
        onChange={setPhoneInput}
        required autoFocus
      />
      <div className="flex justify-end">
        <button
          type="submit"
          disabled={state === 'searching' || !phoneInput.trim()}
          className="flex items-center gap-2 px-4 py-2 text-sm font-semibold text-white bg-red-600 rounded-md hover:bg-red-700 disabled:opacity-50"
        >
          <Search size={16} /> {state === 'searching' ? 'Searching...' : 'Look up customer'}
        </button>
      </div>
    </form>
  );
}

function Input({ label, icon, value, onChange, required, autoFocus }) {
  return (
    <div>
      <label className="block text-sm font-medium text-gray-700 mb-1 flex items-center gap-1">{icon} {label}</label>
      <input
        type="text" value={value}
        onChange={(e) => onChange(e.target.value)}
        required={required} autoFocus={autoFocus} autoComplete="off"
        className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-red-500 focus:ring-red-500"
      />
    </div>
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

function Mini({ label, value }) {
  return (
    <div className="text-center">
      <div className="text-xs text-gray-500">{label}</div>
      <div className="font-bold text-gray-900">{value}</div>
    </div>
  );
}
