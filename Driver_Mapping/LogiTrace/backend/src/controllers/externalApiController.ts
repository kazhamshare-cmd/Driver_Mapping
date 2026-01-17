import { Response } from 'express';
import { pool } from '../utils/db';
import { ApiKeyRequest, requireScope } from '../middleware/apiKeyAuth';

// === Work Records (日報) ===

// Get work records with pagination and filters
export const getWorkRecords = async (req: ApiKeyRequest, res: Response) => {
    const companyId = req.apiKey?.company_id;
    const {
        driverId,
        startDate,
        endDate,
        page = 1,
        limit = 50,
        sort = 'work_date',
        order = 'desc'
    } = req.query;

    try {
        const offset = (Number(page) - 1) * Number(limit);
        const params: any[] = [companyId];
        let whereClause = 'WHERE wr.company_id = $1';
        let paramCount = 2;

        if (driverId) {
            whereClause += ` AND wr.driver_id = $${paramCount++}`;
            params.push(driverId);
        }
        if (startDate) {
            whereClause += ` AND wr.work_date >= $${paramCount++}`;
            params.push(startDate);
        }
        if (endDate) {
            whereClause += ` AND wr.work_date <= $${paramCount++}`;
            params.push(endDate);
        }

        // Get total count
        const countResult = await pool.query(`
            SELECT COUNT(*) FROM work_records wr ${whereClause}
        `, params);

        // Get records with driver info
        params.push(Number(limit));
        params.push(offset);

        const validSortFields = ['work_date', 'created_at', 'driver_id'];
        const sortField = validSortFields.includes(sort as string) ? sort : 'work_date';
        const sortOrder = order === 'asc' ? 'ASC' : 'DESC';

        const result = await pool.query(`
            SELECT
                wr.id,
                wr.driver_id,
                u.name as driver_name,
                wr.work_date,
                wr.departure_time,
                wr.departure_location,
                wr.return_time,
                wr.return_location,
                wr.total_distance_km,
                wr.cargo_weight_kg,
                wr.driving_time_hours,
                wr.rest_time_hours,
                wr.notes,
                wr.created_at,
                wr.updated_at
            FROM work_records wr
            LEFT JOIN users u ON wr.driver_id = u.id
            ${whereClause}
            ORDER BY wr.${sortField} ${sortOrder}
            LIMIT $${paramCount++} OFFSET $${paramCount}
        `, params);

        res.json({
            data: result.rows,
            pagination: {
                total: parseInt(countResult.rows[0].count),
                page: Number(page),
                limit: Number(limit),
                totalPages: Math.ceil(parseInt(countResult.rows[0].count) / Number(limit))
            }
        });
    } catch (error) {
        console.error('External API - Get work records error:', error);
        res.status(500).json({ error: 'Failed to fetch work records' });
    }
};

