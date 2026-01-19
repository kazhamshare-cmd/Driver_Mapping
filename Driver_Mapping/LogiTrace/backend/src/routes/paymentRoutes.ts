/**
 * Payment Routes - 入金管理API
 */

import { Router } from 'express';
import {
    getPayments,
    createPayment,
    matchPaymentToInvoice,
    unmatchPayment,
    deletePayment,
    getUnmatchedPayments,
    getPaymentSummary,
    getMatchingSuggestions
} from '../controllers/paymentController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// 入金CRUD
router.get('/', authenticateToken, getPayments);
router.get('/unmatched', authenticateToken, getUnmatchedPayments);
router.get('/summary', authenticateToken, getPaymentSummary);
router.get('/:id/suggestions', authenticateToken, getMatchingSuggestions);
router.post('/', authenticateToken, createPayment);
router.post('/:id/match', authenticateToken, matchPaymentToInvoice);
router.post('/:id/unmatch', authenticateToken, unmatchPayment);
router.delete('/:id', authenticateToken, deletePayment);

export default router;
