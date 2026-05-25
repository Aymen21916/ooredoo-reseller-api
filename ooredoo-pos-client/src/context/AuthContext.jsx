import React, { createContext, useState, useEffect } from 'react';
import api from '../api/axios';

// 1. Create the Context (the "empty box" that will hold our data)
export const AuthContext = createContext(null);

// 2. Create the Provider (the component that wraps our app and fills the box)
export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [isLoading, setIsLoading] = useState(true);

  // When the app first loads, check if we have a user saved in local storage
  useEffect(() => {
    const storedUser = localStorage.getItem('user');
    if (storedUser) {
      setUser(JSON.parse(storedUser));
    }
    setIsLoading(false);
  }, []);

  // The Login Action
  const login = async (username, password) => {
    try {
      const response = await api.post('/auth/login', { username, password });
      const { accessToken, refreshToken, user: userData } = response.data.data;

      // Save to browser memory so they stay logged in if they refresh the page
      localStorage.setItem('accessToken', accessToken);
      localStorage.setItem('refreshToken', refreshToken);
      localStorage.setItem('user', JSON.stringify(userData));

      // Update React state
      setUser(userData);
      return { success: true };
    } catch (error) {
      // Return the error message from the backend (e.g., "Invalid Credentials")
      return { 
        success: false, 
        message: error.response?.data?.message || 'Login failed' 
      };
    }
  };

  // The Logout Action
  const logout = async () => {
    try {
      const refreshToken = localStorage.getItem('refreshToken');
      if (refreshToken) {
        // Tell the backend to revoke the token
        await api.post('/auth/logout', { refreshToken });
      }
    } catch (error) {
      console.error('Logout error:', error);
    } finally {
      // Regardless of backend success, wipe the local memory
      localStorage.removeItem('accessToken');
      localStorage.removeItem('refreshToken');
      localStorage.removeItem('user');
      setUser(null);
    }
  };

  // Bundle everything up to share with the rest of the app
  const value = {
    user,
    isAuthenticated: !!user, // true if user exists, false if null
    isAdmin: user?.role === 'admin',
    isCashier: user?.role === 'cashier',
    login,
    logout,
    isLoading
  };

  return (
    <AuthContext.Provider value={value}>
      {!isLoading && children}
    </AuthContext.Provider>
  );
};