import { useState, useEffect } from 'react';
import api from '../../api/axios';
import { Wallet, Coins, Gift, Building2, Diff, RefreshCw, X, CheckCircle2 } from 'lucide-react';

export default function CashManagement() {
  const [globalPool, setGlobalPool] = useState({ balance: 0, bonus: 0, points: 0 });
  const [registers, setRegisters] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  
  // Modal State
  const [activeModal, setActiveModal] = useState(null); // 'pool' | 'register' | null
  const [selectedRegister, setSelectedRegister] = useState(null);
  const [formData, setFormData] = useState({ amount: '', type: 'add', note: '' });
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    fetchFinancials();
  }, []);

  const fetchFinancials = async () => {
    try {
      setIsLoading(true);
      // Assuming these endpoints will be created in your Node backend next
      const [poolRes, registersRes] = await Promise.all([
        api.get('/finances/pool').catch(() => ({ data: { data: { balance: 0, bonus: 0, points: 0 } } })), // Fallbacks if backend not ready
        api.get('/finances/registers').catch(() => ({ data: { data: [] } }))
      ]);
      
      setGlobalPool(poolRes.data.data);
      setRegisters(registersRes.data.data);
    } catch (err) {
      console.error('Failed to load financials', err);
    } finally {
      setIsLoading(false);
    }
  };

  const openPoolModal = () => {
    setFormData({ amount: '', type: 'add', field: 'balance', note: '' });
    setActiveModal('pool');
  };

  const openRegisterModal = (store) => {
    setSelectedRegister(store);
    setFormData({ amount: '', type: 'add', note: '' });
    setActiveModal('register');
  };

  const handleUpdateSubmit = async (e) => {
    e.preventDefault();
    setIsSubmitting(true);
    
    try {
      const payload = {
        amount: Number(formData.amount),
        type: formData.type, // 'add' or 'subtract'
        note: formData.note
      };

      if (activeModal === 'pool') {
        payload.field = formData.field; // 'balance', 'bonus', or 'points'
        await api.put('/finances/pool', payload);
      } else if (activeModal === 'register') {
        await api.put(`/finances/registers/${selectedRegister.id}`, payload);
      }

      setActiveModal(null);
      fetchFinancials(); // Refresh data
    } catch (err) {
      alert(err.response?.data?.message || 'Update failed. Check backend routes.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const formatDZD = (amount) => {
    return new Intl.NumberFormat('fr-DZ', { style: 'currency', currency: 'DZD' }).format(amount || 0);
  };

  if (isLoading) {
    return <div className="p-6 flex justify-center"><RefreshCw className="animate-spin text-red-600" /></div>;
  }

  return (
    <div className="space-y-8 relative">
      
      {/* ─── MODAL OVERLAY ──────────────────────────────────────────────── */}
      {activeModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
          <div className="bg-white rounded-xl shadow-xl w-full max-w-md overflow-hidden animate-in fade-in zoom-in duration-200">
            <div className="flex justify-between items-center p-4 border-b border-gray-100 bg-gray-50">
              <h3 className="font-bold text-lg text-gray-900">
                {activeModal === 'pool' ? 'Adjust Global Pool' : `Adjust ${selectedRegister?.name} Cash`}
              </h3>
              <button onClick={() => setActiveModal(null)} className="text-gray-400 hover:text-gray-600"><X size={20} /></button>
            </div>
            
            <form onSubmit={handleUpdateSubmit} className="p-6 space-y-4">
              
              {activeModal === 'pool' && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Select Asset to Update</label>
                  <select name="field" value={formData.field} onChange={(e) => setFormData({...formData, field: e.target.value})} className="w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500">
                    <option value="balance">Main Balance (Solde)</option>
                    <option value="bonus">Bonus Balance</option>
                    <option value="points">Loyalty Points</option>
                  </select>
                </div>
              )}

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Action</label>
                  <select name="type" value={formData.type} onChange={(e) => setFormData({...formData, type: e.target.value})} className="w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500">
                    <option value="add">Add (+)</option>
                    <option value="subtract">Remove (-)</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Amount</label>
                  <input required type="number" min="1" step="0.01" value={formData.amount} onChange={(e) => setFormData({...formData, amount: e.target.value})} className="w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500" placeholder="0.00" />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Reason / Note</label>
                <input required type="text" value={formData.note} onChange={(e) => setFormData({...formData, note: e.target.value})} className="w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500" placeholder="e.g., Headquarters top-up, Bank deposit..." />
              </div>

              <div className="mt-6 flex justify-end gap-3 pt-4 border-t border-gray-100">
                <button type="button" onClick={() => setActiveModal(null)} className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50">Cancel</button>
                <button type="submit" disabled={isSubmitting} className="px-4 py-2 text-sm font-medium text-white bg-red-600 rounded-md hover:bg-red-700 disabled:opacity-50 flex items-center gap-2">
                  <CheckCircle2 size={16} /> {isSubmitting ? 'Saving...' : 'Confirm Adjustment'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ─── GLOBAL POOL SECTION ────────────────────────────────────────── */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-bold text-gray-900 flex items-center gap-2">
            <Building2 className="text-red-600" /> Global Digital Pool
          </h2>
          <button onClick={openPoolModal} className="flex items-center gap-2 text-sm font-medium text-red-600 bg-red-50 px-3 py-1.5 rounded-lg hover:bg-red-100 transition-colors">
            <Diff size={16} /> Adjust Balances
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="bg-white p-6 rounded-xl shadow-sm ring-1 ring-gray-200 border-t-4 border-t-blue-500">
            <div className="flex justify-between items-start">
              <div>
                <p className="text-sm font-bold text-gray-500 uppercase tracking-wider">Main Balance (Solde)</p>
                <p className="mt-2 text-3xl font-extrabold text-gray-900">{formatDZD(globalPool.balance)}</p>
              </div>
              <div className="p-3 bg-blue-50 rounded-lg"><Wallet className="text-blue-600" size={24}/></div>
            </div>
          </div>

          <div className="bg-white p-6 rounded-xl shadow-sm ring-1 ring-gray-200 border-t-4 border-t-orange-500">
            <div className="flex justify-between items-start">
              <div>
                <p className="text-sm font-bold text-gray-500 uppercase tracking-wider">Bonus Balance</p>
                <p className="mt-2 text-3xl font-extrabold text-gray-900">{formatDZD(globalPool.bonus)}</p>
              </div>
              <div className="p-3 bg-orange-50 rounded-lg"><Gift className="text-orange-600" size={24}/></div>
            </div>
          </div>

          <div className="bg-white p-6 rounded-xl shadow-sm ring-1 ring-gray-200 border-t-4 border-t-purple-500">
            <div className="flex justify-between items-start">
              <div>
                <p className="text-sm font-bold text-gray-500 uppercase tracking-wider">Loyalty Points</p>
                <p className="mt-2 text-3xl font-extrabold text-gray-900">{globalPool.points.toLocaleString()}</p>
              </div>
              <div className="p-3 bg-purple-50 rounded-lg"><Coins className="text-purple-600" size={24}/></div>
            </div>
          </div>
        </div>
      </div>

      {/* ─── STORE REGISTERS SECTION ────────────────────────────────────── */}
      <div className="pt-6 border-t border-gray-200">
        <h2 className="text-xl font-bold text-gray-900 mb-4 flex items-center gap-2">
          <Wallet className="text-green-600" /> Physical Store Registers
        </h2>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {registers.length === 0 ? (
            <p className="text-gray-500 text-sm italic col-span-2">No active registers found. Check database connection.</p>
          ) : (
            registers.map(store => (
              <div key={store.id} className="bg-white p-6 rounded-xl shadow-sm ring-1 ring-gray-200 flex justify-between items-center">
                <div>
                  <p className="text-sm font-bold text-gray-500 uppercase tracking-wider">{store.name}</p>
                  <p className="mt-1 text-2xl font-extrabold text-green-600">{formatDZD(store.current_cash)}</p>
                  <p className="text-xs text-gray-400 mt-1">Available in drawer</p>
                </div>
                <button 
                  onClick={() => openRegisterModal(store)}
                  className="px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors"
                >
                  Deposit / Withdraw
                </button>
              </div>
            ))
          )}
        </div>
      </div>

    </div>
  );
}