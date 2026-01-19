import { Router } from 'express';
import {
    getConfirmationHistory,
    approveWithSignature,
    bulkApproveWithSignature,
    getManagerSignature,
    rejectWithReason,
    requestCorrection,
    getDailyApprovalSummary
} from '../controllers/managerConfirmationController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// 確認履歴を取得
router.get('/history/:work_record_id', authenticateToken, getConfirmationHistory);

// 運行管理者の保存済み署名を取得
router.get('/my-signature', authenticateToken, getManagerSignature);

// 日次承認サマリー
router.get('/summary/daily', authenticateToken, getDailyApprovalSummary);

// 電子署名付きで承認
router.post('/:work_record_id/approve', authenticateToken, approveWithSignature);

// 一括電子署名承認
router.post('/bulk-approve', authenticateToken, bulkApproveWithSignature);

// 差戻し
router.post('/:work_record_id/reject', authenticateToken, rejectWithReason);

// 修正依頼
router.post('/:work_record_id/request-correction', authenticateToken, requestCorrection);

export default router;
