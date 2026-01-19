/**
 * Trailer Management Routes
 * トレーラー管理API（トラクタヘッド・シャーシ）
 */

import { Router } from 'express';
import {
    // トラクタヘッド
    getTractorHeads,
    getTractorHeadById,
    createTractorHead,
    updateTractorHead,
    // シャーシ
    getChassis,
    getChassisById,
    createChassis,
    updateChassis,
    getAvailableChassis,
    // 連結記録
    getCouplingRecords,
    coupleTrailerChassis,
    uncoupleTrailerChassis,
    // シャーシスケジュール
    getChassisSchedules,
    createChassisSchedule,
    updateChassisSchedule,
    getChassisGanttData
} from '../controllers/trailerController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// すべてのエンドポイントで認証が必要
router.use(authenticateToken);

// ============================================
// トラクタヘッド
// ============================================
router.get('/tractors', getTractorHeads);
router.get('/tractors/:id', getTractorHeadById);
router.post('/tractors', createTractorHead);
router.put('/tractors/:id', updateTractorHead);

// ============================================
// シャーシ
// ============================================
router.get('/chassis', getChassis);
router.get('/chassis/available', getAvailableChassis);
router.get('/chassis/:id', getChassisById);
router.post('/chassis', createChassis);
router.put('/chassis/:id', updateChassis);

// ============================================
// 連結・連結解除
// ============================================
router.get('/coupling-records', getCouplingRecords);
router.post('/couple', coupleTrailerChassis);
router.post('/uncouple', uncoupleTrailerChassis);

// ============================================
// シャーシスケジュール
// ============================================
router.get('/schedules', getChassisSchedules);
router.get('/schedules/gantt', getChassisGanttData);
router.post('/schedules', createChassisSchedule);
router.put('/schedules/:id', updateChassisSchedule);

export default router;
