/**
 * Tachograph Integration Routes
 * デジタコ連携管理API
 */

import { Router } from 'express';
import {
    getProviders,
    getIntegrations,
    getIntegrationById,
    createIntegration,
    updateIntegration,
    testConnection,
    triggerSync,
    getDriverMappings,
    updateDriverMapping,
    getVehicleMappings,
    updateVehicleMapping,
    getSyncLogs,
    getDrivingEvaluations,
    getVehicleLocationHistory,
    getCurrentVehicleLocations
} from '../controllers/tachographIntegrationController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// すべてのエンドポイントで認証が必要
router.use(authenticateToken);

// プロバイダー一覧
router.get('/providers', getProviders);

// 連携設定CRUD
router.get('/integrations', getIntegrations);
router.get('/integrations/:id', getIntegrationById);
router.post('/integrations', createIntegration);
router.put('/integrations/:id', updateIntegration);

// 接続テスト
router.post('/integrations/:id/test', testConnection);

// 手動同期
router.post('/integrations/:id/sync', triggerSync);

// ドライバーマッピング
router.get('/integrations/:integrationId/driver-mappings', getDriverMappings);
router.put('/integrations/:integrationId/driver-mappings/:mappingId', updateDriverMapping);

// 車両マッピング
router.get('/integrations/:integrationId/vehicle-mappings', getVehicleMappings);
router.put('/integrations/:integrationId/vehicle-mappings/:mappingId', updateVehicleMapping);

// 同期ログ
router.get('/integrations/:integrationId/sync-logs', getSyncLogs);

// 運転評価データ
router.get('/evaluations', getDrivingEvaluations);

// 位置情報
router.get('/locations/history', getVehicleLocationHistory);
router.get('/locations/current', getCurrentVehicleLocations);

export default router;
