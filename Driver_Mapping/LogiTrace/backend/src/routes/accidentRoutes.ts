import { Router } from 'express';
import {
    getAccidentRecords,
    getAccidentById,
    createAccident,
    updateAccident,
    deleteAccident,
    getAccidentStatistics,
    getDriverAccidentHistory,
    getFollowUpRequired
} from '../controllers/accidentController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// すべてのエンドポイントで認証が必要
router.use(authenticateToken);

// 事故・違反記録一覧取得
router.get('/', getAccidentRecords);

// 統計情報取得
router.get('/statistics', getAccidentStatistics);

// フォローアップ研修が必要なドライバー一覧
router.get('/follow-up-required', getFollowUpRequired);

// ドライバーの事故・違反履歴
router.get('/driver/:driverId/history', getDriverAccidentHistory);

// 事故・違反記録詳細取得
router.get('/:id', getAccidentById);

// 事故・違反記録作成
router.post('/', createAccident);

// 事故・違反記録更新
router.put('/:id', updateAccident);

// 事故・違反記録削除
router.delete('/:id', deleteAccident);

export default router;
