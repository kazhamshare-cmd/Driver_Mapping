import { Router } from 'express';
import {
    getHealthCheckups,
    getHealthCheckupById,
    createHealthCheckup,
    updateHealthCheckup,
    deleteHealthCheckup,
    getCheckupsDue,
    getDriverHealthHistory
} from '../controllers/healthCheckupController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// すべてのエンドポイントで認証が必要
router.use(authenticateToken);

// 健康診断記録一覧取得
router.get('/', getHealthCheckups);

// 受診期限が近いドライバー一覧
router.get('/due', getCheckupsDue);

// ドライバーの健康診断履歴
router.get('/driver/:driverId/history', getDriverHealthHistory);

// 健康診断記録詳細取得
router.get('/:id', getHealthCheckupById);

// 健康診断記録作成
router.post('/', createHealthCheckup);

// 健康診断記録更新
router.put('/:id', updateHealthCheckup);

// 健康診断記録削除
router.delete('/:id', deleteHealthCheckup);

export default router;
