/**
 * Labor Compliance Routes - 労務コンプライアンスAPI
 */

import { Router } from 'express';
import {
    getAlerts,
    getUnacknowledgedCount,
    acknowledgeAlert,
    bulkAcknowledgeAlerts,
    getSettings,
    updateSettings,
    getDriverMonthlySummary,
    getCompanyMonthlyStats,
    processWorkRecord,
    getDriverCurrentStatus,
    getDriverComplianceDetail
} from '../controllers/laborComplianceController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// アラート関連
router.get('/alerts', authenticateToken, getAlerts);
router.get('/alerts/unacknowledged-count', authenticateToken, getUnacknowledgedCount);
router.post('/alerts/:id/acknowledge', authenticateToken, acknowledgeAlert);
router.post('/alerts/bulk-acknowledge', authenticateToken, bulkAcknowledgeAlerts);

// 設定
router.get('/settings', authenticateToken, getSettings);
router.put('/settings', authenticateToken, updateSettings);

// 統計・サマリー
router.get('/driver-summary', authenticateToken, getDriverMonthlySummary);
router.get('/company-stats', authenticateToken, getCompanyMonthlyStats);

// リアルタイム監視
router.get('/driver-status', authenticateToken, getDriverCurrentStatus);
router.get('/driver/:driver_id/detail', authenticateToken, getDriverComplianceDetail);

// 手動チェック実行
router.post('/process-record', authenticateToken, processWorkRecord);

export default router;
