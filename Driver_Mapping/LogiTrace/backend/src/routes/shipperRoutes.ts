/**
 * Shipper Routes - 荷主マスタAPI
 */

import { Router } from 'express';
import {
    getShippers,
    getShipperById,
    createShipper,
    updateShipper,
    deleteShipper
} from '../controllers/shipperController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

router.get('/', authenticateToken, getShippers);
router.get('/:id', authenticateToken, getShipperById);
router.post('/', authenticateToken, createShipper);
router.put('/:id', authenticateToken, updateShipper);
router.delete('/:id', authenticateToken, deleteShipper);

export default router;
