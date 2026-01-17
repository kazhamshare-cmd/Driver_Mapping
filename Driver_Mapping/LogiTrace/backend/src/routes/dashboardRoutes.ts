import { Router } from 'express';
import {
    getDashboardSummary,
    getRecentActivities,
    getVehicleStatus
} from '../controllers/dashboardController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

router.get('/summary', authenticateToken, getDashboardSummary);
router.get('/recent-activities', authenticateToken, getRecentActivities);
router.get('/vehicle-status', authenticateToken, getVehicleStatus);

export default router;
