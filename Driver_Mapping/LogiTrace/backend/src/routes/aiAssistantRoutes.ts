/**
 * AI Assistant Routes
 * AI連携機能API
 */

import { Router } from 'express';
import {
    getAiSettings,
    updateAiSettings,
    startChatSession,
    sendChatMessage,
    getChatHistory,
    getUserSessions,
    getDispatchOptimization,
    getCostAnalysis,
    getComplianceAlerts,
    generateDailySummary,
    getReports,
    getReportById
} from '../controllers/aiAssistantController';

const router = Router();

// ============================================
// AI設定
// ============================================

// AI設定取得
router.get('/settings', getAiSettings);

// AI設定更新
router.put('/settings/:companyId', updateAiSettings);

// ============================================
// AIチャット
// ============================================

// チャットセッション開始
router.post('/chat/start', startChatSession);

// メッセージ送信
router.post('/chat/message', sendChatMessage);

// チャット履歴取得
router.get('/chat/history/:sessionId', getChatHistory);

// ユーザーセッション一覧
router.get('/chat/sessions/:userId', getUserSessions);

// ============================================
// AI分析
// ============================================

// 配車最適化提案
router.get('/analysis/dispatch', getDispatchOptimization);

// コスト分析
router.get('/analysis/cost', getCostAnalysis);

// コンプライアンスアラート
router.get('/analysis/compliance', getComplianceAlerts);

// ============================================
// AIレポート
// ============================================

// 日次サマリー生成
router.post('/reports/daily-summary', generateDailySummary);

// レポート一覧取得
router.get('/reports', getReports);

// レポート詳細取得
router.get('/reports/:id', getReportById);

export default router;
