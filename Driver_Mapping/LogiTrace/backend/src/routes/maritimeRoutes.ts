/**
 * Maritime Transport Routes
 * 海上輸送連携API（RORO船・フェリー・港湾作業）
 */

import { Router } from 'express';
import {
    // 港湾
    getPorts,
    getPortById,
    // フェリー航路
    getFerryRoutes,
    // フェリースケジュール
    getFerrySchedules,
    createFerrySchedule,
    updateFerrySchedule,
    // フェリー予約
    getFerryBookings,
    createFerryBooking,
    updateFerryBooking,
    cancelFerryBooking,
    // 港湾作業
    getPortOperations,
    createPortOperation,
    updatePortOperation,
    getPortStatistics
} from '../controllers/maritimeController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// すべてのエンドポイントで認証が必要
router.use(authenticateToken);

// ============================================
// 港湾マスタ
// ============================================
router.get('/ports', getPorts);
router.get('/ports/:id', getPortById);

// ============================================
// フェリー航路
// ============================================
router.get('/ferry-routes', getFerryRoutes);

// ============================================
// フェリースケジュール
// ============================================
router.get('/ferry-schedules', getFerrySchedules);
router.post('/ferry-schedules', createFerrySchedule);
router.put('/ferry-schedules/:id', updateFerrySchedule);

// ============================================
// フェリー予約
// ============================================
router.get('/ferry-bookings', getFerryBookings);
router.post('/ferry-bookings', createFerryBooking);
router.put('/ferry-bookings/:id', updateFerryBooking);
router.delete('/ferry-bookings/:id', cancelFerryBooking);

// ============================================
// 港湾作業
// ============================================
router.get('/port-operations', getPortOperations);
router.get('/port-operations/statistics', getPortStatistics);
router.post('/port-operations', createPortOperation);
router.put('/port-operations/:id', updatePortOperation);

export default router;
