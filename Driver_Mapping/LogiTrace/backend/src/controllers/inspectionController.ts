import { Request, Response } from 'express';
import { pool } from '../utils/db';

// 点検記録作成
export const createInspection = async (req: Request, res: Response) => {
    try {
        const {
            company_id,
            vehicle_id,
            driver_id,
            work_record_id,
            inspection_items,
            odometer_reading,
            inspector_signature,
            notes,
            issues_found,
            follow_up_required,
            follow_up_notes,
            photos
        } = req.body;

        // 総合判定を計算
        let overall_result = 'pass';
        const items = inspection_items || {};

        for (const key of Object.keys(items)) {
            if (items[key].result === 'fail') {
                overall_result = 'fail';
                break;
            }
        }

        // 問題が見つかった場合は条件付き合格も検討
        if (overall_result === 'pass' && (issues_found || follow_up_required)) {
            overall_result = 'conditional';
        }

        const result = await pool.query(
            `INSERT INTO vehicle_inspection_records (
                company_id, vehicle_id, driver_id, work_record_id,
                inspection_date, inspection_time, overall_result, inspection_items,
                odometer_reading, inspector_signature, notes, issues_found,
                follow_up_required, follow_up_notes, photos
            ) VALUES (
                $1, $2, $3, $4,
                CURRENT_DATE, NOW(), $5, $6,
                $7, $8, $9, $10,
                $11, $12, $13
            ) RETURNING *`,
            [
                company_id, vehicle_id, driver_id, work_record_id,
                overall_result, JSON.stringify(inspection_items),
                odometer_reading, inspector_signature, notes, issues_found,
                follow_up_required || false, follow_up_notes,
                photos ? JSON.stringify(photos) : null
            ]
        );

        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error creating inspection record:', error);
        res.status(500).json({ error: 'Failed to create inspection record' });
    }
};

// 点検記録一覧取得
export const getInspections = async (req: Request, res: Response) => {
    try {
        const { companyId, vehicleId, driverId, dateFrom, dateTo, result: overallResult, limit = 100, offset = 0 } = req.query;

        let query = `
            SELECT i.*, v.vehicle_number, u.name as driver_name
            FROM vehicle_inspection_records i
            LEFT JOIN vehicles v ON i.vehicle_id = v.id
            LEFT JOIN users u ON i.driver_id = u.id
            WHERE i.company_id = $1
        `;
        const params: any[] = [companyId];
        let paramIndex = 2;

        if (vehicleId) {
            query += ` AND i.vehicle_id = $${paramIndex}`;
            params.push(vehicleId);
            paramIndex++;
        }

        if (driverId) {
            query += ` AND i.driver_id = $${paramIndex}`;
            params.push(driverId);
            paramIndex++;
        }

        if (dateFrom) {
            query += ` AND i.inspection_date >= $${paramIndex}`;
            params.push(dateFrom);
            paramIndex++;
        }

        if (dateTo) {
            query += ` AND i.inspection_date <= $${paramIndex}`;
            params.push(dateTo);
            paramIndex++;
        }

        if (overallResult) {
            query += ` AND i.overall_result = $${paramIndex}`;
            params.push(overallResult);
            paramIndex++;
        }

        query += ` ORDER BY i.inspection_date DESC, i.inspection_time DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
        params.push(limit, offset);

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching inspections:', error);
        res.status(500).json({ error: 'Failed to fetch inspections' });
    }
};

// 点検記録詳細取得
export const getInspectionById = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        const result = await pool.query(
            `SELECT i.*, v.vehicle_number, v.vehicle_type, u.name as driver_name
             FROM vehicle_inspection_records i
             LEFT JOIN vehicles v ON i.vehicle_id = v.id
             LEFT JOIN users u ON i.driver_id = u.id
             WHERE i.id = $1`,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Inspection record not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching inspection:', error);
        res.status(500).json({ error: 'Failed to fetch inspection' });
    }
};

// 点検項目マスタ取得
export const getInspectionItems = async (req: Request, res: Response) => {
    try {
        const { category, requiredOnly } = req.query;

        let query = 'SELECT * FROM inspection_item_master WHERE 1=1';
        const params: any[] = [];
        let paramIndex = 1;

        if (category) {
            query += ` AND category = $${paramIndex}`;
            params.push(category);
            paramIndex++;
        }

        if (requiredOnly === 'true') {
            query += ' AND is_required = TRUE';
        }

        query += ' ORDER BY display_order ASC';

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching inspection items:', error);
        res.status(500).json({ error: 'Failed to fetch inspection items' });
    }
};

// 車両の最新点検記録取得
export const getLatestInspectionByVehicle = async (req: Request, res: Response) => {
    try {
        const { vehicleId } = req.params;

        const result = await pool.query(
            `SELECT i.*, u.name as driver_name
             FROM vehicle_inspection_records i
             LEFT JOIN users u ON i.driver_id = u.id
             WHERE i.vehicle_id = $1
             ORDER BY i.inspection_date DESC, i.inspection_time DESC
             LIMIT 1`,
            [vehicleId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'No inspection record found for this vehicle' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching latest inspection:', error);
        res.status(500).json({ error: 'Failed to fetch latest inspection' });
    }
};

// 今日の点検済み車両取得
export const getTodayInspectedVehicles = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.query;

        const result = await pool.query(
            `SELECT DISTINCT i.vehicle_id, v.vehicle_number, i.overall_result, i.inspection_time
             FROM vehicle_inspection_records i
             JOIN vehicles v ON i.vehicle_id = v.id
             WHERE i.company_id = $1 AND i.inspection_date = CURRENT_DATE
             ORDER BY i.inspection_time DESC`,
            [companyId]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching today inspected vehicles:', error);
        res.status(500).json({ error: 'Failed to fetch inspected vehicles' });
    }
};

// 点検記録更新
export const updateInspection = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const { notes, follow_up_notes, follow_up_required } = req.body;

        const result = await pool.query(
            `UPDATE vehicle_inspection_records
             SET notes = COALESCE($1, notes),
                 follow_up_notes = COALESCE($2, follow_up_notes),
                 follow_up_required = COALESCE($3, follow_up_required),
                 updated_at = NOW()
             WHERE id = $4
             RETURNING *`,
            [notes, follow_up_notes, follow_up_required, id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Inspection record not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating inspection:', error);
        res.status(500).json({ error: 'Failed to update inspection' });
    }
};

// フォローアップが必要な点検一覧
export const getFollowUpRequired = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.query;

        const result = await pool.query(
            `SELECT i.*, v.vehicle_number, u.name as driver_name
             FROM vehicle_inspection_records i
             LEFT JOIN vehicles v ON i.vehicle_id = v.id
             LEFT JOIN users u ON i.driver_id = u.id
             WHERE i.company_id = $1 AND i.follow_up_required = TRUE
             ORDER BY i.inspection_date DESC`,
            [companyId]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching follow-up required:', error);
        res.status(500).json({ error: 'Failed to fetch follow-up required inspections' });
    }
};
