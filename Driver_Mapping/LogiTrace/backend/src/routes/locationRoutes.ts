/**
 * Location Routes - 発着地マスタAPI
 */

import { Router } from 'express';
import {
    getLocations,
    getLocationById,
    createLocation,
    updateLocation,
    deleteLocation,
    geocodeAddress
} from '../controllers/locationController';
import { authenticateToken } from '../middleware/authMiddleware';

const router = Router();

router.get('/', authenticateToken, getLocations);
router.get('/:id', authenticateToken, getLocationById);
router.post('/', authenticateToken, createLocation);
router.put('/:id', authenticateToken, updateLocation);
router.delete('/:id', authenticateToken, deleteLocation);
router.post('/geocode', authenticateToken, geocodeAddress);

export default router;
