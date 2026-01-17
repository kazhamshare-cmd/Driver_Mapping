import { Router } from 'express';
import {
    getAptitudeTests,
    getAptitudeTestById,
    createAptitudeTest,
    updateAptitudeTest,
    deleteAptitudeTest,
    getTestsRequired,
    getDriverAptitudeHistory
} from '../controllers/aptitudeTestController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// すべてのエンドポイントで認証が必要
router.use(authenticateToken);

// 適性診断記録一覧取得
router.get('/', getAptitudeTests);

// 要受診者一覧
router.get('/required', getTestsRequired);

// ドライバーの適性診断履歴
router.get('/driver/:driverId/history', getDriverAptitudeHistory);

// 適性診断記録詳細取得
router.get('/:id', getAptitudeTestById);

// 適性診断記録作成
router.post('/', createAptitudeTest);

// 適性診断記録更新
router.put('/:id', updateAptitudeTest);

// 適性診断記録削除
router.delete('/:id', deleteAptitudeTest);

export default router;
