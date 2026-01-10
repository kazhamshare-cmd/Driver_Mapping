import { Router } from 'express';
import { authenticateToken } from '../middleware/authMiddleware';
import { createSubscription } from '../controllers/billingController';

const router = Router();

router.post('/create-subscription', authenticateToken, createSubscription);

export default router;
