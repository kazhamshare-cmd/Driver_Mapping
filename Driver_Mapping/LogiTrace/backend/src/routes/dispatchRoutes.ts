/**
 * Dispatch Routes - 配車割当API
 */

import { Router } from 'express';
import {
    getDispatches,
    getTodayDispatchSummary,
    getDriverSchedule,
    getVehicleSchedule,
    createDispatch,
    updateDispatch,
    startDispatch,
    completeDispatch,
    cancelDispatch,
    getSuggestions,
    getAvailableVehicles,
    getAvailableDrivers
} from '../controllers/dispatchController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// 配車一覧・サマリー
router.get('/', authenticateToken, getDispatches);
router.get('/summary/today', authenticateToken, getTodayDispatchSummary);
router.get('/schedule/drivers', authenticateToken, getDriverSchedule);
router.get('/schedule/vehicles', authenticateToken, getVehicleSchedule);

// 自動割当支援
router.get('/suggestions', authenticateToken, getSuggestions);
router.get('/available-vehicles', authenticateToken, getAvailableVehicles);
router.get('/available-drivers', authenticateToken, getAvailableDrivers);

// 配車CRUD
router.post('/', authenticateToken, createDispatch);
router.put('/:id', authenticateToken, updateDispatch);

// 配車ステータス変更
router.post('/:id/start', authenticateToken, startDispatch);
router.post('/:id/complete', authenticateToken, completeDispatch);
router.post('/:id/cancel', authenticateToken, cancelDispatch);

export default router;
