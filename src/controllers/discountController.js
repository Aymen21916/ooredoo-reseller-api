'use strict';
const { asyncHandler, sendSuccess, sendCreated } = require('../utils/asyncHandler');

// In-memory store for real-time requests (clears automatically on server restart)
const requestsStore = new Map();

const requestDiscount = asyncHandler(async (req, res) => {
    // Generate a quick unique ID
    const id = Date.now().toString() + Math.floor(Math.random() * 1000).toString();
    const requestData = {
        id,
        cashier_id: req.user.id,
        cashier_name: req.user.full_name || req.user.fullName || 'Cashier',
        product_name: req.body.product_name,
        price: req.body.price,
        status: 'pending',
        created_at: Date.now()
    };
    requestsStore.set(id, requestData);
    sendCreated(res, requestData, 'Discount requested');
});

const getPendingRequests = asyncHandler(async (req, res) => {
    // Auto-cleanup stale requests older than 30 minutes
    const expirationTime = Date.now() - (30 * 60 * 1000); 
    const pending = [];
    
    for (const [id, data] of requestsStore.entries()) {
        if (data.created_at < expirationTime) {
            requestsStore.delete(id);
        } else if (data.status === 'pending') {
            pending.push(data);
        }
    }
    sendSuccess(res, pending);
});

const getRequestStatus = asyncHandler(async (req, res) => {
    const data = requestsStore.get(req.params.id);
    if (!data) return res.status(404).json({ message: 'Request expired or not found' });
    sendSuccess(res, data);
});

const resolveRequest = asyncHandler(async (req, res) => {
    const { status } = req.body; // 'approved' or 'rejected'
    const data = requestsStore.get(req.params.id);
    if (!data) return res.status(404).json({ message: 'Request expired or not found' });
    
    data.status = status;
    data.resolved_by = req.user.id;
    requestsStore.set(req.params.id, data);
    
    sendSuccess(res, data);
});

module.exports = { requestDiscount, getPendingRequests, getRequestStatus, resolveRequest };