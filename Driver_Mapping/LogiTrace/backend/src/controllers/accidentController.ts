import { Request, Response } from 'express';
import { pool } from '../utils/db';

// 事故・違反記録一覧取得
export const getAccidentRecords = async (req: Request, res: Response) => {
    try {
        const { companyId, driverId, recordType, severity, dateFrom, dateTo, limit = 100, offset = 0 } = req.query;

        let query = `
            SELECT avr.*, dr.full_name as driver_name, u.employee_number,
                   v.plate_number as vehicle_plate
            FROM accident_violation_records avr
            JOIN driver_registries dr ON avr.driver_id = dr.driver_id
            JOIN users u ON avr.driver_id = u.id
            LEFT JOIN vehicles v ON avr.vehicle_id = v.id
            WHERE avr.company_id = $1
        `;
        const params: any[] = [companyId];
        let paramIndex = 2;

        if (driverId) {
            query += ` AND avr.driver_id = $${paramIndex}`;
            params.push(driverId);
            paramIndex++;
        }

        if (recordType) {
            query += ` AND avr.record_type = $${paramIndex}`;
            params.push(recordType);
            paramIndex++;
        }

        if (severity) {
            query += ` AND avr.severity = $${paramIndex}`;
            params.push(severity);
            paramIndex++;
        }

        if (dateFrom) {
            query += ` AND avr.incident_date >= $${paramIndex}`;
            params.push(dateFrom);
            paramIndex++;
        }

        if (dateTo) {
            query += ` AND avr.incident_date <= $${paramIndex}`;
            params.push(dateTo);
            paramIndex++;
        }

        query += ` ORDER BY avr.incident_date DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
        params.push(limit, offset);

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching accident records:', error);
        res.status(500).json({ error: 'Failed to fetch accident records' });
    }
};

// 事故・違反記録詳細取得
export const getAccidentById = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        const result = await pool.query(
            `SELECT avr.*, dr.full_name as driver_name, u.employee_number,
                    v.plate_number as vehicle_plate, v.model as vehicle_model
             FROM accident_violation_records avr
             JOIN driver_registries dr ON avr.driver_id = dr.driver_id
             JOIN users u ON avr.driver_id = u.id
             LEFT JOIN vehicles v ON avr.vehicle_id = v.id
             WHERE avr.id = $1`,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Accident record not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching accident record:', error);
        res.status(500).json({ error: 'Failed to fetch accident record' });
    }
};

// 事故・違反記録作成
export const createAccident = async (req: Request, res: Response) => {
    try {
        const {
            company_id,
            driver_id,
            vehicle_id,
            record_type,
            incident_date,
            incident_time,
            location,
            description,
            severity,
            is_at_fault,
            // 違反の場合
            violation_type,
            violation_code,
            points_deducted,
            fine_amount,
            // 事故の場合
            accident_type,
            damage_amount,
            injury_count,
            fatality_count,
            police_report_number,
            insurance_claim_number,
            // 対応
            corrective_action,
            follow_up_training_required,
            documents
        } = req.body;

        const result = await pool.query(
            `INSERT INTO accident_violation_records (
                company_id, driver_id, vehicle_id, record_type, incident_date, incident_time,
                location, description, severity, is_at_fault,
                violation_type, violation_code, points_deducted, fine_amount,
                accident_type, damage_amount, injury_count, fatality_count,
                police_report_number, insurance_claim_number,
                corrective_action, follow_up_training_required, documents
            ) VALUES (
                $1, $2, $3, $4, $5, $6,
                $7, $8, $9, $10,
                $11, $12, $13, $14,
                $15, $16, $17, $18,
                $19, $20,
                $21, $22, $23
            ) RETURNING *`,
            [
                company_id, driver_id, vehicle_id, record_type, incident_date, incident_time,
                location, description, severity, is_at_fault,
                violation_type, violation_code, points_deducted, fine_amount,
                accident_type, damage_amount, injury_count, fatality_count || 0,
                police_report_number, insurance_claim_number,
                corrective_action, follow_up_training_required || false,
                documents ? JSON.stringify(documents) : null
            ]
        );

        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error creating accident record:', error);
        res.status(500).json({ error: 'Failed to create accident record' });
    }
};

// 事故・違反記録更新
export const updateAccident = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const {
            vehicle_id,
            incident_date,
            incident_time,
            location,
            description,
            severity,
            is_at_fault,
            violation_type,
            violation_code,
            points_deducted,
            fine_amount,
            accident_type,
            damage_amount,
            injury_count,
            fatality_count,
            police_report_number,
            insurance_claim_number,
            corrective_action,
            follow_up_training_required,
            follow_up_training_completed,
            follow_up_training_date,
            documents
        } = req.body;

        const result = await pool.query(
            `UPDATE accident_violation_records SET
                vehicle_id = $1,
                incident_date = COALESCE($2, incident_date),
                incident_time = $3,
                location = $4,
                description = COALESCE($5, description),
                severity = $6,
                is_at_fault = $7,
                violation_type = $8,
                violation_code = $9,
                points_deducted = $10,
                fine_amount = $11,
                accident_type = $12,
                damage_amount = $13,
                injury_count = $14,
                fatality_count = $15,
                police_report_number = $16,
                insurance_claim_number = $17,
                corrective_action = $18,
                follow_up_training_required = COALESCE($19, follow_up_training_required),
                follow_up_training_completed = COALESCE($20, follow_up_training_completed),
                follow_up_training_date = $21,
                documents = COALESCE($22, documents),
                updated_at = NOW()
             WHERE id = $23
             RETURNING *`,
            [
                vehicle_id, incident_date, incident_time, location, description,
                severity, is_at_fault, violation_type, violation_code,
                points_deducted, fine_amount, accident_type, damage_amount,
                injury_count, fatality_count, police_report_number,
                insurance_claim_number, corrective_action,
                follow_up_training_required, follow_up_training_completed,
                follow_up_training_date, documents ? JSON.stringify(documents) : null, id
            ]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Accident record not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating accident record:', error);
        res.status(500).json({ error: 'Failed to update accident record' });
    }
};

// 事故・違反記録削除
export const deleteAccident = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        const result = await pool.query(
            'DELETE FROM accident_violation_records WHERE id = $1 RETURNING id',
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Accident record not found' });
        }

        res.json({ message: 'Accident record deleted successfully' });
    } catch (error) {
        console.error('Error deleting accident record:', error);
        res.status(500).json({ error: 'Failed to delete accident record' });
    }
};

// 統計情報取得
export const getAccidentStatistics = async (req: Request, res: Response) => {
    try {
        const { companyId, year } = req.query;
        const targetYear = year || new Date().getFullYear();

        // 月別集計
        const monthlyStats = await pool.query(
            `SELECT
                EXTRACT(MONTH FROM incident_date) as month,
                record_type,
                COUNT(*) as count,
                SUM(CASE WHEN record_type = 'accident' THEN damage_amount ELSE 0 END) as total_damage,
                SUM(CASE WHEN record_type = 'violation' THEN fine_amount ELSE 0 END) as total_fines
             FROM accident_violation_records
             WHERE company_id = $1
               AND EXTRACT(YEAR FROM incident_date) = $2
             GROUP BY EXTRACT(MONTH FROM incident_date), record_type
             ORDER BY month, record_type`,
            [companyId, targetYear]
        );

        // 重大度別集計
        const severityStats = await pool.query(
            `SELECT
                severity,
                record_type,
                COUNT(*) as count
             FROM accident_violation_records
             WHERE company_id = $1
               AND EXTRACT(YEAR FROM incident_date) = $2
             GROUP BY severity, record_type
             ORDER BY severity`,
            [companyId, targetYear]
        );

        // ドライバー別集計
        const driverStats = await pool.query(
            `SELECT
                avr.driver_id,
                dr.full_name as driver_name,
                COUNT(*) as total_count,
                SUM(CASE WHEN avr.record_type = 'accident' THEN 1 ELSE 0 END) as accident_count,
                SUM(CASE WHEN avr.record_type = 'violation' THEN 1 ELSE 0 END) as violation_count
             FROM accident_violation_records avr
             JOIN driver_registries dr ON avr.driver_id = dr.driver_id
             WHERE avr.company_id = $1
               AND EXTRACT(YEAR FROM avr.incident_date) = $2
             GROUP BY avr.driver_id, dr.full_name
             ORDER BY total_count DESC
             LIMIT 10`,
            [companyId, targetYear]
        );

        // 年間サマリー
        const yearSummary = await pool.query(
            `SELECT
                COUNT(*) as total_incidents,
                SUM(CASE WHEN record_type = 'accident' THEN 1 ELSE 0 END) as total_accidents,
                SUM(CASE WHEN record_type = 'violation' THEN 1 ELSE 0 END) as total_violations,
                SUM(damage_amount) as total_damage,
                SUM(fine_amount) as total_fines,
                SUM(injury_count) as total_injuries,
                SUM(fatality_count) as total_fatalities
             FROM accident_violation_records
             WHERE company_id = $1
               AND EXTRACT(YEAR FROM incident_date) = $2`,
            [companyId, targetYear]
        );

        res.json({
            year: targetYear,
            summary: yearSummary.rows[0],
            monthlyStats: monthlyStats.rows,
            severityStats: severityStats.rows,
            driverStats: driverStats.rows
        });
    } catch (error) {
        console.error('Error fetching accident statistics:', error);
        res.status(500).json({ error: 'Failed to fetch accident statistics' });
    }
};

// ドライバーの事故・違反履歴
export const getDriverAccidentHistory = async (req: Request, res: Response) => {
    try {
        const { driverId } = req.params;

        const result = await pool.query(
            `SELECT avr.*, v.plate_number as vehicle_plate
             FROM accident_violation_records avr
             LEFT JOIN vehicles v ON avr.vehicle_id = v.id
             WHERE avr.driver_id = $1
             ORDER BY avr.incident_date DESC`,
            [driverId]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching driver accident history:', error);
        res.status(500).json({ error: 'Failed to fetch driver accident history' });
    }
};

// フォローアップ研修が必要なドライバー一覧
export const getFollowUpRequired = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.query;

        const result = await pool.query(
            `SELECT avr.*, dr.full_name as driver_name, u.employee_number
             FROM accident_violation_records avr
             JOIN driver_registries dr ON avr.driver_id = dr.driver_id
             JOIN users u ON avr.driver_id = u.id
             WHERE avr.company_id = $1
               AND avr.follow_up_training_required = TRUE
               AND avr.follow_up_training_completed = FALSE
             ORDER BY avr.incident_date DESC`,
            [companyId]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching follow-up required:', error);
        res.status(500).json({ error: 'Failed to fetch follow-up required' });
    }
};
