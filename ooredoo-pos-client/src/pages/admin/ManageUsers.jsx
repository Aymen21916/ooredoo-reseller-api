import { useState, useEffect, useMemo } from 'react';
import api from '../../api/axios';
import { Users, Plus, Shield, User, Trash2, RotateCcw, Trash } from 'lucide-react';

export default function ManageUsers() {
  const [users, setUsers] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [showInactive, setShowInactive] = useState(false);

  // Form State
  const [isAdding, setIsAdding] = useState(false);
  const [formData, setFormData] = useState({
    username: '',
    password: '',
    full_name: '',
    role: 'cashier',
    store_id: '1',
  });

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    try {
      setIsLoading(true);
      const response = await api.get('/users');
      setUsers(response.data.data);
      setError('');
    } catch (err) {
      console.error('Failed to fetch users', err);
      setError('Failed to load users.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({
      ...prev,
      [name]: name === 'store_id' ? parseInt(value, 10) : value,
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const payload = { ...formData };
      if (payload.role === 'admin') delete payload.store_id;
      await api.post('/users', payload);
      setFormData({ username: '', password: '', full_name: '', role: 'cashier', store_id: '1' });
      setIsAdding(false);
      fetchUsers();
    } catch (err) {
      alert(err.response?.data?.message || 'Failed to create user');
    }
  };

  const handleDeactivate = async (id, username) => {
    if (!window.confirm(`Deactivate ${username}? They keep their history but can no longer log in.`)) return;
    try {
      await api.delete(`/users/${id}`);
      fetchUsers();
    } catch (err) {
      alert(err.response?.data?.message || 'Failed to deactivate user');
    }
  };

  const handleRestore = async (id, username) => {
    try {
      await api.post(`/users/${id}/restore`);
      fetchUsers();
    } catch (err) {
      alert(err.response?.data?.message || `Failed to restore ${username}`);
    }
  };

  const handlePermanentDelete = async (id, username) => {
    if (!window.confirm(
      `PERMANENTLY DELETE ${username}?\n\nThis cannot be undone. If the user has any historical sessions or sales, the deletion will fail and they must remain deactivated.`
    )) return;
    try {
      await api.delete(`/users/${id}/permanent`);
      fetchUsers();
    } catch (err) {
      alert(err.response?.data?.message || `Failed to delete ${username}`);
    }
  };

  const visibleUsers = useMemo(
    () => (showInactive ? users : users.filter((u) => u.is_active)),
    [users, showInactive]
  );

  const inactiveCount = users.filter((u) => !u.is_active).length;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-gray-200 pb-4">
        <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
          <Users className="text-red-600" /> Manage Users
        </h1>
        <button
          onClick={() => setIsAdding(!isAdding)}
          className="flex items-center gap-2 rounded-md bg-red-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-red-700"
        >
          <Plus size={16} /> {isAdding ? 'Cancel' : 'Add User'}
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
        Show inactive users
        {inactiveCount > 0 && (
          <span className="text-xs text-gray-500">({inactiveCount} hidden)</span>
        )}
      </label>

      {/* Add User Form */}
      {isAdding && (
        <div className="rounded-xl bg-white p-6 shadow-sm ring-1 ring-gray-200 mb-6">
          <h2 className="text-lg font-semibold mb-4">Create New Account</h2>
          <form onSubmit={handleSubmit} className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700">Full Name</label>
              <input required name="full_name" value={formData.full_name} onChange={handleInputChange} className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500 sm:text-sm" placeholder="e.g. Aymen" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">Username</label>
              <input required name="username" value={formData.username} onChange={handleInputChange} className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500 sm:text-sm" placeholder="aymen_sobha" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">Password</label>
              <input required type="password" name="password" value={formData.password} onChange={handleInputChange} className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500 sm:text-sm" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">Role</label>
              <select name="role" value={formData.role} onChange={handleInputChange} className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500 sm:text-sm">
                <option value="cashier">Cashier</option>
                <option value="admin">Admin</option>
              </select>
            </div>
            {formData.role === 'cashier' && (
              <div>
                <label className="block text-sm font-medium text-gray-700">Store Assignment</label>
                <select name="store_id" value={formData.store_id} onChange={handleInputChange} className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 focus:border-red-500 focus:ring-red-500 sm:text-sm">
                  <option value={1}>AAO Sobha</option>
                  <option value={2}>Kiosque Ain Meraine</option>
                </select>
              </div>
            )}
            <div className="md:col-span-2 flex justify-end mt-2">
              <button type="submit" className="rounded-md bg-green-600 px-6 py-2 text-sm font-semibold text-white shadow-sm hover:bg-green-700">
                Save User
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Users Table */}
      <div className="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-gray-200">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">User</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Role</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Store</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200 bg-white">
            {isLoading ? (
              <tr><td colSpan="5" className="px-6 py-4 text-center text-sm text-gray-500">Loading...</td></tr>
            ) : visibleUsers.length === 0 ? (
              <tr><td colSpan="5" className="px-6 py-4 text-center text-sm text-gray-500">
                {showInactive ? 'No users found.' : 'No active users. Toggle "Show inactive" to view deactivated accounts.'}
              </td></tr>
            ) : (
              visibleUsers.map((u) => (
                <tr key={u.id} className={!u.is_active ? 'bg-gray-50' : ''}>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center">
                      <div className="h-8 w-8 flex-shrink-0 rounded-full bg-gray-100 flex items-center justify-center">
                        {u.role === 'admin' ? <Shield size={16} className="text-red-600" /> : <User size={16} className="text-gray-500" />}
                      </div>
                      <div className="ml-4">
                        <div className="text-sm font-medium text-gray-900">{u.full_name}</div>
                        <div className="text-sm text-gray-500">@{u.username}</div>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`inline-flex rounded-full px-2 text-xs font-semibold leading-5 ${u.role === 'admin' ? 'bg-red-100 text-red-800' : 'bg-blue-100 text-blue-800'}`}>
                      {u.role}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{u.store_name || '-'}</td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    {u.is_active ? (
                      <span className="inline-flex rounded-full bg-green-100 px-2 text-xs font-semibold leading-5 text-green-800">Active</span>
                    ) : (
                      <span className="inline-flex rounded-full bg-gray-200 px-2 text-xs font-semibold leading-5 text-gray-700">Inactive</span>
                    )}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium space-x-3">
                    {u.is_active && u.role !== 'admin' && (
                      <button
                        onClick={() => handleDeactivate(u.id, u.username)}
                        className="text-red-600 hover:text-red-900 transition-colors"
                        title="Deactivate"
                      >
                        <Trash2 size={18} />
                      </button>
                    )}
                    {!u.is_active && (
                      <>
                        <button
                          onClick={() => handleRestore(u.id, u.username)}
                          className="text-green-600 hover:text-green-900 transition-colors"
                          title="Restore"
                        >
                          <RotateCcw size={18} />
                        </button>
                        <button
                          onClick={() => handlePermanentDelete(u.id, u.username)}
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
