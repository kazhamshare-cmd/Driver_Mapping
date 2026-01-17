import { Request, Response } from 'express';
import { pool } from '../utils/db';

// 適性診断記録一覧取得
export const getAptitudeTests = async (req: Request, res: Response) => {
    try {
        const { companyId, driverId, testType, dateFrom, dateTo, limit = 100, offset = 0 } = req.query;

        let query = `
            SELECT at.*, dr.full_name as driver_name, u.employee_number,
                   dr.birth_date,
                   EXTRACT(YEAR FROM AGE(CURRENT_DATE, dr.birth_date)) as driver_age
            FROM aptitude_test_records at
            JOIN driver_registries dr ON at.driver_id = dr.driver_id
            JOIN users u ON at.driver_id = u.id
            WHERE at.company_id = $1
        `;
        const params: any[] = [companyId];
        let paramIndex = 2;

        if (driverId) {
            query += ` AND at.driver_id = $${paramIndex}`;
            params.push(driverId);
            paramIndex++;
        }

        if (testType) {
            query += ` AND at.test_type = $${paramIndex}`;
            params.push(testType);
            paramIndex++;
        }

        if (dateFrom) {
            query += ` AND at.test_date >= $${paramIndex}`;
            params.push(dateFrom);
            paramIndex++;
        }

        if (dateTo) {
            query += ` AND at.test_date <= $${paramIndex}`;
            params.push(dateTo);
            paramIndex++;
        }

        query += ` ORDER BY at.test_date DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
        params.push(limit, offset);

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching aptitude tests:', error);
        res.status(500).json({ error: 'Failed to fetch aptitude tests' });
    }
};

// 適性診断記録詳細取得
export const getAptitudeTestById = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        const result = await pool.query(
            `SELECT at.*, dr.full_name as driver_name, u.employee_number
             FROM aptitude_test_records at
             JOIN driver_registries dr ON at.driver_id = dr.driver_id
             JOIN users u ON at.driver_id = u.id
             WHERE at.id = $1`,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Aptitude test record not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching aptitude test:', error);
        res.status(500).json({ error: 'Failed to fetch aptitude test' });
    }
};

// 適性診断記録作成
export const createAptitudeTest = async (req: Request, res: Response) => {
    try {
        const {
            company_id,
            driver_id,
            test_type,
            test_date,
            next_test_date,
            facility_name,
            overall_score,
            result_summary,
            recommendations,
            certificate_url
        } = req.body;

        const result = await pool.query(
            `INSERT INTO aptitude_test_records (
                company_id, driver_id, test_type, test_date, next_test_date,
                facility_name, overall_score, result_summary, recommendations, certificate_url
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
             RETURNING *`,
            [
                company_id, driver_id, test_type, test_date, next_test_date,
                facility_name, overall_score, result_summary, recommendations, certificate_url
            ]
        );

        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error creating aptitude test:', error);
        res.status(500).json({ error: 'Failed to create aptitude test' });
    }
};

// 適性診断記録更新
export const updateAptitudeTest = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const {
            test_type,
            test_date,
            next_test_date,
            facility_name,
            overall_score,
            result_summary,
            recommendations,
            certificate_url
        } = req.body;

        const result = await pool.query(
            `UPDATE aptitude_test_records SET
                test_type = COALESCE($1, test_type),
                test_date = COALESCE($2, test_date),
                next_test_date = $3,
                facility_name = COALESCE($4, facility_name),
                overall_score = $5,
                result_summary = $6,
                recommendations = $7,
                certificate_url = $8
             WHERE id = $9
             RETURNING *`,
            [
                test_type, test_date, next_test_date, facility_name,
                overall_score, result_summary, recommendations, certificate_url, id
            ]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Aptitude test record not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating aptitude test:', error);
        res.status(500).json({ error: 'Failed to update aptitude test' });
    }
};

// 適性診断記録削除
export const deleteAptitudeTest = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        const result = await pool.query(
            'DELETE FROM aptitude_test_records WHERE id = $1 RETURNING id',
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Aptitude test record not found' });
        }

        res.json({ message: 'Aptitude test record deleted successfully' });
    } catch (error) {
        console.error('Error deleting aptitude test:', error);
        res.status(500).json({ error: 'Failed to delete aptitude test' });
    }
};

// 要受診者一覧（初任・適齢・特定）
export const getTestsRequired = async (req: Request, res: Response) => {
    try {
        const { companyId, daysAhead = 30 } = req.query;

        // 初任診断が必要（新規採用で未受診）
        const initialRequired = await pool.query(
            `SELECT dr.driver_id, dr.full_name, u.employee_number, dr.hire_date,
                    'initial' as required_type, '初任診断' as required_type_name
             FROM driver_registries dr
             JOIN users u ON dr.driver_id = u.id
             WHERE dr.company_id = $1
               AND dr.status = 'active'
               AND NOT EXISTS (
                   SELECT 1 FROM aptitude_test_records
                   WHERE driver_id = dr.driver_id AND test_type = 'initial'
               )`,
            [companyId]
        );

        // 適齢診断が必要（65歳以上で3年以内未受診）
        const ageBasedRequired = await pool.query(
            `SELECT dr.driver_id, dr.full_name, u.employee_number, dr.birth_date,
                    EXTRACT(YEAR FROM AGE(CURRENT_DATE, dr.birth_date)) as age,
                    'age_based' as required_type, '適齢診断' as required_type_name,
                    at.test_date as last_test_date
             FROM driver_registries dr
             JOIN users u ON dr.driver_id = u.id
             LEFT JOIN LATERAL (
                 SELECT test_date FROM aptitude_test_records
                 WHERE driver_id = dr.driver_id AND test_type = 'age_based'
                 ORDER BY test_date DESC
                 LIMIT 1
             ) at ON true
             WHERE dr.company_id = $1
               AND dr.status = 'active'
               AND EXTRACT(YEAR FROM AGE(CURRENT_DATE, dr.birth_date)) >= 65
               AND (
                   at.test_date IS NULL
                   OR at.test_date < CURRENT_DATE - INTERVAL '3 years'
               )`,
            [companyId]
        );

        // 次回受診期限が近いドライバー
        const upcomingTests = await pool.query(
            `SELECT dr.driver_id, dr.full_name, u.employee_number,
                    at.test_type, at.test_date as last_test_date,
                    at.next_test_date,
                    (at.next_test_date - CURRENT_DATE) as days_until_due,
                    CASE
                        WHEN at.test_type = 'initial' THEN '初任診断'
                        WHEN at.test_type = 'age_based' THEN '適齢診断'
                        WHEN at.test_type = 'specific' THEN '特定診断'
                        WHEN at.test_type = 'voluntary' THEN '一般診断'
                        ELSE at.test_type
                    END as test_type_name
             FROM driver_registries dr
             JOIN users u ON dr.driver_id = u.id
             JOIN LATERAL (
                 SELECT * FROM aptitude_test_records
                 WHERE driver_id = dr.driver_id
                 ORDER BY test_date DESC
                 LIMIT 1
             ) at ON true
             WHERE dr.company_id = $1
               AND dr.status = 'active'
               AND at.next_test_date IS NOT NULL
               AND at.next_test_date <= CURRENT_DATE + INTERVAL '1 day' * $2
             ORDER BY at.next_test_date ASC`,
            [companyId, daysAhead]
        );

        res.json({
            initialRequired: initialRequired.rows,
            ageBasedRequired: ageBasedRequired.rows,
            upcomingTests: upcomingTests.rows
        });
    } catch (error) {
        console.error('Error fetching tests required:', error);
        res.status(500).json({ error: 'Failed to fetch tests required' });
    }
};

// ドライバーの適性診断履歴
export const getDriverAptitudeHistory = async (req: Request, res: Response) => {
    try {
        const { driverId } = req.params;

        const result = await pool.query(
            `SELECT at.*,
                    CASE
                        WHEN at.test_type = 'initial' THEN '初任診断'
                        WHEN at.test_type = 'age_based' THEN '適齢診断'
                        WHEN at.test_type = 'specific' THEN '特定診断'
                        WHEN at.test_type = 'voluntary' THEN '一般診断'
                        ELSE at.test_type
                    END as test_type_name
             FROM aptitude_test_records at
             WHERE at.driver_id = $1
             ORDER BY at.test_date DESC`,
            [driverId]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching driver aptitude history:', error);
        res.status(500).json({ error: 'Failed to fetch driver aptitude history' });
    }
};
