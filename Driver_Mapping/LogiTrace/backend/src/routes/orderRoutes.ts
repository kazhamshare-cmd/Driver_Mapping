/**
 * Order Routes - 受注管理API
 */

import { Router } from 'express';
import {
    getOrders,
    getUnassignedOrders,
    getOrderById,
    createOrder,
    updateOrder,
    cancelOrder,
    deleteOrder,
    getOrderStats
} from '../controllers/orderController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

router.get('/', authenticateToken, getOrders);
router.get('/unassigned', authenticateToken, getUnassignedOrders);
router.get('/stats', authenticateToken, getOrderStats);
router.get('/:id', authenticateToken, getOrderById);
router.post('/', authenticateToken, createOrder);
router.put('/:id', authenticateToken, updateOrder);
router.post('/:id/cancel', authenticateToken, cancelOrder);
router.delete('/:id', authenticateToken, deleteOrder);

export default router;
