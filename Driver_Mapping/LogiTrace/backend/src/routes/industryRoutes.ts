import { Router } from 'express';
import {
    getIndustryTypes,
    getVehicleTypesByIndustry,
    getAllVehicleTypes,
    updateCompanyIndustry,
    getCompanyWithIndustry,
    getOperationTypesByIndustry,
    getFieldConfigByIndustry,
    getCompanyDrivers
} from '../controllers/industryController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// すべてのエンドポイントで認証が必要
router.use(authenticateToken);

// 業種一覧取得
router.get('/', getIndustryTypes);

// 全車両タイプ取得
router.get('/vehicle-types', getAllVehicleTypes);

// 業種別車両タイプ取得
router.get('/:industryCode/vehicle-types', getVehicleTypesByIndustry);

// 業種別運行種別マスタ取得
router.get('/:industryCode/operation-types', getOperationTypesByIndustry);

// 業種別フィールド設定取得
router.get('/:industryCode/field-config', getFieldConfigByIndustry);

// 会社情報取得（業種含む）
router.get('/company/:companyId', getCompanyWithIndustry);

// 会社のドライバー一覧取得（交替運転者選択用）
router.get('/company/:companyId/drivers', getCompanyDrivers);

// 会社の業種設定
router.put('/company/:companyId', updateCompanyIndustry);

export default router;
