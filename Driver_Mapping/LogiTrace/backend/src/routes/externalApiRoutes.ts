import express from 'express';
import { authenticateApiKey, requireScope } from '../middleware/apiKeyAuth';
import {
    getWorkRecords,
    getWorkRecord,
    getTenkoRecords,
    getInspectionRecords,
    getDrivers,
    getVehicles,
    getComplianceSummary,
    getExpirationAlerts
} from '../controllers/externalApiController';

const router = express.Router();

// API Documentation endpoint
router.get('/', (req, res) => {
    res.json({
        name: 'LogiTrace External API',
        version: '1.0.0',
        description: 'REST API for integrating LogiTrace with accounting and ERP systems',
        authentication: {
            type: 'API Key',
            header: 'X-API-Key',
            description: 'Include your API key in the X-API-Key header'
        },
        endpoints: {
            workRecords: {
                list: 'GET /api/v1/work-records',
                detail: 'GET /api/v1/work-records/:id',
                description: 'Work records (日報)',
                scope: 'read'
            },
            tenko: {
                list: 'GET /api/v1/tenko',
                description: 'Tenko (点呼) records',
                scope: 'read'
            },
            inspections: {
                list: 'GET /api/v1/inspections',
                description: 'Vehicle inspection records (点検記録)',
                scope: 'read'
            },
            drivers: {
                list: 'GET /api/v1/drivers',
                description: 'Driver registry (運転者台帳)',
                scope: 'read'
            },
            vehicles: {
                list: 'GET /api/v1/vehicles',
                description: 'Vehicle list',
                scope: 'read'
            },
            compliance: {
                summary: 'GET /api/v1/compliance/summary',
                alerts: 'GET /api/v1/compliance/alerts',
                description: 'Compliance summary and alerts',
                scope: 'read'
            }
        },
        rateLimits: {
            default: '60 requests per minute',
            note: 'Rate limits can be configured per API key'
        },
        pagination: {
            description: 'All list endpoints support pagination',
            parameters: {
                page: 'Page number (default: 1)',
                limit: 'Items per page (default: 50, max: 100)'
            }
        },
        documentation: 'https://haisha-pro.com/api/docs'
    });
});

// All API routes require API key authentication
router.use(authenticateApiKey);

// Work Records (日報)
router.get('/work-records', requireScope('read'), getWorkRecords);
router.get('/work-records/:id', requireScope('read'), getWorkRecord);

// Tenko Records (点呼)
router.get('/tenko', requireScope('read'), getTenkoRecords);

// Inspection Records (点検)
router.get('/inspections', requireScope('read'), getInspectionRecords);

// Drivers (運転者)
router.get('/drivers', requireScope('read'), getDrivers);

// Vehicles (車両)
router.get('/vehicles', requireScope('read'), getVehicles);

// Compliance
router.get('/compliance/summary', requireScope('read'), getComplianceSummary);
router.get('/compliance/alerts', requireScope('read'), getExpirationAlerts);

export default router;
