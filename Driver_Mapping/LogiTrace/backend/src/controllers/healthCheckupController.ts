import { Request, Response } from 'express';
import { pool } from '../utils/db';

// 健康診断記録一覧取得
export const getHealthCheckups = async (req: Request, res: Response) => {
    try {
        const { companyId, driverId, checkupType, dateFrom, dateTo, limit = 100, offset = 0 } = req.query;

        let query = `
            SELECT hc.*, dr.full_name as driver_name, u.employee_number
            FROM health_checkup_records hc
            JOIN driver_registries dr ON hc.driver_id = dr.driver_id
            JOIN users u ON hc.driver_id = u.id
            WHERE hc.company_id = $1
        `;
        const params: any[] = [companyId];
        let paramIndex = 2;

        if (driverId) {
            query += ` AND hc.driver_id = $${paramIndex}`;
            params.push(driverId);
            paramIndex++;
        }

        if (checkupType) {
            query += ` AND hc.checkup_type = $${paramIndex}`;
            params.push(checkupType);
            paramIndex++;
        }

        if (dateFrom) {
            query += ` AND hc.checkup_date >= $${paramIndex}`;
            params.push(dateFrom);
            paramIndex++;
        }

        if (dateTo) {
            query += ` AND hc.checkup_date <= $${paramIndex}`;
            params.push(dateTo);
            paramIndex++;
        }

        query += ` ORDER BY hc.checkup_date DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
        params.push(limit, offset);

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching health checkups:', error);
        res.status(500).json({ error: 'Failed to fetch health checkups' });
    }
};

// 健康診断記録詳細取得
export const getHealthCheckupById = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        const result = await pool.query(
            `SELECT hc.*, dr.full_name as driver_name, u.employee_number
             FROM health_checkup_records hc
             JOIN driver_registries dr ON hc.driver_id = dr.driver_id
             JOIN users u ON hc.driver_id = u.id
             WHERE hc.id = $1`,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Health checkup record not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching health checkup:', error);
        res.status(500).json({ error: 'Failed to fetch health checkup' });
    }
};

// 健康診断記録作成
export const createHealthCheckup = async (req: Request, res: Response) => {
    try {
        const {
            company_id,
            driver_id,
            checkup_type,
            checkup_date,
            next_checkup_date,
            facility_name,
            overall_result,
            result_details,
            work_restriction_notes,
            certificate_url
        } = req.body;

        const result = await pool.query(
            `INSERT INTO health_checkup_records (
                company_id, driver_id, checkup_type, checkup_date, next_checkup_date,
                facility_name, overall_result, result_details, work_restriction_notes, certificate_url
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
             RETURNING *`,
            [
                company_id, driver_id, checkup_type, checkup_date, next_checkup_date,
                facility_name, overall_result,
                result_details ? JSON.stringify(result_details) : null,
                work_restriction_notes, certificate_url
            ]
        );

        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error creating health checkup:', error);
        res.status(500).json({ error: 'Failed to create health checkup' });
    }
};

// 健康診断記録更新
export const updateHealthCheckup = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const {
            checkup_type,
            checkup_date,
            next_checkup_date,
            facility_name,
            overall_result,
            result_details,
            work_restriction_notes,
            certificate_url
        } = req.body;

        const result = await pool.query(
            `UPDATE health_checkup_records SET
                checkup_type = COALESCE($1, checkup_type),
                checkup_date = COALESCE($2, checkup_date),
                next_checkup_date = $3,
                facility_name = COALESCE($4, facility_name),
                overall_result = COALESCE($5, overall_result),
                result_details = COALESCE($6, result_details),
                work_restriction_notes = $7,
                certificate_url = $8,
                updated_at = NOW()
             WHERE id = $9
             RETURNING *`,
            [
                checkup_type, checkup_date, next_checkup_date, facility_name,
                overall_result, result_details ? JSON.stringify(result_details) : null,
                work_restriction_notes, certificate_url, id
            ]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Health checkup record not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating health checkup:', error);
        res.status(500).json({ error: 'Failed to update health checkup' });
    }
};

// 健康診断記録削除
export const deleteHealthCheckup = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        const result = await pool.query(
            'DELETE FROM health_checkup_records WHERE id = $1 RETURNING id',
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Health checkup record not found' });
        }

        res.json({ message: 'Health checkup record deleted successfully' });
    } catch (error) {
        console.error('Error deleting health checkup:', error);
        res.status(500).json({ error: 'Failed to delete health checkup' });
    }
};

// 受診期限が近いドライバー一覧
export const getCheckupsDue = async (req: Request, res: Response) => {
    try {
        const { companyId, daysAhead = 30 } = req.query;

        const result = await pool.query(
            `SELECT dr.driver_id, dr.full_name, u.employee_number,
                    hc.id as checkup_id, hc.checkup_date as last_checkup_date,
                    hc.next_checkup_date, hc.checkup_type,
                    (hc.next_checkup_date - CURRENT_DATE) as days_until_due
             FROM driver_registries dr
             JOIN users u ON dr.driver_id = u.id
             LEFT JOIN LATERAL (
                 SELECT * FROM health_checkup_records
                 WHERE driver_id = dr.driver_id
                 ORDER BY checkup_date DESC
                 LIMIT 1
             ) hc ON true
             WHERE dr.company_id = $1
               AND dr.status = 'active'
               AND (
                   hc.next_checkup_date IS NULL
                   OR hc.next_checkup_date <= CURRENT_DATE + INTERVAL '1 day' * $2
               )
             ORDER BY hc.next_checkup_date ASC NULLS FIRST`,
            [companyId, daysAhead]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching checkups due:', error);
        res.status(500).json({ error: 'Failed to fetch checkups due' });
    }
};

// ドライバーの健康診断履歴
export const getDriverHealthHistory = async (req: Request, res: Response) => {
    try {
        const { driverId } = req.params;

        const result = await pool.query(
            `SELECT hc.*,
                    CASE
                        WHEN hc.checkup_type = 'regular' THEN '定期健康診断'
                        WHEN hc.checkup_type = 'special' THEN '特殊健康診断'
                        WHEN hc.checkup_type = 'pre_employment' THEN '雇入時健康診断'
                        ELSE hc.checkup_type
                    END as checkup_type_name
             FROM health_checkup_records hc
             WHERE hc.driver_id = $1
             ORDER BY hc.checkup_date DESC`,
            [driverId]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching driver health history:', error);
        res.status(500).json({ error: 'Failed to fetch driver health history' });
    }
};
