import { Request, Response } from 'express';
import { pool } from '../utils/db';

// 運転者台帳一覧取得
export const getDriverRegistries = async (req: Request, res: Response) => {
    try {
        const { companyId, status, licenseExpiringSoon, limit = 100, offset = 0 } = req.query;

        let query = `
            SELECT dr.*, u.email as driver_email, u.employee_number
            FROM driver_registries dr
            JOIN users u ON dr.driver_id = u.id
            WHERE dr.company_id = $1
        `;
        const params: any[] = [companyId];
        let paramIndex = 2;

        if (status) {
            query += ` AND dr.status = $${paramIndex}`;
            params.push(status);
            paramIndex++;
        }

        // 免許有効期限が30日以内のドライバーをフィルタ
        if (licenseExpiringSoon === 'true') {
            query += ` AND dr.license_expiry_date <= CURRENT_DATE + INTERVAL '30 days'`;
        }

        query += ` ORDER BY dr.full_name LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
        params.push(limit, offset);

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching driver registries:', error);
        res.status(500).json({ error: 'Failed to fetch driver registries' });
    }
};

// 運転者台帳詳細取得
export const getDriverRegistryById = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        const result = await pool.query(
            `SELECT dr.*, u.email as driver_email, u.employee_number
             FROM driver_registries dr
             JOIN users u ON dr.driver_id = u.id
             WHERE dr.id = $1`,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Driver registry not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching driver registry:', error);
        res.status(500).json({ error: 'Failed to fetch driver registry' });
    }
};

// ドライバーIDで運転者台帳取得
export const getDriverRegistryByDriverId = async (req: Request, res: Response) => {
    try {
        const { driverId } = req.params;

        const result = await pool.query(
            `SELECT dr.*, u.email as driver_email, u.employee_number
             FROM driver_registries dr
             JOIN users u ON dr.driver_id = u.id
             WHERE dr.driver_id = $1`,
            [driverId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Driver registry not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching driver registry:', error);
        res.status(500).json({ error: 'Failed to fetch driver registry' });
    }
};

// 自分の運転者台帳取得（モバイルアプリ用）
export const getMyDriverRegistry = async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user?.id;

        if (!userId) {
            return res.status(401).json({ error: 'User not authenticated' });
        }

        const result = await pool.query(
            `SELECT dr.*, u.email as driver_email, u.employee_number
             FROM driver_registries dr
             JOIN users u ON dr.driver_id = u.id
             WHERE dr.driver_id = $1`,
            [userId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Driver registry not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching my driver registry:', error);
        res.status(500).json({ error: 'Failed to fetch driver registry' });
    }
};

// 運転者台帳作成
export const createDriverRegistry = async (req: Request, res: Response) => {
    try {
        const {
            company_id,
            driver_id,
            full_name,
            full_name_kana,
            birth_date,
            address,
            phone,
            emergency_contact,
            emergency_phone,
            hire_date,
            license_number,
            license_type,
            license_expiry_date,
            license_conditions,
            license_image_url,
            hazmat_license,
            hazmat_expiry_date,
            forklift_license,
            second_class_license,
            other_qualifications,
            notes
        } = req.body;

        const result = await pool.query(
            `INSERT INTO driver_registries (
                company_id, driver_id, full_name, full_name_kana, birth_date,
                address, phone, emergency_contact, emergency_phone, hire_date,
                license_number, license_type, license_expiry_date, license_conditions, license_image_url,
                hazmat_license, hazmat_expiry_date, forklift_license, second_class_license,
                other_qualifications, notes
            ) VALUES (
                $1, $2, $3, $4, $5,
                $6, $7, $8, $9, $10,
                $11, $12, $13, $14, $15,
                $16, $17, $18, $19,
                $20, $21
            ) RETURNING *`,
            [
                company_id, driver_id, full_name, full_name_kana, birth_date,
                address, phone, emergency_contact, emergency_phone, hire_date,
                license_number, license_type, license_expiry_date, license_conditions, license_image_url,
                hazmat_license || false, hazmat_expiry_date, forklift_license || false, second_class_license || false,
                other_qualifications ? JSON.stringify(other_qualifications) : null, notes
            ]
        );

        res.status(201).json(result.rows[0]);
    } catch (error: any) {
        console.error('Error creating driver registry:', error);
        if (error.code === '23505') { // Unique violation
            return res.status(400).json({ error: 'Driver registry already exists for this driver' });
        }
        res.status(500).json({ error: 'Failed to create driver registry' });
    }
};

// 運転者台帳更新
export const updateDriverRegistry = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const {
            full_name,
            full_name_kana,
            birth_date,
            address,
            phone,
            emergency_contact,
            emergency_phone,
            termination_date,
            license_number,
            license_type,
            license_expiry_date,
            license_conditions,
            license_image_url,
            hazmat_license,
            hazmat_expiry_date,
            forklift_license,
            second_class_license,
            other_qualifications,
            status,
            notes
        } = req.body;

        const result = await pool.query(
            `UPDATE driver_registries SET
                full_name = COALESCE($1, full_name),
                full_name_kana = COALESCE($2, full_name_kana),
                birth_date = COALESCE($3, birth_date),
                address = COALESCE($4, address),
                phone = COALESCE($5, phone),
                emergency_contact = COALESCE($6, emergency_contact),
                emergency_phone = COALESCE($7, emergency_phone),
                termination_date = $8,
                license_number = COALESCE($9, license_number),
                license_type = COALESCE($10, license_type),
                license_expiry_date = COALESCE($11, license_expiry_date),
                license_conditions = $12,
                license_image_url = $13,
                hazmat_license = COALESCE($14, hazmat_license),
                hazmat_expiry_date = $15,
                forklift_license = COALESCE($16, forklift_license),
                second_class_license = COALESCE($17, second_class_license),
                other_qualifications = COALESCE($18, other_qualifications),
                status = COALESCE($19, status),
                notes = $20,
                updated_at = NOW()
             WHERE id = $21
             RETURNING *`,
            [
                full_name, full_name_kana, birth_date, address, phone,
                emergency_contact, emergency_phone, termination_date,
                license_number, license_type, license_expiry_date, license_conditions, license_image_url,
                hazmat_license, hazmat_expiry_date, forklift_license, second_class_license,
                other_qualifications ? JSON.stringify(other_qualifications) : null,
                status, notes, id
            ]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Driver registry not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating driver registry:', error);
        res.status(500).json({ error: 'Failed to update driver registry' });
    }
};

// 運転者台帳削除
export const deleteDriverRegistry = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        const result = await pool.query(
            'DELETE FROM driver_registries WHERE id = $1 RETURNING id',
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Driver registry not found' });
        }

        res.json({ message: 'Driver registry deleted successfully' });
    } catch (error) {
        console.error('Error deleting driver registry:', error);
        res.status(500).json({ error: 'Failed to delete driver registry' });
    }
};

// 期限切れ間近の免許一覧
export const getExpiringLicenses = async (req: Request, res: Response) => {
    try {
        const { companyId, daysAhead = 30 } = req.query;

        const result = await pool.query(
            `SELECT dr.*, u.email as driver_email, u.employee_number,
                    (dr.license_expiry_date - CURRENT_DATE) as days_remaining
             FROM driver_registries dr
             JOIN users u ON dr.driver_id = u.id
             WHERE dr.company_id = $1
               AND dr.status = 'active'
               AND dr.license_expiry_date <= CURRENT_DATE + INTERVAL '1 day' * $2
             ORDER BY dr.license_expiry_date ASC`,
            [companyId, daysAhead]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching expiring licenses:', error);
        res.status(500).json({ error: 'Failed to fetch expiring licenses' });
    }
};

// ドライバーのコンプライアンス状況チェック（点呼時使用）
export const checkDriverCompliance = async (req: Request, res: Response) => {
    try {
        const { driverId } = req.params;

        // 運転者台帳情報
        const registryResult = await pool.query(
            `SELECT dr.*,
                    (dr.license_expiry_date - CURRENT_DATE) as license_days_remaining
             FROM driver_registries dr
             WHERE dr.driver_id = $1`,
            [driverId]
        );

        if (registryResult.rows.length === 0) {
            return res.status(404).json({ error: 'Driver registry not found' });
        }

        const registry = registryResult.rows[0];

        // 最新の健康診断
        const healthResult = await pool.query(
            `SELECT checkup_date, next_checkup_date, overall_result,
                    (next_checkup_date - CURRENT_DATE) as days_until_next
             FROM health_checkup_records
             WHERE driver_id = $1
             ORDER BY checkup_date DESC
             LIMIT 1`,
            [driverId]
        );

        // 最新の適性診断
        const aptitudeResult = await pool.query(
            `SELECT test_date, next_test_date, test_type,
                    (next_test_date - CURRENT_DATE) as days_until_next
             FROM aptitude_test_records
             WHERE driver_id = $1
             ORDER BY test_date DESC
             LIMIT 1`,
            [driverId]
        );

        const compliance = {
            driverId: parseInt(driverId as string),
            driverName: registry.full_name,
            license: {
                expiryDate: registry.license_expiry_date,
                daysRemaining: registry.license_days_remaining,
                isExpired: registry.license_days_remaining < 0,
                isExpiringSoon: registry.license_days_remaining <= 30
            },
            healthCheckup: healthResult.rows.length > 0 ? {
                lastCheckup: healthResult.rows[0].checkup_date,
                nextDue: healthResult.rows[0].next_checkup_date,
                result: healthResult.rows[0].overall_result,
                daysUntilNext: healthResult.rows[0].days_until_next,
                isOverdue: healthResult.rows[0].days_until_next < 0
            } : null,
            aptitudeTest: aptitudeResult.rows.length > 0 ? {
                lastTest: aptitudeResult.rows[0].test_date,
                nextDue: aptitudeResult.rows[0].next_test_date,
                type: aptitudeResult.rows[0].test_type,
                daysUntilNext: aptitudeResult.rows[0].days_until_next,
                isOverdue: aptitudeResult.rows[0].days_until_next < 0
            } : null,
            canOperate: registry.license_days_remaining >= 0 && registry.status === 'active'
        };

        res.json(compliance);
    } catch (error) {
        console.error('Error checking driver compliance:', error);
        res.status(500).json({ error: 'Failed to check driver compliance' });
    }
};
