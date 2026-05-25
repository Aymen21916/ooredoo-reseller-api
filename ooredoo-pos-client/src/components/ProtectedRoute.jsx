import { Navigate, Outlet } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';

export const ProtectedRoute = ({ requireAdmin = false, requireCashier = false }) => {
  const { isAuthenticated, isAdmin, isLoading } = useAuth();

  // Show a simple loading state while checking local storage
  if (isLoading) {
    return (
      <div className="flex h-screen items-center justify-center bg-gray-50">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-red-600 border-t-transparent"></div>
      </div>
    );
  }

  // If they are not logged in, send them to the login page
  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  // If the route requires admin rights, but the user is a cashier, block them
  // Send them to their POS screen instead
  if (requireAdmin && !isAdmin) {
    return <Navigate to="/pos" replace />;
  }

  // If the route requires cashier rights, but the user is an admin, send them
  // to the admin dashboard instead.
  if (requireCashier && isAdmin) {
    return <Navigate to="/admin/dashboard" replace />;
  }

  // If everything is good, render the child routes (the Outlet)
  return <Outlet />;
};