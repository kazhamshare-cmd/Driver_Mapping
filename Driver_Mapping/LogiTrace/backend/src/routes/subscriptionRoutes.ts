import { Router } from 'express';
import { authenticateToken } from '../middleware/authMiddleware';
import { createSubscription, createSetupIntent } from '../controllers/subscriptionController';

const router = Router();

// Setup Intent - No auth required (called before user registration)
router.post('/create-setup-intent', createSetupIntent);

// Create Subscription - Auth required
router.post('/create-subscription', authenticateToken, createSubscription);

export default router;
