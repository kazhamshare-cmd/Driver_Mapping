import { Router } from 'express';
import {
    getTrainingRecords,
    getTrainingById,
    createTraining,
    updateTraining,
    deleteTraining,
    getTrainingTypes,
    getScheduledTrainings,
    getDriverTrainingHistory,
    getTrainingStatistics
} from '../controllers/trainingController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// すべてのエンドポイントで認証が必要
router.use(authenticateToken);

// 研修種別マスタ取得
router.get('/types', getTrainingTypes);

// 研修記録一覧取得
router.get('/', getTrainingRecords);

// 予定一覧（未完了の研修）
router.get('/scheduled', getScheduledTrainings);

// 研修統計
router.get('/statistics', getTrainingStatistics);

// ドライバーの研修履歴
router.get('/driver/:driverId/history', getDriverTrainingHistory);

// 研修記録詳細取得
router.get('/:id', getTrainingById);

// 研修記録作成
router.post('/', createTraining);

// 研修記録更新
router.put('/:id', updateTraining);

// 研修記録削除
router.delete('/:id', deleteTraining);

export default router;
