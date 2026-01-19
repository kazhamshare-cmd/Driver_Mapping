/**
 * Fair Transaction Routes
 * 取適法対応API
 */

import { Router } from 'express';
import {
    getTransactionTerms,
    getTransactionTermsById,
    createTransactionTerms,
    updateTransactionTerms,
    confirmDocumentReceipt,
    getUnfairPractices,
    createUnfairPractice,
    updateUnfairPracticeStatus,
    getFairTransactionSummary,
    getTermsForPdf
} from '../controllers/fairTransactionController';

const router = Router();

// ============================================
// 取引条件書管理
// ============================================

// 取引条件書一覧取得
router.get('/terms', getTransactionTerms);

// 取引条件書詳細取得
router.get('/terms/:id', getTransactionTermsById);

// 取引条件書作成
router.post('/terms', createTransactionTerms);

// 取引条件書更新
router.put('/terms/:id', updateTransactionTerms);

// 書面交付確認
router.post('/terms/:id/confirm-receipt', confirmDocumentReceipt);

// PDF生成用データ取得
router.get('/terms/:id/pdf-data', getTermsForPdf);

// ============================================
// 不当取引行為記録
// ============================================

// 不当取引行為一覧取得
router.get('/unfair-practices', getUnfairPractices);

// 不当取引行為記録作成
router.post('/unfair-practices', createUnfairPractice);

// 不当取引行為ステータス更新
router.put('/unfair-practices/:id/status', updateUnfairPracticeStatus);

// ============================================
// ダッシュボード
// ============================================

// コンプライアンスサマリー
router.get('/summary', getFairTransactionSummary);

export default router;
