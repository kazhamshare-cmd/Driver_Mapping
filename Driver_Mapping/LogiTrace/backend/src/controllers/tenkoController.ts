import { Request, Response } from 'express';
import { pool } from '../utils/db';

// 点呼記録作成
export const createTenko = async (req: Request, res: Response) => {
    try {
        const {
            company_id,
            driver_id,
            work_record_id,
            tenko_type,
            method,
            health_status,
            health_notes,
            alcohol_level,
            alcohol_device_id,
            fatigue_level,
            sleep_hours,
            sleep_sufficient,
            inspector_id,
            driver_signature,
            inspector_signature,
            notes
        } = req.body;

        // ドライバー名と点呼執行者名を取得
        const [driverResult, inspectorResult] = await Promise.all([
            pool.query('SELECT name FROM users WHERE id = $1', [driver_id]),
            pool.query('SELECT name FROM users WHERE id = $1', [inspector_id])
        ]);

        if (driverResult.rows.length === 0) {
            return res.status(400).json({ error: 'Driver not found' });
        }
        if (inspectorResult.rows.length === 0) {
            return res.status(400).json({ error: 'Inspector not found' });
        }

        const driver_name = driverResult.rows[0].name;
        const inspector_name = inspectorResult.rows[0].name;

        // アルコールチェック判定（0.000以外は不合格）
        const alcohol_check_passed = parseFloat(alcohol_level) === 0;

        const result = await pool.query(
            `INSERT INTO tenko_records (
                company_id, driver_id, work_record_id, tenko_type, tenko_date, tenko_time,
                method, health_status, health_notes, alcohol_level, alcohol_check_passed,
                alcohol_device_id, fatigue_level, sleep_hours, sleep_sufficient,
                inspector_id, inspector_name, driver_name, driver_signature, inspector_signature, notes
            ) VALUES (
                $1, $2, $3, $4, CURRENT_DATE, NOW(),
                $5, $6, $7, $8, $9,
                $10, $11, $12, $13,
                $14, $15, $16, $17, $18, $19
            ) RETURNING *`,
            [
                company_id, driver_id, work_record_id, tenko_type,
                method, health_status, health_notes, alcohol_level, alcohol_check_passed,
                alcohol_device_id, fatigue_level, sleep_hours, sleep_sufficient,
                inspector_id, inspector_name, driver_name, driver_signature, inspector_signature, notes
            ]
        );

        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error creating tenko record:', error);
        res.status(500).json({ error: 'Failed to create tenko record' });
    }
};

// 点呼記録一覧取得
export const getTenkoRecords = async (req: Request, res: Response) => {
    try {
        const { companyId, driverId, dateFrom, dateTo, tenkoType, limit = 100, offset = 0 } = req.query;

        let query = `
            SELECT t.*, u.email as driver_email
            FROM tenko_records t
            LEFT JOIN users u ON t.driver_id = u.id
            WHERE t.company_id = $1
        `;
        const params: any[] = [companyId];
        let paramIndex = 2;

        if (driverId) {
            query += ` AND t.driver_id = $${paramIndex}`;
            params.push(driverId);
            paramIndex++;
        }

        if (dateFrom) {
            query += ` AND t.tenko_date >= $${paramIndex}`;
            params.push(dateFrom);
            paramIndex++;
        }

        if (dateTo) {
            query += ` AND t.tenko_date <= $${paramIndex}`;
            params.push(dateTo);
            paramIndex++;
        }

        if (tenkoType) {
            query += ` AND t.tenko_type = $${paramIndex}`;
            params.push(tenkoType);
            paramIndex++;
        }

        query += ` ORDER BY t.tenko_date DESC, t.tenko_time DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
        params.push(limit, offset);

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching tenko records:', error);
        res.status(500).json({ error: 'Failed to fetch tenko records' });
    }
};

// 点呼記録詳細取得
export const getTenkoById = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        const result = await pool.query(
            `SELECT t.*, u.email as driver_email
             FROM tenko_records t
             LEFT JOIN users u ON t.driver_id = u.id
             WHERE t.id = $1`,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Tenko record not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching tenko record:', error);
        res.status(500).json({ error: 'Failed to fetch tenko record' });
    }
};

// 本日の点呼状況取得（ドライバー別）
export const getTodayTenkoStatus = async (req: Request, res: Response) => {
    try {
        const { driverId } = req.params;

        const result = await pool.query(
            `SELECT tenko_type, alcohol_check_passed, health_status, tenko_time
             FROM tenko_records
             WHERE driver_id = $1 AND tenko_date = CURRENT_DATE
             ORDER BY tenko_time ASC`,
            [driverId]
        );

        const preTenko = result.rows.find(r => r.tenko_type === 'pre');
        const postTenko = result.rows.find(r => r.tenko_type === 'post');

        res.json({
            preTenko: preTenko || null,
            postTenko: postTenko || null,
            preCompleted: !!preTenko,
            postCompleted: !!postTenko,
            canStartWork: preTenko?.alcohol_check_passed === true
        });
    } catch (error) {
        console.error('Error fetching today tenko status:', error);
        res.status(500).json({ error: 'Failed to fetch tenko status' });
    }
};

// 点呼未完了ドライバー一覧取得
export const getPendingTenko = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.query;

        // 今日の乗務前点呼が未完了のドライバー
        const result = await pool.query(
            `SELECT u.id, u.name, u.email, u.employee_number
             FROM users u
             WHERE u.company_id = $1
               AND u.user_type = 'driver'
               AND u.status = 'active'
               AND u.id NOT IN (
                   SELECT driver_id FROM tenko_records
                   WHERE tenko_date = CURRENT_DATE AND tenko_type = 'pre'
               )
             ORDER BY u.name`,
            [companyId]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching pending tenko:', error);
        res.status(500).json({ error: 'Failed to fetch pending tenko' });
    }
};

// 点呼記録更新
export const updateTenko = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const { notes } = req.body;

        // 点呼記録は基本的に更新不可（法的要件）
        // notesのみ更新可能
        const result = await pool.query(
            `UPDATE tenko_records
             SET notes = COALESCE($1, notes), updated_at = NOW()
             WHERE id = $2
             RETURNING *`,
            [notes, id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Tenko record not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating tenko record:', error);
        res.status(500).json({ error: 'Failed to update tenko record' });
    }
};

// 点呼記録削除（管理者のみ、監査ログ用に残すべき）
export const deleteTenko = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        // 実際には削除せず、論理削除フラグを立てるべきだが
        // 現在のスキーマにはフラグがないため物理削除
        const result = await pool.query(
            'DELETE FROM tenko_records WHERE id = $1 RETURNING id',
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Tenko record not found' });
        }

        res.json({ message: 'Tenko record deleted successfully' });
    } catch (error) {
        console.error('Error deleting tenko record:', error);
        res.status(500).json({ error: 'Failed to delete tenko record' });
    }
};
