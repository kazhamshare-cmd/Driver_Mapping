import express from 'express';
import { authenticateToken } from '../middleware/authMiddleware';
import {
    getOperationInstructions,
    getOperationInstruction,
    getDriverOperationInstructions,
    createOperationInstruction,
    updateOperationInstruction,
    updateOperationInstructionStatus,
    deleteOperationInstruction
} from '../controllers/operationInstructionController';

const router = express.Router();

// All routes require authentication
router.use(authenticateToken);

// GET /operation-instructions - List all for company
router.get('/', getOperationInstructions);

// GET /operation-instructions/driver/:driverId - Get instructions for a specific driver
router.get('/driver/:driverId', getDriverOperationInstructions);

// GET /operation-instructions/:id - Get single instruction
router.get('/:id', getOperationInstruction);

// POST /operation-instructions - Create new instruction
router.post('/', createOperationInstruction);

// PUT /operation-instructions/:id - Update instruction
router.put('/:id', updateOperationInstruction);

// PUT /operation-instructions/:id/status - Update status
router.put('/:id/status', updateOperationInstructionStatus);

// DELETE /operation-instructions/:id - Delete instruction (draft only)
router.delete('/:id', deleteOperationInstruction);

export default router;
