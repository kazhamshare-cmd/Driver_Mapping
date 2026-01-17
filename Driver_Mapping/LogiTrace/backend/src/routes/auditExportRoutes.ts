import { Router } from 'express';
import {
    createAuditExport,
    getExportHistory,
    getExportById,
    downloadExport,
    deleteExport,
    getAuditSummary,
    downloadDriverRegistryPDF,
    downloadDriverRegistryListPDF,
    downloadComplianceSummaryPDF
} from '../controllers/auditExportController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// すべてのエンドポイントで認証が必要
router.use(authenticateToken);

// 監査データサマリー（プレビュー用）
router.get('/summary', getAuditSummary);

// 出力履歴
router.get('/exports', getExportHistory);

// 出力詳細・ステータス
router.get('/exports/:id', getExportById);

// PDFダウンロード
router.get('/exports/:id/download', downloadExport);

// PDF出力開始
router.post('/export', createAuditExport);

// 出力削除
router.delete('/exports/:id', deleteExport);

// === 新規PDF出力エンドポイント ===

// 運転者台帳PDF（個人）直接ダウンロード
router.get('/driver-registry/:driverId/pdf', downloadDriverRegistryPDF);

// 運転者台帳一覧PDF直接ダウンロード
router.get('/driver-registry-list/pdf', downloadDriverRegistryListPDF);

// コンプライアンスサマリーPDF直接ダウンロード
router.get('/compliance-summary/pdf', downloadComplianceSummaryPDF);

export default router;
