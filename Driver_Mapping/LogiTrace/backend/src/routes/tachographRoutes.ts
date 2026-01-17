import { Router } from 'express';
import {
    getSupportedFormats,
    uploadTachographData,
    previewTachographData,
    getImportHistory,
    getImportById
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

// CSVプレビュー（保存せずにパース結果を返す）
router.post('/preview', previewTachographData);

// CSVアップロード・インポート
router.post('/upload', uploadTachographData);

export default router;