// Get a single work record
export const getWorkRecord = async (req: ApiKeyRequest, res: Response) => {
    const companyId = req.apiKey?.company_id;
    const { id } = req.params;

    try {
        const result = await pool.query(`
            SELECT
                wr.*,
                u.name as driver_name,
                v.registration_number as vehicle_number
            FROM work_records wr
            LEFT JOIN users u ON wr.driver_id = u.id
            LEFT JOIN vehicles v ON wr.vehicle_id = v.id
            WHERE wr.id = $1 AND wr.company_id = $2
        `, [id, companyId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Work record not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('External API - Get work record error:', error);
        res.status(500).json({ error: 'Failed to fetch work record' });
    }
};

// === Tenko (点呼) Records ===

// Get tenko records
export const getTenkoRecords = async (req: ApiKeyRequest, res: Response) => {
    const companyId = req.apiKey?.company_id;
    const {
        driverId,
        tenkoType,
        startDate,
        endDate,
        page = 1,
        limit = 50
    } = req.query;

    try {
        const offset = (Number(page) - 1) * Number(limit);
        const params: any[] = [companyId];
        let whereClause = 'WHERE t.company_id = $1';
        let paramCount = 2;

        if (driverId) {
            whereClause += ` AND t.driver_id = $${paramCount++}`;
            params.push(driverId);
        }
        if (tenkoType) {
            whereClause += ` AND t.tenko_type = $${paramCount++}`;
            params.push(tenkoType);
        }
        if (startDate) {
            whereClause += ` AND DATE(t.tenko_datetime) >= $${paramCount++}`;
            params.push(startDate);
        }
        if (endDate) {
            whereClause += ` AND DATE(t.tenko_datetime) <= $${paramCount++}`;
            params.push(endDate);
        }

        const countResult = await pool.query(`
            SELECT COUNT(*) FROM tenko_records t ${whereClause}
        `, params);

        params.push(Number(limit));
        params.push(offset);

        const result = await pool.query(`
            SELECT
                t.id,
                t.driver_id,
                u.name as driver_name,
                t.tenko_type,
                t.tenko_datetime,
                t.alcohol_level,
                t.health_condition,
                t.fatigue_level,
                t.sleep_hours,
                t.illness_notes,
                t.weather_conditions,
                t.work_instructions,
                t.performed_by,
                t.tenko_method,
                t.is_face_to_face,
                t.created_at
            FROM tenko_records t
            LEFT JOIN users u ON t.driver_id = u.id
            ${whereClause}
            ORDER BY t.tenko_datetime DESC
            LIMIT $${paramCount++} OFFSET $${paramCount}
        `, params);

        res.json({
            data: result.rows,
            pagination: {
                total: parseInt(countResult.rows[0].count),
                page: Number(page),
                limit: Number(limit),
                totalPages: Math.ceil(parseInt(countResult.rows[0].count) / Number(limit))
            }
        });
    } catch (error) {
        console.error('External API - Get tenko records error:', error);
        res.status(500).json({ error: 'Failed to fetch tenko records' });
    }
};

// === Inspection Records (点検記録) ===

// Get inspection records
export const getInspectionRecords = async (req: ApiKeyRequest, res: Response) => {
    const companyId = req.apiKey?.company_id;
    const {
        vehicleId,
        inspectionType,
        startDate,
        endDate,
        page = 1,
        limit = 50
    } = req.query;

    try {
        const offset = (Number(page) - 1) * Number(limit);
        const params: any[] = [companyId];
        let whereClause = 'WHERE i.company_id = $1';
        let paramCount = 2;

        if (vehicleId) {
            whereClause += ` AND i.vehicle_id = $${paramCount++}`;
            params.push(vehicleId);
        }
        if (inspectionType) {
            whereClause += ` AND i.inspection_type = $${paramCount++}`;
            params.push(inspectionType);
        }
        if (startDate) {
            whereClause += ` AND i.inspection_date >= $${paramCount++}`;
            params.push(startDate);
        }
        if (endDate) {
            whereClause += ` AND i.inspection_date <= $${paramCount++}`;
            params.push(endDate);
        }

        const countResult = await pool.query(`
            SELECT COUNT(*) FROM inspection_records i ${whereClause}
        `, params);

        params.push(Number(limit));
        params.push(offset);

        const result = await pool.query(`
            SELECT
                i.id,
                i.vehicle_id,
                v.registration_number as vehicle_number,
                i.inspection_type,
                i.inspection_date,
                i.inspector_id,
                u.name as inspector_name,
                i.overall_result,
                i.items_checked,
                i.issues_found,
                i.corrective_actions,
                i.next_inspection_date,
                i.created_at
            FROM inspection_records i
            LEFT JOIN vehicles v ON i.vehicle_id = v.id
            LEFT JOIN users u ON i.inspector_id = u.id
            ${whereClause}
            ORDER BY i.inspection_date DESC
            LIMIT $${paramCount++} OFFSET $${paramCount}
        `, params);

        res.json({
            data: result.rows,
            pagination: {
                total: parseInt(countResult.rows[0].count),
                page: Number(page),
                limit: Number(limit),
                totalPages: Math.ceil(parseInt(countResult.rows[0].count) / Number(limit))
            }
        });
    } catch (error) {
        console.error('External API - Get inspection records error:', error);
        res.status(500).json({ error: 'Failed to fetch inspection records' });
    }
};

// === Drivers ===

// Get drivers list
export const getDrivers = async (req: ApiKeyRequest, res: Response) => {
    const companyId = req.apiKey?.company_id;
    const { status, page = 1, limit = 50 } = req.query;

    try {
        const offset = (Number(page) - 1) * Number(limit);
        const params: any[] = [companyId];
        let whereClause = 'WHERE dr.company_id = $1';
        let paramCount = 2;

        if (status) {
            whereClause += ` AND dr.status = $${paramCount++}`;
            params.push(status);
        }

        const countResult = await pool.query(`
            SELECT COUNT(*) FROM driver_registries dr ${whereClause}
        `, params);

        params.push(Number(limit));
        params.push(offset);

        const result = await pool.query(`
            SELECT
                dr.id,
                dr.driver_id,
                dr.full_name,
                dr.full_name_kana,
                dr.employee_number,
                dr.hire_date,
                dr.license_number,
                dr.license_type,
                dr.license_expiry_date,
                dr.status,
                dr.created_at,
                dr.updated_at
            FROM driver_registries dr
            ${whereClause}
            ORDER BY dr.full_name_kana ASC
            LIMIT $${paramCount++} OFFSET $${paramCount}
        `, params);

        res.json({
            data: result.rows,
            pagination: {
                total: parseInt(countResult.rows[0].count),
                page: Number(page),
                limit: Number(limit),
                totalPages: Math.ceil(parseInt(countResult.rows[0].count) / Number(limit))
            }
        });
    } catch (error) {
        console.error('External API - Get drivers error:', error);
        res.status(500).json({ error: 'Failed to fetch drivers' });
    }
};

// === Vehicles ===

// Get vehicles list
export const getVehicles = async (req: ApiKeyRequest, res: Response) => {
    const companyId = req.apiKey?.company_id;
    const { status, page = 1, limit = 50 } = req.query;

    try {
        const offset = (Number(page) - 1) * Number(limit);
        const params: any[] = [companyId];
        let whereClause = 'WHERE v.company_id = $1';
        let paramCount = 2;

        if (status) {
            whereClause += ` AND v.status = $${paramCount++}`;
            params.push(status);
        }

        const countResult = await pool.query(`
            SELECT COUNT(*) FROM vehicles v ${whereClause}
        `, params);

        params.push(Number(limit));
        params.push(offset);

        const result = await pool.query(`
            SELECT
                v.id,
                v.registration_number,
                v.vehicle_type,
                v.make,
                v.model,
                v.year,
                v.capacity,
                v.inspection_expiry_date,
                v.insurance_expiry_date,
                v.status,
                v.created_at,
                v.updated_at
            FROM vehicles v
            ${whereClause}
            ORDER BY v.registration_number ASC
            LIMIT $${paramCount++} OFFSET $${paramCount}
        `, params);

        res.json({
            data: result.rows,
            pagination: {
                total: parseInt(countResult.rows[0].count),
                page: Number(page),
                limit: Number(limit),
                totalPages: Math.ceil(parseInt(countResult.rows[0].count) / Number(limit))
            }
        });
    } catch (error) {
        console.error('External API - Get vehicles error:', error);
        res.status(500).json({ error: 'Failed to fetch vehicles' });
    }
};

// === Compliance Summary ===

// Get compliance summary for accounting/ERP systems
export const getComplianceSummary = async (req: ApiKeyRequest, res: Response) => {
    const companyId = req.apiKey?.company_id;
    const { startDate, endDate } = req.query;

    try {
        const dateFilter = startDate && endDate
            ? `AND created_at BETWEEN '${startDate}' AND '${endDate}'`
            : '';

        // Get counts for various records
        const [workRecords, tenkoRecords, inspections, accidents] = await Promise.all([
            pool.query(`
                SELECT COUNT(*) as count, SUM(total_distance_km) as total_distance
                FROM work_records
                WHERE company_id = $1 ${dateFilter.replace('created_at', 'work_date')}
            `, [companyId]),
            pool.query(`
                SELECT
                    COUNT(*) as total,
                    COUNT(CASE WHEN tenko_type = 'departure' THEN 1 END) as departure_count,
                    COUNT(CASE WHEN tenko_type = 'return' THEN 1 END) as return_count,
                    COUNT(CASE WHEN alcohol_level > 0 THEN 1 END) as alcohol_detected
                FROM tenko_records
                WHERE company_id = $1 ${dateFilter.replace('created_at', 'tenko_datetime')}
            `, [companyId]),
            pool.query(`
                SELECT
                    COUNT(*) as total,
                    COUNT(CASE WHEN overall_result = 'pass' THEN 1 END) as passed,
                    COUNT(CASE WHEN overall_result = 'fail' THEN 1 END) as failed
                FROM inspection_records
                WHERE company_id = $1 ${dateFilter.replace('created_at', 'inspection_date')}
            `, [companyId]),
            pool.query(`
                SELECT
                    COUNT(*) as total,
                    COUNT(CASE WHEN record_type = 'accident' THEN 1 END) as accidents,
                    COUNT(CASE WHEN record_type = 'violation' THEN 1 END) as violations
                FROM accident_violation_records
                WHERE company_id = $1 ${dateFilter.replace('created_at', 'incident_date')}
            `, [companyId])
        ]);

        // Get active drivers and vehicles count
        const [drivers, vehicles] = await Promise.all([
            pool.query(`
                SELECT COUNT(*) as active FROM driver_registries WHERE company_id = $1 AND status = 'active'
            `, [companyId]),
            pool.query(`
                SELECT COUNT(*) as active FROM vehicles WHERE company_id = $1 AND status = 'active'
            `, [companyId])
        ]);

        res.json({
            period: { startDate, endDate },
            summary: {
                workRecords: {
                    count: parseInt(workRecords.rows[0].count),
                    totalDistanceKm: parseFloat(workRecords.rows[0].total_distance) || 0
                },
                tenko: {
                    total: parseInt(tenkoRecords.rows[0].total),
                    departure: parseInt(tenkoRecords.rows[0].departure_count),
                    return: parseInt(tenkoRecords.rows[0].return_count),
                    alcoholDetected: parseInt(tenkoRecords.rows[0].alcohol_detected)
                },
                inspections: {
                    total: parseInt(inspections.rows[0].total),
                    passed: parseInt(inspections.rows[0].passed),
                    failed: parseInt(inspections.rows[0].failed)
                },
                incidents: {
                    total: parseInt(accidents.rows[0].total),
                    accidents: parseInt(accidents.rows[0].accidents),
                    violations: parseInt(accidents.rows[0].violations)
                },
                resources: {
                    activeDrivers: parseInt(drivers.rows[0].active),
                    activeVehicles: parseInt(vehicles.rows[0].active)
                }
            },
            generatedAt: new Date().toISOString()
        });
    } catch (error) {
        console.error('External API - Get compliance summary error:', error);
        res.status(500).json({ error: 'Failed to fetch compliance summary' });
    }
};

// === Expiration Alerts ===

// Get upcoming expirations for external monitoring
export const getExpirationAlerts = async (req: ApiKeyRequest, res: Response) => {
    const companyId = req.apiKey?.company_id;
    const { daysAhead = 30 } = req.query;

    try {
        // License expirations
        const licenses = await pool.query(`
            SELECT
                'license' as type,
                dr.driver_id,
                dr.full_name as name,
                dr.license_expiry_date as expiry_date,
                dr.license_expiry_date - CURRENT_DATE as days_remaining
            FROM driver_registries dr
            WHERE dr.company_id = $1
            AND dr.status = 'active'
            AND dr.license_expiry_date <= CURRENT_DATE + INTERVAL '${Number(daysAhead)} days'
            ORDER BY dr.license_expiry_date ASC
        `, [companyId]);

        // Vehicle inspection expirations
        const vehicleInspections = await pool.query(`
            SELECT
                'vehicle_inspection' as type,
                v.id as vehicle_id,
                v.registration_number as name,
                v.inspection_expiry_date as expiry_date,
                v.inspection_expiry_date - CURRENT_DATE as days_remaining
            FROM vehicles v
            WHERE v.company_id = $1
            AND v.status = 'active'
            AND v.inspection_expiry_date <= CURRENT_DATE + INTERVAL '${Number(daysAhead)} days'
            ORDER BY v.inspection_expiry_date ASC
        `, [companyId]);

        // Health checkup due
        const healthCheckups = await pool.query(`
            SELECT
                'health_checkup' as type,
                hc.driver_id,
                dr.full_name as name,
                hc.next_checkup_date as expiry_date,
                hc.next_checkup_date - CURRENT_DATE as days_remaining
            FROM health_checkup_records hc
            JOIN driver_registries dr ON hc.driver_id = dr.driver_id
            WHERE hc.company_id = $1
            AND hc.next_checkup_date <= CURRENT_DATE + INTERVAL '${Number(daysAhead)} days'
            AND hc.id = (
                SELECT MAX(id) FROM health_checkup_records
                WHERE driver_id = hc.driver_id AND company_id = hc.company_id
            )
            ORDER BY hc.next_checkup_date ASC
        `, [companyId]);

        res.json({
            alerts: {
                licenses: licenses.rows,
                vehicleInspections: vehicleInspections.rows,
                healthCheckups: healthCheckups.rows
            },
            summary: {
                totalAlerts: licenses.rows.length + vehicleInspections.rows.length + healthCheckups.rows.length,
                critical: licenses.rows.filter(r => r.days_remaining <= 7).length +
                    vehicleInspections.rows.filter(r => r.days_remaining <= 7).length +
                    healthCheckups.rows.filter(r => r.days_remaining <= 7).length
            },
            daysAhead: Number(daysAhead),
            generatedAt: new Date().toISOString()
        });
    } catch (error) {
        console.error('External API - Get expiration alerts error:', error);
        res.status(500).json({ error: 'Failed to fetch expiration alerts' });
    }
};
