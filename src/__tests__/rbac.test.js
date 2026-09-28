const request = require('supertest');
const express = require('express');
const { authorize } = require('../middleware/authorize');

// Mock a simple Express app to test the middleware
const app = express();
app.use(express.json());

// Mock route protected by 'admin' role
app.post('/api/secure-admin-route', 
  (req, res, next) => {
    // Simulate an authenticated cashier trying to access it
    req.user = { id: 2, role: 'cashier' }; 
    next();
  }, 
  authorize('admin'), 
  (req, res) => res.status(200).json({ success: true })
);

describe('Role-Based Access Control (RBAC) Security', () => {
  it('MUST block Cashiers from accessing Admin routes with 403 Forbidden', async () => {
    const response = await request(app).post('/api/secure-admin-route');
    expect(response.status).toBe(403);
    expect(response.body.message).toMatch(/Forbidden/i);
  });
});