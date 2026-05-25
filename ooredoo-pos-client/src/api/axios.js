import axios from 'axios';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3001/api';

// Create a base instance pointing to your Node.js server
const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// ─── REQUEST INTERCEPTOR ────────────────────────────────────────────────
// Before ANY request leaves the browser, this function runs.
api.interceptors.request.use(
  (config) => {
    // Short-circuit if the browser reports no network — avoids a long timeout
    if (typeof navigator !== 'undefined' && navigator.onLine === false) {
      const err = new Error('You are offline. Please check your connection.');
      err.code = 'OFFLINE';
      return Promise.reject(err);
    }

    // Grab the token from the browser's local storage
    const token = localStorage.getItem('accessToken');
    if (token) {
      // Attach it to the Authorization header just like we did in Postman
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// ─── RESPONSE INTERCEPTOR ───────────────────────────────────────────────
// When the backend responds, this function runs. It looks for 401 Unauthorized errors.
api.interceptors.response.use(
  (response) => response, // If it's a success, just pass it through.
  async (error) => {
    const originalRequest = error.config;

    // If the error is 401 (token expired) and we haven't already tried to retry this request:
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;

      try {
        const refreshToken = localStorage.getItem('refreshToken');
        if (!refreshToken) throw new Error('No refresh token available');

        // Ask the backend for a fresh pair of tokens
        const { data } = await axios.post(`${API_URL}/auth/refresh`, {
          refreshToken,
        });

        // Save the new tokens
        localStorage.setItem('accessToken', data.data.accessToken);
        localStorage.setItem('refreshToken', data.data.refreshToken);

        // Update the failed request with the new token and try it again!
        originalRequest.headers.Authorization = `Bearer ${data.data.accessToken}`;
        return api(originalRequest);
        
      } catch (refreshError) {
        // If the refresh token is ALSO expired, force a hard logout
        localStorage.removeItem('accessToken');
        localStorage.removeItem('refreshToken');
        localStorage.removeItem('user');
        window.location.href = '/login'; // Kick them to the login screen
        return Promise.reject(refreshError);
      }
    }

    return Promise.reject(error);
  }
);

export default api;