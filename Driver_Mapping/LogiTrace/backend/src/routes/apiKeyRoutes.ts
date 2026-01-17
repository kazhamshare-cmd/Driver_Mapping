import express from 'express';
import { authenticateToken } from '../middleware/authMiddleware';
import {
    getApiKeys,
    createApiKey,
    updateApiKey,
    deleteApiKey,
    regenerateApiKey,
    getApiUsageStats,
    getWebhooks,
    createWebhook,
    updateWebhook,
    deleteWebhook,
    testWebhook
} from '../controllers/apiKeyController';

const router = express.Router();

// All routes require authentication
router.use(authenticateToken);

// API Keys Management
router.get('/keys', getApiKeys);
router.post('/keys', createApiKey);
router.put('/keys/:id', updateApiKey);
router.delete('/keys/:id', deleteApiKey);
router.post('/keys/:id/regenerate', regenerateApiKey);

// Usage Statistics
router.get('/usage', getApiUsageStats);

// Webhooks Management
router.get('/webhooks', getWebhooks);
router.post('/webhooks', createWebhook);
router.put('/webhooks/:id', updateWebhook);
router.delete('/webhooks/:id', deleteWebhook);
router.post('/webhooks/:id/test', testWebhook);

export default router;
