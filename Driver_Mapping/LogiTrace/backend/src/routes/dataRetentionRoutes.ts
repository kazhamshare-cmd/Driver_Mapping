import { Router } from 'express';
import { authenticateToken } from '../middleware/authMiddleware';
import {
    getStatus,
    runCleanup,
    cleanupCompany,
    getRetentionInfo
} from '../controllers/dataRetentionController';

const router = Router();

// 保存期間情報を取得
router.get('/info', getRetentionInfo);

// 自社のデータ保存状況を取得
router.get('/status', authenticateToken, getStatus);

// 全社のデータクリーンアップ実行（管理者用）
router.post('/cleanup', authenticateToken, runCleanup);

// 特定会社のデータクリーンアップ実行（管理者用）
router.post('/cleanup/:companyId', authenticateToken, cleanupCompany);

export default router;
