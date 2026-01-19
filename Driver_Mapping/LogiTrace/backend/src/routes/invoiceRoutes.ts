/**
 * Invoice Routes - 請求書管理API
 */

import { Router } from 'express';
import {
    getInvoices,
    getInvoiceById,
    createInvoice,
    generateInvoiceFromDispatches,
    updateInvoiceStatus,
    deleteInvoice,
    getAccountsReceivable,
    getRevenueSummary,
    getFareMasters,
    createFareMaster,
    updateFareMaster,
    calculateFarePreview
} from '../controllers/invoiceController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// 請求書CRUD
router.get('/', authenticateToken, getInvoices);
router.get('/accounts-receivable', authenticateToken, getAccountsReceivable);
router.get('/revenue-summary', authenticateToken, getRevenueSummary);
router.get('/:id', authenticateToken, getInvoiceById);
router.post('/', authenticateToken, createInvoice);
router.post('/generate-from-dispatches', authenticateToken, generateInvoiceFromDispatches);
router.patch('/:id/status', authenticateToken, updateInvoiceStatus);
router.delete('/:id', authenticateToken, deleteInvoice);

// 運賃マスタ
router.get('/fare-masters', authenticateToken, getFareMasters);
router.post('/fare-masters', authenticateToken, createFareMaster);
router.put('/fare-masters/:id', authenticateToken, updateFareMaster);

// 運賃計算プレビュー
router.post('/calculate-fare', authenticateToken, calculateFarePreview);

export default router;
