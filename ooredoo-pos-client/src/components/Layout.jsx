import { Outlet, useNavigate, NavLink } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';
import {
  LogOut, UserCircle, LayoutDashboard, Users, UsersRound, Tags,
  PackagePlus, Package, MonitorDot, Wallet, FileText,
  HandCoins, Receipt, BarChart3,
} from 'lucide-react';
import OfflineBanner from './OfflineBanner';

export default function Layout() {
  const { user, isAdmin, isCashier, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = async () => {
    await logout();
    navigate('/login');
  };

  // Helper function to style active navigation links
  const navLinkClass = ({ isActive }) =>
    `flex items-center gap-2 px-4 py-3 text-sm font-medium transition-colors ${
      isActive 
        ? 'border-b-2 border-red-600 text-red-600 bg-red-50' 
        : 'text-gray-600 hover:text-red-600 hover:bg-gray-50'
    }`;

  return (
    <div className="min-h-screen bg-gray-100 flex flex-col">
      <OfflineBanner />
      {/* Top Header Bar */}
      <header className="bg-red-600 text-white shadow-md z-10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex h-16 items-center justify-between">
            
            {/* Brand Logo / Title */}
            <div className="flex items-center gap-2 font-extrabold tracking-wider text-xl">
              <div className="h-8 w-8 rounded-full bg-white flex items-center justify-center shadow-inner">
                <span className="text-red-600 text-lg">O</span>
              </div>
              <span>OOREDOO POS</span>
            </div>

            {/* User Info & Logout */}
            <div className="flex items-center gap-6">
              <div className="flex items-center gap-2 text-sm font-medium bg-red-700 px-3 py-1.5 rounded-full border border-red-500 shadow-sm">
                <UserCircle size={18} />
                <span>{user?.fullName}</span>
                <span className="bg-red-500 px-2 py-0.5 rounded text-xs uppercase tracking-wider ml-1 text-white">
                  {user?.role}
                </span>
              </div>
              
              <button
                onClick={handleLogout}
                className="flex items-center gap-2 text-sm font-semibold hover:text-red-200 transition-colors"
                title="Secure Logout"
              >
                <LogOut size={18} />
                <span className="hidden sm:inline">Logout</span>
              </button>
            </div>

          </div>
        </div>
      </header>

      {/* Navigation Tabs Menu */}
      <div className="bg-white border-b border-gray-200 shadow-sm sticky top-0 z-0">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <nav className="flex -mb-px overflow-x-auto">
            
            {/* Admin Links */}
            {isAdmin && (
              <>
                <NavLink to="/admin/dashboard" className={navLinkClass}>
                  <LayoutDashboard size={18} /> Overview
                </NavLink>
                <NavLink to="/admin/stock" className={navLinkClass}>
                  <PackagePlus size={18} /> Assign Stock
                </NavLink>
                <NavLink to="/admin/offers" className={navLinkClass}>
                  <Tags size={18} /> SIM Offers
                </NavLink>
                <NavLink to="/admin/products" className={navLinkClass}>
                  <Package size={18} /> Products
                </NavLink>
                <NavLink to="/admin/users" className={navLinkClass}>
                  <Users size={18} /> Manage Users
                </NavLink>
                <NavLink to="/admin/customers" className={navLinkClass}>
                  <UsersRound size={18} /> Customers
                </NavLink>
                <NavLink to="/admin/finances" className={navLinkClass}>
                    <Wallet size={18} /> Finances & Cash
                </NavLink>
                <NavLink to="/admin/advances" className={navLinkClass}>
                    <HandCoins size={18} /> Advances
                </NavLink>
                <NavLink to="/admin/expenses" className={navLinkClass}>
                    <Receipt size={18} /> Expenses
                </NavLink>
                <NavLink to="/admin/reports" end className={navLinkClass}>
                    <FileText size={18} /> Daily Reports
                </NavLink>
                <NavLink to="/admin/reports/range" className={navLinkClass}>
                    <BarChart3 size={18} /> Date Range Reports
                </NavLink>
              </>
            )}

            {/* Cashier Links */}
            {isCashier && (
              <>
                <NavLink to="/pos" className={navLinkClass}>
                  <MonitorDot size={18} /> POS Terminal
                </NavLink>
                {/* Additional cashier tabs like 'End Shift' could go here later */}
              </>
            )}

          </nav>
        </div>
      </div>

      {/* Main Page Content */}
      <main className="flex-1 max-w-7xl w-full mx-auto py-8 px-4 sm:px-6 lg:px-8">
        <Outlet />
      </main>
    </div>
  );
}