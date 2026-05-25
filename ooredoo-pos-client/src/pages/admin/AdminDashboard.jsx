import { useState, useEffect } from 'react';
import api from '../../api/axios';
import { Store, User, DollarSign, Activity, CreditCard, Smartphone } from 'lucide-react';

export default function AdminDashboard() {
  const [sessions, setSessions] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchLiveSessions();
    // Optional: Refresh data every 30 seconds
    const interval = setInterval(fetchLiveSessions, 30000);
    return () => clearInterval(interval);
  }, []);

  const fetchLiveSessions = async () => {
    try {
      const response = await api.get('/sessions/live');
      setSessions(response.data.data);
      setError('');
    } catch (err) {
      console.error('Failed to fetch live sessions', err);
      setError('Failed to load live store data. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  // Helper to format currency in Algerian Dinar (DZD)
  const formatDZD = (amount) => {
    return new Intl.NumberFormat('fr-DZ', { 
      style: 'currency', 
      currency: 'DZD' 
    }).format(amount || 0);
  };

  if (isLoading && sessions.length === 0) {
    return (
      <div className="flex h-64 items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-red-600 border-t-transparent"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Live Store Overview</h1>
        <button 
          onClick={fetchLiveSessions}
          className="rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
        >
          Refresh Now
        </button>
      </div>

      {error && (
        <div className="rounded-md bg-red-50 p-4 text-sm text-red-600 border border-red-200">
          {error}
        </div>
      )}

      {sessions.length === 0 && !isLoading && !error ? (
        <div className="rounded-xl border-2 border-dashed border-gray-300 p-12 text-center">
          <Store className="mx-auto h-12 w-12 text-gray-400" />
          <h3 className="mt-2 text-sm font-semibold text-gray-900">No Active Sessions</h3>
          <p className="mt-1 text-sm text-gray-500">There are currently no cashiers with an open shift.</p>
        </div>
      ) : (
        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {sessions.map((session) => (
            <div key={session.session_id} className="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-gray-200">
              
              {/* Card Header */}
              <div className="border-b border-gray-200 bg-gray-50 p-4">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2 text-sm font-medium text-gray-900">
                    <Store size={18} className="text-red-600" />
                    {session.store_name}
                  </div>
                  <span className="inline-flex items-center rounded-full bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20">
                    Live
                  </span>
                </div>
                <div className="mt-2 flex items-center gap-2 text-sm text-gray-600">
                  <User size={16} />
                  {session.cashier_name}
                </div>
              </div>

              {/* Card Body - Financials */}
              <div className="p-4 space-y-4">
                <div>
                  <p className="text-xs font-medium text-gray-500 uppercase tracking-wider">Expected Register Cash</p>
                  <p className="mt-1 text-2xl font-bold text-gray-900 flex items-center gap-2">
                    <DollarSign size={24} className="text-green-500" />
                    {formatDZD(session.expected_register_cash)}
                  </p>
                </div>

                <div className="grid grid-cols-2 gap-4 border-t border-gray-100 pt-4">
                  <div>
                    <p className="text-xs text-gray-500 flex items-center gap-1"><Smartphone size={14}/> SIM Sales</p>
                    <p className="font-semibold text-gray-900">{formatDZD(session.sim_total_selling_price)}</p>
                    <p className="text-xs text-gray-400">{session.sim_units_sold} units</p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-500 flex items-center gap-1"><Activity size={14}/> Storm</p>
                    <p className="font-semibold text-gray-900">{formatDZD(session.storm_total)}</p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-500 flex items-center gap-1"><CreditCard size={14}/> Accessories</p>
                    <p className="font-semibold text-gray-900">{formatDZD(session.accessories_total)}</p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-500 flex items-center gap-1 text-red-600">Debts</p>
                    <p className="font-semibold text-gray-900">{formatDZD(session.debt_total)}</p>
                  </div>
                </div>
              </div>

            </div>
          ))}
        </div>
      )}
    </div>
  );
}