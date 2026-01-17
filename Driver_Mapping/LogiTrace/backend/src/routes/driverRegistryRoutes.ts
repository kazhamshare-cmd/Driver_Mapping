import { Router } from 'express';
import {
    getDriverRegistries,
    getDriverRegistryById,
    getDriverRegistryByDriverId,
    getMyDriverRegistry,
    createDriverRegistry,
    updateDriverRegistry,
    deleteDriverRegistry,
    getExpiringLicenses,
    checkDriverCompliance
} from '../controllers/driverRegistryController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// すべてのエンドポイントで認証が必要
router.use(authenticateToken);

// 運転者台帳一覧取得
router.get('/', getDriverRegistries);

// 自分の運転者台帳取得（モバイルアプリ用）
router.get('/me', getMyDriverRegistry);

// 期限切れ間近の免許一覧
router.get('/expiring', getExpiringLicenses);

// ドライバーのコンプライアンス状況チェック（点呼時使用）
router.get('/compliance/:driverId', checkDriverCompliance);

// ドライバーIDで運転者台帳取得
router.get('/driver/:driverId', getDriverRegistryByDriverId);

// 運転者台帳詳細取得
router.get('/:id', getDriverRegistryById);

// 運転者台帳作成
router.post('/', createDriverRegistry);

// 運転者台帳更新
router.put('/:id', updateDriverRegistry);

// 運転者台帳削除
router.delete('/:id', deleteDriverRegistry);

export default router;
