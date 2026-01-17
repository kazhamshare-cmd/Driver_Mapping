import { Router } from 'express';
import { authenticateToken } from '../middleware/authMiddleware';
import { upload, uploadImage, uploadMultipleImages, deleteImage } from '../controllers/uploadController';

const router = Router();

// Single image upload
router.post('/image', authenticateToken, upload.single('image'), uploadImage);

// Multiple images upload (up to 5)
router.post('/images', authenticateToken, upload.array('images', 5), uploadMultipleImages);

// Delete image
router.delete('/image/:filename', authenticateToken, deleteImage);

export default router;
