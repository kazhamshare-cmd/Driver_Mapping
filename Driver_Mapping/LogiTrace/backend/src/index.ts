import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { Pool } from 'pg';

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Routes
import authRoutes from './routes/authRoutes';
import workRecordRoutes from './routes/workRecordRoutes';
import subscriptionRoutes from './routes/subscriptionRoutes';
import driverRoutes from './routes/driverRoutes';
import dashboardRoutes from './routes/dashboardRoutes';
import tenkoRoutes from './routes/tenkoRoutes';
import inspectionRoutes from './routes/inspectionRoutes';
import tachographRoutes from './routes/tachographRoutes';
import auditExportRoutes from './routes/auditExportRoutes';
// Multi-industry support routes
import industryRoutes from './routes/industryRoutes';
import driverRegistryRoutes from './routes/driverRegistryRoutes';
import healthCheckupRoutes from './routes/healthCheckupRoutes';
import aptitudeTestRoutes from './routes/aptitudeTestRoutes';
import trainingRoutes from './routes/trainingRoutes';
import accidentRoutes from './routes/accidentRoutes';
// Bus industry specific routes
import operationInstructionRoutes from './routes/operationInstructionRoutes';
// API integration routes
import apiKeyRoutes from './routes/apiKeyRoutes';
import externalApiRoutes from './routes/externalApiRoutes';
// Report routes
import reportRoutes from './routes/reportRoutes';
// Upload routes
import uploadRoutes from './routes/uploadRoutes';
// Data retention routes
import dataRetentionRoutes from './routes/dataRetentionRoutes';
import path from 'path';
// Expiration alert service
import { getAlertsController, getSummaryController, checkOperateController } from './services/expirationAlertService';
import { authenticateToken } from './middleware/authMiddleware';

app.use('/auth', authRoutes);
app.use('/work-records', workRecordRoutes);
app.use('/billing', subscriptionRoutes);
app.use('/drivers', driverRoutes);
app.use('/dashboard', dashboardRoutes);
app.use('/tenko', tenkoRoutes);
app.use('/inspections', inspectionRoutes);
app.use('/tachograph', tachographRoutes);
app.use('/audit', auditExportRoutes);
// Multi-industry support routes
app.use('/industries', industryRoutes);
app.use('/driver-registry', driverRegistryRoutes);
app.use('/health-checkups', healthCheckupRoutes);
app.use('/aptitude-tests', aptitudeTestRoutes);
app.use('/training', trainingRoutes);
app.use('/accidents', accidentRoutes);
// Bus industry specific routes
app.use('/operation-instructions', operationInstructionRoutes);
// API integration (internal management)
app.use('/api-management', apiKeyRoutes);
// External API (public API with API key auth)
app.use('/api/v1', externalApiRoutes);
// Report routes
app.use('/reports', reportRoutes);
// Upload routes
app.use('/upload', uploadRoutes);
// Data retention routes
app.use('/data-retention', dataRetentionRoutes);
// Serve uploaded files
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));
// Compliance alerts
app.get('/alerts', authenticateToken, getAlertsController);
app.get('/compliance/summary', authenticateToken, getSummaryController);
app.get('/compliance/check/:driverId', authenticateToken, checkOperateController);

// Database connection
const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
});

// Health check
app.get('/', (req, res) => {
    res.send('LogiTrace API is running');
});

// Start server
app.listen(port, () => {
    console.log(`Server is running on port ${port}`);
});

export { pool };
