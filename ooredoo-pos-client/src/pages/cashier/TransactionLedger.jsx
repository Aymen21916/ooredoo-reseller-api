import { useState, useEffect } from 'react';
import api from '../../api/axios';
import { Clock, Ban, RefreshCw, Smartphone, Zap, CreditCard, AlertTriangle, CheckCircle2 } from 'lucide-react';

export default function TransactionLedger({ sessionId, refreshTrigger, onVoidSuccess }) {
  const [transactions, setTransactions] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  // Re-fetch when the component loads or when the parent tells it to (refreshTrigger)
  useEffect(() => {
    if (sessionId) fetchHistory();
  }, [sessionId, refreshTrigger]);

  const fetchHistory = async () => {
    try {
      setIsLoading(true);
      const response = await api.get(`/sessions/${sessionId}/history`);
      setTransactions(response.data.data);
    } catch (err) {
      console.error('Failed to fetch history', err);
    } finally {
      setIsLoading(false);
    }
  };

  const handleVoid = async (type, id) => {
    if (!window.confirm('Are you sure you want to void this transaction? This will reverse the cash and restore stock.')) return;
    
    try {
      await api.post(`/sales/${type}/${id}/void`);
      fetchHistory(); // Update the list
      if (onVoidSuccess) onVoidSuccess(); // Tell the parent to update the big totals
    } catch (err) {
      alert(err.response?.data?.message || 'Failed to void transaction');
    }
  };

  const formatDZD = (amount) => {
    return new Intl.NumberFormat('fr-DZ', { style: 'currency', currency: 'DZD' }).format(amount || 0);
  };

  const getIcon = (type) => {
    switch(type) {
      case 'sim': return <Smartphone size={16} className="text-red-500" />;
      case 'storm': return <Zap size={16} className="text-orange-500" />;
      case 'accessory': return <CreditCard size={16} className="text-blue-500" />;
      case 'debt': return <AlertTriangle size={16} className="text-gray-500" />;
      default: return <Clock size={16} />;
    }
  };

  if (isLoading) {
    return <div className="p-4 flex justify-center"><RefreshCw className="animate-spin text-gray-400" /></div>;
  }

  return (
    <div className="bg-white rounded-xl shadow-sm ring-1 ring-gray-200 flex flex-col h-full max-h-[400px]">
      <div className="bg-gray-50 px-4 py-3 border-b border-gray-200 flex justify-between items-center">
        <h3 className="font-semibold text-gray-900 flex items-center gap-2">
          <Clock size={18} className="text-gray-500" /> Recent Transactions
        </h3>
        <button onClick={fetchHistory} className="text-gray-500 hover:text-red-600">
          <RefreshCw size={16} />
        </button>
      </div>
      
      <div className="p-2 overflow-y-auto flex-1">
        {transactions.length === 0 ? (
          <p className="text-sm text-gray-500 text-center py-6">No transactions recorded yet.</p>
        ) : (
          <div className="space-y-2">
            {transactions.map((t) => (
              <div 
                key={`${t.type}-${t.id}`} 
                className={`flex items-center justify-between p-3 rounded-lg border ${t.is_voided ? 'bg-red-50/50 border-red-100 opacity-75' : 'bg-white border-gray-100 hover:bg-gray-50'}`}
              >
                <div className="flex items-center gap-3">
                  <div className={`p-2 rounded-full ${t.is_voided ? 'bg-red-100' : 'bg-gray-100'}`}>
                    {t.is_voided ? <Ban size={16} className="text-red-500" /> : getIcon(t.type)}
                  </div>
                  <div>
                    <p className={`text-sm font-medium ${t.is_voided ? 'text-gray-500 line-through' : 'text-gray-900'}`}>
                      {t.description}
                    </p>
                    <p className="text-xs text-gray-400">
                      {new Date(t.created_at).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}
                    </p>
                  </div>
                </div>
                
                <div className="flex items-center gap-4">
                  <span className={`font-semibold ${t.is_voided ? 'text-gray-400 line-through' : (t.type === 'debt' ? 'text-red-600' : 'text-green-600')}`}>
                    {t.type === 'debt' ? '-' : '+'}{formatDZD(t.amount)}
                  </span>
                  
                  {!t.is_voided ? (
                    <button 
                      onClick={() => handleVoid(t.type, t.id)}
                      className="text-xs font-medium text-red-600 hover:text-red-800 bg-red-50 px-2 py-1 rounded"
                    >
                      Void
                    </button>
                  ) : (
                    <span className="text-xs font-medium text-red-500 px-2 py-1 flex items-center gap-1">
                      Voided
                    </span>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}