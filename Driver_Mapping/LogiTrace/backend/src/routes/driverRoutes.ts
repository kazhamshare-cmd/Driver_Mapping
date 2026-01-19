import { Router } from 'express';
import {
    getDrivers,
    getDriverUsage,
    createDriver,
    createInvite,
    setupDriverPassword,
    registerByCompanyCode,
    updateDriver,
    deleteDriver,
    resetDriverPassword,
    getCompanyInfo
} from '../controllers/driverController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// 認証が必要なエンドポイント
router.get('/', authenticateToken, getDrivers);
router.get('/usage', authenticateToken, getDriverUsage);
router.post('/', authenticateToken, createDriver);
router.post('/invite', authenticateToken, createInvite);
router.put('/:id', authenticateToken, updateDriver);
router.delete('/:id', authenticateToken, deleteDriver);
router.post('/:id/reset-password', authenticateToken, resetDriverPassword);
router.get('/company/:companyId', authenticateToken, getCompanyInfo);

// 認証不要なエンドポイント（ドライバー自己登録用）
router.post('/register-by-code', registerByCompanyCode);
router.post('/setup-password', setupDriverPassword);

export default router;
