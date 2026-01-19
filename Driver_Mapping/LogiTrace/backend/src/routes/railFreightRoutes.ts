/**
 * Rail Freight Routes
 * 通運事業API（JR貨物連携・コンテナ管理）
 */

import { Router } from 'express';
import {
    // コンテナ
    getContainers,
    getContainerById,
    createContainer,
    updateContainer,
    // 貨物駅
    getFreightStations,
    getFreightStationById,
    // 鉄道ルート
    getRailRoutes,
    // 鉄道予約
    getRailBookings,
    getRailBookingById,
    createRailBooking,
    updateRailBooking,
    // コンテナ追跡
    getContainerTracking,
    addContainerTracking,
    getCurrentContainerLocations,
    // 統計
    getRailStatistics
} from '../controllers/railFreightController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// すべてのエンドポイントで認証が必要
router.use(authenticateToken);

// ============================================
// コンテナ管理
// ============================================
router.get('/containers', getContainers);
router.get('/containers/locations', getCurrentContainerLocations);
router.get('/containers/:id', getContainerById);
router.post('/containers', createContainer);
router.put('/containers/:id', updateContainer);

// ============================================
// 貨物駅マスタ
// ============================================
router.get('/freight-stations', getFreightStations);
router.get('/freight-stations/:id', getFreightStationById);

// ============================================
// 鉄道輸送ルート
// ============================================
router.get('/rail-routes', getRailRoutes);

// ============================================
// 鉄道輸送予約
// ============================================
router.get('/rail-bookings', getRailBookings);
router.get('/rail-bookings/statistics', getRailStatistics);
router.get('/rail-bookings/:id', getRailBookingById);
router.post('/rail-bookings', createRailBooking);
router.put('/rail-bookings/:id', updateRailBooking);

// ============================================
// コンテナ追跡
// ============================================
router.get('/container-tracking', getContainerTracking);
router.post('/container-tracking', addContainerTracking);

export default router;
