import { Router } from 'express';
import { authenticateToken } from '../middleware/authMiddleware';
import { createSubscription, getSubscription, cancelSubscription } from '../controllers/subscriptionController';

const router = Router();

router.post('/create-subscription', authenticateToken, createSubscription);
router.get('/subscription', authenticateToken, getSubscription);
router.post('/cancel-subscription', authenticateToken, cancelSubscription);

export default router;
