import { Router } from 'express';
import {
    createTenko,
    getTenkoRecords,
    getTenkoById,
    getTodayTenkoStatus,
    getPendingTenko,
    updateTenko,
    deleteTenko
} from '../controllers/tenkoController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// すべてのエンドポイントで認証が必要
router.use(authenticateToken);

// 点呼記録一覧取得
router.get('/', getTenkoRecords);

// 点呼未完了ドライバー一覧
router.get('/pending', getPendingTenko);

// 本日の点呼状況（ドライバー別）
router.get('/today/:driverId', getTodayTenkoStatus);

// 点呼記録詳細
router.get('/:id', getTenkoById);

// 点呼記録作成
router.post('/', createTenko);

// 点呼記録更新（notesのみ）
router.put('/:id', updateTenko);

// 点呼記録削除（管理者のみ）
router.delete('/:id', deleteTenko);

export default router;
