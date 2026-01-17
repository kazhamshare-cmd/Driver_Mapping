import { Request, Response } from 'express';
import { pool } from '../utils/db';

// 研修記録一覧取得
export const getTrainingRecords = async (req: Request, res: Response) => {
    try {
        const { companyId, driverId, trainingType, status, dateFrom, dateTo, limit = 100, offset = 0 } = req.query;

        let query = `
            SELECT tr.*, dr.full_name as driver_name, u.employee_number,
                   ttm.name_ja as training_type_name
            FROM training_records tr
            JOIN driver_registries dr ON tr.driver_id = dr.driver_id
            JOIN users u ON tr.driver_id = u.id
            LEFT JOIN training_type_master ttm ON tr.training_type = ttm.code
            WHERE tr.company_id = $1
        `;
        const params: any[] = [companyId];
        let paramIndex = 2;

        if (driverId) {
            query += ` AND tr.driver_id = $${paramIndex}`;
            params.push(driverId);
            paramIndex++;
        }

        if (trainingType) {
            query += ` AND tr.training_type = $${paramIndex}`;
            params.push(trainingType);
            paramIndex++;
        }

        if (status) {
            query += ` AND tr.completion_status = $${paramIndex}`;
            params.push(status);
            paramIndex++;
        }

        if (dateFrom) {
            query += ` AND tr.training_date >= $${paramIndex}`;
            params.push(dateFrom);
            paramIndex++;
        }

        if (dateTo) {
            query += ` AND tr.training_date <= $${paramIndex}`;
            params.push(dateTo);
            paramIndex++;
        }

        query += ` ORDER BY tr.training_date DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
        params.push(limit, offset);

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching training records:', error);
        res.status(500).json({ error: 'Failed to fetch training records' });
    }
};

// 研修記録詳細取得
export const getTrainingById = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        const result = await pool.query(
            `SELECT tr.*, dr.full_name as driver_name, u.employee_number,
                    ttm.name_ja as training_type_name
             FROM training_records tr
             JOIN driver_registries dr ON tr.driver_id = dr.driver_id
             JOIN users u ON tr.driver_id = u.id
             LEFT JOIN training_type_master ttm ON tr.training_type = ttm.code
             WHERE tr.id = $1`,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Training record not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching training record:', error);
        res.status(500).json({ error: 'Failed to fetch training record' });
    }
};

// 研修記録作成
export const createTraining = async (req: Request, res: Response) => {
    try {
        const {
            company_id,
            driver_id,
            training_type,
            training_name,
            training_date,
            duration_hours,
            instructor_name,
            location,
            content_summary,
            materials_used,
            completion_status,
            test_score,
            certificate_url
        } = req.body;

        const result = await pool.query(
            `INSERT INTO training_records (
                company_id, driver_id, training_type, training_name, training_date,
                duration_hours, instructor_name, location, content_summary, materials_used,
                completion_status, test_score, certificate_url
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
             RETURNING *`,
            [
                company_id, driver_id, training_type, training_name, training_date,
                duration_hours, instructor_name, location, content_summary, materials_used,
                completion_status || 'completed', test_score, certificate_url
            ]
        );

        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error creating training record:', error);
        res.status(500).json({ error: 'Failed to create training record' });
    }
};

// 研修記録更新
export const updateTraining = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const {
            training_type,
            training_name,
            training_date,
            duration_hours,
            instructor_name,
            location,
            content_summary,
            materials_used,
            completion_status,
            test_score,
            certificate_url
        } = req.body;

        const result = await pool.query(
            `UPDATE training_records SET
                training_type = COALESCE($1, training_type),
                training_name = COALESCE($2, training_name),
                training_date = COALESCE($3, training_date),
                duration_hours = $4,
                instructor_name = $5,
                location = $6,
                content_summary = $7,
                materials_used = $8,
                completion_status = COALESCE($9, completion_status),
                test_score = $10,
                certificate_url = $11
             WHERE id = $12
             RETURNING *`,
            [
                training_type, training_name, training_date, duration_hours,
                instructor_name, location, content_summary, materials_used,
                completion_status, test_score, certificate_url, id
            ]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Training record not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating training record:', error);
        res.status(500).json({ error: 'Failed to update training record' });
    }
};

// 研修記録削除
export const deleteTraining = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        const result = await pool.query(
            'DELETE FROM training_records WHERE id = $1 RETURNING id',
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Training record not found' });
        }

        res.json({ message: 'Training record deleted successfully' });
    } catch (error) {
        console.error('Error deleting training record:', error);
        res.status(500).json({ error: 'Failed to delete training record' });
    }
};

// 研修種別マスタ取得
export const getTrainingTypes = async (req: Request, res: Response) => {
    try {
        const result = await pool.query(
            `SELECT id, code, name_ja, name_en, description, is_mandatory, frequency_months, display_order
             FROM training_type_master
             ORDER BY display_order, name_ja`
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching training types:', error);
        res.status(500).json({ error: 'Failed to fetch training types' });
    }
};

// 予定一覧（未完了の研修）
export const getScheduledTrainings = async (req: Request, res: Response) => {
    try {
        const { companyId, dateFrom, dateTo } = req.query;

        let query = `
            SELECT tr.*, dr.full_name as driver_name, u.employee_number,
                   ttm.name_ja as training_type_name
            FROM training_records tr
            JOIN driver_registries dr ON tr.driver_id = dr.driver_id
            JOIN users u ON tr.driver_id = u.id
            LEFT JOIN training_type_master ttm ON tr.training_type = ttm.code
            WHERE tr.company_id = $1
              AND tr.completion_status = 'scheduled'
        `;
        const params: any[] = [companyId];
        let paramIndex = 2;

        if (dateFrom) {
            query += ` AND tr.training_date >= $${paramIndex}`;
            params.push(dateFrom);
            paramIndex++;
        }

        if (dateTo) {
            query += ` AND tr.training_date <= $${paramIndex}`;
            params.push(dateTo);
            paramIndex++;
        }

        query += ` ORDER BY tr.training_date ASC`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching scheduled trainings:', error);
        res.status(500).json({ error: 'Failed to fetch scheduled trainings' });
    }
};

// ドライバーの研修履歴
export const getDriverTrainingHistory = async (req: Request, res: Response) => {
    try {
        const { driverId } = req.params;

        const result = await pool.query(
            `SELECT tr.*, ttm.name_ja as training_type_name
             FROM training_records tr
             LEFT JOIN training_type_master ttm ON tr.training_type = ttm.code
             WHERE tr.driver_id = $1
             ORDER BY tr.training_date DESC`,
            [driverId]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching driver training history:', error);
        res.status(500).json({ error: 'Failed to fetch driver training history' });
    }
};

// 研修統計
export const getTrainingStatistics = async (req: Request, res: Response) => {
    try {
        const { companyId, year } = req.query;
        const targetYear = year || new Date().getFullYear();

        // 月別研修実施数
        const monthlyStats = await pool.query(
            `SELECT
                EXTRACT(MONTH FROM training_date) as month,
                COUNT(*) as total_count,
                SUM(duration_hours) as total_hours,
                COUNT(DISTINCT driver_id) as unique_drivers
             FROM training_records
             WHERE company_id = $1
               AND EXTRACT(YEAR FROM training_date) = $2
               AND completion_status = 'completed'
             GROUP BY EXTRACT(MONTH FROM training_date)
             ORDER BY month`,
            [companyId, targetYear]
        );

        // 研修種別別統計
        const typeStats = await pool.query(
            `SELECT
                tr.training_type,
                ttm.name_ja as training_type_name,
                COUNT(*) as total_count,
                COUNT(DISTINCT tr.driver_id) as unique_drivers
             FROM training_records tr
             LEFT JOIN training_type_master ttm ON tr.training_type = ttm.code
             WHERE tr.company_id = $1
               AND EXTRACT(YEAR FROM tr.training_date) = $2
               AND tr.completion_status = 'completed'
             GROUP BY tr.training_type, ttm.name_ja
             ORDER BY total_count DESC`,
            [companyId, targetYear]
        );

        res.json({
            year: targetYear,
            monthlyStats: monthlyStats.rows,
            typeStats: typeStats.rows
        });
    } catch (error) {
        console.error('Error fetching training statistics:', error);
        res.status(500).json({ error: 'Failed to fetch training statistics' });
    }
};
