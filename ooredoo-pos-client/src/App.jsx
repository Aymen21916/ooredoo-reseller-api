import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { ProtectedRoute } from './components/ProtectedRoute';
import Layout from './components/Layout';
import Login from './pages/Login';
import AdminDashboard from './pages/admin/AdminDashboard';
import ManageUsers from './pages/admin/ManageUsers';
import ManageOffers from './pages/admin/ManageOffers';
import AssignStock from './pages/admin/AssignStock';
import POSDashboard from './pages/cashier/POSDashboard';
import CashManagement from './pages/admin/CashManagement';
import DailyReports from './pages/admin/DailyReports';
import ManageProducts from './pages/admin/ManageProducts';
import ManageCustomers from './pages/admin/ManageCustomers';
import AdminAdvances from './pages/admin/AdminAdvances';
import AdminExpenses from './pages/admin/AdminExpenses';
import DateRangeReports from './pages/admin/DateRangeReports';
import CashierDateRangeReport from './pages/cashier/CashierDateRangeReport';


// Placeholder components
// const POSDashboard = () => <div className="rounded-lg bg-white p-10 shadow text-2xl">Cashier POS Interface (Coming Soon)</div>;
// const AdminDashboard = () => <div className="rounded-lg bg-white p-10 shadow text-2xl">Admin Dashboard (Coming Soon)</div>;

function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          {/* Public Route */}
          <Route path="/login" element={<Login />} />

          {/* Protected Routes (Wrapped in Layout) */}
          <Route element={<ProtectedRoute />}>
            <Route element={<Layout />}>
              
              {/* Cashier Routes */}
              <Route path="/pos" element={<POSDashboard />} />

              {/* Cashier-Only Routes (date-range report scoped to self) */}
              <Route element={<ProtectedRoute requireCashier={true} />}>
                <Route path="/cashier/reports/range" element={<CashierDateRangeReport />} />
              </Route>

              {/* Admin-Only Routes */}
              <Route element={<ProtectedRoute requireAdmin={true} />}>
                <Route path="/admin/dashboard" element={<AdminDashboard />} />
                <Route path="/admin/users" element={<ManageUsers />} />
                <Route path="/admin/customers" element={<ManageCustomers />} />
                <Route path="/admin/offers" element={<ManageOffers />} />
                <Route path="/admin/products" element={<ManageProducts />} />
                <Route path="/admin/stock" element={<AssignStock />} />
                <Route path="/admin/finances" element={<CashManagement />} />
                <Route path="/admin/advances" element={<AdminAdvances />} />
                <Route path="/admin/expenses" element={<AdminExpenses />} />
                <Route path="/admin/reports" element={<DailyReports />} />
                <Route path="/admin/reports/range" element={<DateRangeReports />} />
              </Route>

            </Route>
          </Route>

          {/* Catch-all redirect */}
          <Route path="*" element={<Navigate to="/login" replace />} />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  );
}

export default App;