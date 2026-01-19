/**
 * Analytics Routes - 経営分析・原価管理API
 */

import { Router } from 'express';
import {
    getMonthlySummary,
    recalculateMonthlySummary,
    getBreakevenAnalysis,
    getVehicleProfit,
    getDriverProfit,
    getShipperProfit,
    getUtilization,
    getVehicleCosts,
    upsertVehicleCost,
    getDriverCosts,
    upsertDriverCost,
    getFixedCosts,
    upsertFixedCost,
    getDashboardData
} from '../controllers/analyticsController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// 経営ダッシュボード
router.get('/dashboard', authenticateToken, getDashboardData);

// 月次サマリー
router.get('/monthly-summary', authenticateToken, getMonthlySummary);
router.post('/monthly-summary/recalculate', authenticateToken, recalculateMonthlySummary);

// 損益分岐点分析
router.get('/breakeven', authenticateToken, getBreakevenAnalysis);

// 車両別・ドライバー別・荷主別損益
router.get('/profit/vehicles', authenticateToken, getVehicleProfit);
router.get('/profit/drivers', authenticateToken, getDriverProfit);
router.get('/profit/shippers', authenticateToken, getShipperProfit);

// 稼働率
router.get('/utilization', authenticateToken, getUtilization);

// 車両コスト管理
router.get('/costs/vehicles', authenticateToken, getVehicleCosts);
router.post('/costs/vehicles', authenticateToken, upsertVehicleCost);

// ドライバーコスト管理
router.get('/costs/drivers', authenticateToken, getDriverCosts);
router.post('/costs/drivers', authenticateToken, upsertDriverCost);

// 会社固定費管理
router.get('/costs/fixed', authenticateToken, getFixedCosts);
router.post('/costs/fixed', authenticateToken, upsertFixedCost);

export default router;
