import { Router } from 'express';
import { createWorkRecord, updateWorkRecord, getWorkRecords, getWorkRecordById } from '../controllers/workRecordController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

router.post('/', authenticateToken, createWorkRecord);
router.get('/', authenticateToken, getWorkRecords);
router.get('/:id', authenticateToken, getWorkRecordById);
router.put('/:id', authenticateToken, updateWorkRecord);

export default router;
