/**
 * Actual Transport Routes
 * 実運送体制管理簿API
 */

import { Router } from 'express';
import {
    getSubcontractAgreements,
    createSubcontractAgreement,
    updateSubcontractAgreement,
    getActualTransportRecords,
    getActualTransportRecordById,
    createActualTransportRecord,
    updateActualTransportRecord,
    confirmActualTransportRecord,
    submitActualTransportRecord,
    getActualTransportSummary,
    generateFromOrder
} from '../controllers/actualTransportController';

const router = Router();

// ============================================
// 下請契約管理
// ============================================

// 下請契約一覧取得
router.get('/subcontracts', getSubcontractAgreements);

// 下請契約作成
router.post('/subcontracts', createSubcontractAgreement);

// 下請契約更新
router.put('/subcontracts/:id', updateSubcontractAgreement);

// ============================================
// 実運送体制管理簿
// ============================================

// 管理簿一覧取得
router.get('/records', getActualTransportRecords);

// 管理簿詳細取得
router.get('/records/:id', getActualTransportRecordById);

// 管理簿作成
router.post('/records', createActualTransportRecord);

// 管理簿更新
router.put('/records/:id', updateActualTransportRecord);

// 管理簿確認
router.post('/records/:id/confirm', confirmActualTransportRecord);

// 管理簿提出
router.post('/records/:id/submit', submitActualTransportRecord);

// 受注から管理簿自動生成
router.post('/records/generate-from-order', generateFromOrder);

// ============================================
// サマリー
// ============================================

// 実運送体制サマリー
router.get('/summary', getActualTransportSummary);

export default router;
