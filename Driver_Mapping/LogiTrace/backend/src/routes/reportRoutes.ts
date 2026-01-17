import { Router } from 'express';
import { authenticateToken } from '../middleware/authMiddleware';
import { getReportSummary, getYearlyReport, generateReportPDF } from '../controllers/reportController';

const router = Router();

// Get report summary for a date range (monthly)
router.get('/summary', authenticateToken, getReportSummary);

// Get yearly report with monthly breakdown
router.get('/yearly', authenticateToken, getYearlyReport);

// Generate PDF report
router.get('/pdf', authenticateToken, generateReportPDF);

export default router;
