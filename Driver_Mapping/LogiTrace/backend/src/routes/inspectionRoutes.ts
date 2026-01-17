import { Router } from 'express';
import {
    createInspection,
    getInspections,
    getInspectionById,
    getInspectionItems,
    getLatestInspectionByVehicle,
    getTodayInspectedVehicles,
    updateInspection,
    getFollowUpRequired
} from '../controllers/inspectionController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// すべてのエンドポイントで認証が必要
router.use(authenticateToken);

// 点検項目マスタ取得
router.get('/items', getInspectionItems);

// 今日の点検済み車両
router.get('/today', getTodayInspectedVehicles);

// フォローアップ必要な点検一覧
router.get('/follow-up', getFollowUpRequired);

// 点検記録一覧
router.get('/', getInspections);

// 車両の最新点検
router.get('/vehicle/:vehicleId/latest', getLatestInspectionByVehicle);

// 点検記録詳細
router.get('/:id', getInspectionById);

// 点検記録作成
router.post('/', createInspection);

// 点検記録更新
router.put('/:id', updateInspection);

export default router;
