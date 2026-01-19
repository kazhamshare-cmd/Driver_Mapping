import { Router } from 'express';
import {
    getSupportedFormats,
    uploadTachographData,
    previewTachographData,
    getImportHistory,
    getImportById,
    parseUploadedFile,
    importTachographData,
    autoMatchTachographData,
    manualMatchTachographData,
    getUnmatchedData,
    getMatchCandidates
} from '../controllers/tachographController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

// すべてのエンドポイントで認証が必要
router.use(authenticateToken);

// 対応フォーマット一覧
router.get('/supported-formats', getSupportedFormats);

// インポート履歴
router.get('/imports', getImportHistory);

// インポート詳細
router.get('/imports/:id', getImportById);

// 未マッチデータ一覧
router.get('/unmatched', getUnmatchedData);

// マッチ候補取得
router.get('/candidates/:tachograph_data_id', getMatchCandidates);

// CSVプレビュー（保存せずにパース結果を返す）
router.post('/preview', previewTachographData);

// CSVファイルパース（新形式）
router.post('/parse', parseUploadedFile);

// CSVアップロード・インポート（旧形式）
router.post('/upload', uploadTachographData);

// CSVインポート（新形式）
router.post('/import', importTachographData);

// 自動マッチング実行
router.post('/auto-match', autoMatchTachographData);
router.post('/auto-match/:import_id', autoMatchTachographData);

// 手動マッチング
router.post('/manual-match', manualMatchTachographData);

export default router;
