import { Router } from 'express';
import {
    getBreakRecords,
    detectBreaks,
    addBreakRecord,
    updateBreakRecord,
    deleteBreakRecord
} from '../controllers/breakRecordController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// 休憩記録一覧
router.get('/work-record/:work_record_id', authenticateToken, getBreakRecords);

// 休憩自動検出（手動トリガー）
router.post('/work-record/:work_record_id/detect', authenticateToken, detectBreaks);

// 休憩記録を手動追加
router.post('/work-record/:work_record_id', authenticateToken, addBreakRecord);

// 休憩記録を更新
router.put('/:id', authenticateToken, updateBreakRecord);

// 休憩記録を削除
router.delete('/:id', authenticateToken, deleteBreakRecord);

export default router;
