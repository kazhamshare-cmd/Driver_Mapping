/**
 * Trailer Management Controller
 * トレーラー管理（トラクタヘッド・シャーシ・連結記録）
 */

import { Request, Response } from 'express';
import { pool } from '../index';

// ============================================
// トラクタヘッド管理
// ============================================

// トラクタヘッド一覧取得
export const getTractorHeads = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.query;
        const result = await pool.query(
            `SELECT th.*, v.vehicle_number as linked_vehicle_number,
                    c.chassis_number as current_chassis_number
             FROM tractor_heads th
             LEFT JOIN vehicles v ON th.vehicle_id = v.id
             LEFT JOIN chassis c ON th.current_chassis_id = c.id
             WHERE th.company_id = $1
             ORDER BY th.tractor_number`,
            [companyId]
        );
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching tractor heads:', error);
        res.status(500).json({ error: 'トラクタヘッド一覧の取得に失敗しました' });
    }
};

// トラクタヘッド詳細取得
export const getTractorHeadById = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const result = await pool.query(
            `SELECT th.*, v.vehicle_number as linked_vehicle_number,
                    c.chassis_number as current_chassis_number, c.chassis_type as current_chassis_type
             FROM tractor_heads th
             LEFT JOIN vehicles v ON th.vehicle_id = v.id
             LEFT JOIN chassis c ON th.current_chassis_id = c.id
             WHERE th.id = $1`,
            [id]
        );
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'トラクタヘッドが見つかりません' });
        }
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching tractor head:', error);
        res.status(500).json({ error: 'トラクタヘッドの取得に失敗しました' });
    }
};

// トラクタヘッド登録
export const createTractorHead = async (req: Request, res: Response) => {
    try {
        const {
            company_id, vehicle_id, tractor_number, chassis_type,
            fifth_wheel_height, max_towing_weight, coupling_type, notes
        } = req.body;

        const result = await pool.query(
            `INSERT INTO tractor_heads (
                company_id, vehicle_id, tractor_number, chassis_type,
                fifth_wheel_height, max_towing_weight, coupling_type, notes
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            RETURNING *`,
            [company_id, vehicle_id, tractor_number, chassis_type,
             fifth_wheel_height, max_towing_weight, coupling_type, notes]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error creating tractor head:', error);
        res.status(500).json({ error: 'トラクタヘッドの登録に失敗しました' });
    }
};

// トラクタヘッド更新
export const updateTractorHead = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const {
            vehicle_id, tractor_number, chassis_type,
            fifth_wheel_height, max_towing_weight, coupling_type, status, notes
        } = req.body;

        const result = await pool.query(
            `UPDATE tractor_heads SET
                vehicle_id = COALESCE($1, vehicle_id),
                tractor_number = COALESCE($2, tractor_number),
                chassis_type = COALESCE($3, chassis_type),
                fifth_wheel_height = COALESCE($4, fifth_wheel_height),
                max_towing_weight = COALESCE($5, max_towing_weight),
                coupling_type = COALESCE($6, coupling_type),
                status = COALESCE($7, status),
                notes = COALESCE($8, notes),
                updated_at = NOW()
             WHERE id = $9
             RETURNING *`,
            [vehicle_id, tractor_number, chassis_type, fifth_wheel_height,
             max_towing_weight, coupling_type, status, notes, id]
        );
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating tractor head:', error);
        res.status(500).json({ error: 'トラクタヘッドの更新に失敗しました' });
    }
};

// ============================================
// シャーシ管理
// ============================================

// シャーシ一覧取得
export const getChassis = async (req: Request, res: Response) => {
    try {
        const { companyId, status, chassisType } = req.query;
        let query = `
            SELECT c.*, th.tractor_number as current_tractor_number
            FROM chassis c
            LEFT JOIN tractor_heads th ON c.current_tractor_id = th.id
            WHERE c.company_id = $1
        `;
        const params: any[] = [companyId];

        if (status) {
            params.push(status);
            query += ` AND c.status = $${params.length}`;
        }
        if (chassisType) {
            params.push(chassisType);
            query += ` AND c.chassis_type = $${params.length}`;
        }

        query += ` ORDER BY c.chassis_number`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching chassis:', error);
        res.status(500).json({ error: 'シャーシ一覧の取得に失敗しました' });
    }
};

// シャーシ詳細取得
export const getChassisById = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const result = await pool.query(
            `SELECT c.*, th.tractor_number as current_tractor_number
             FROM chassis c
             LEFT JOIN tractor_heads th ON c.current_tractor_id = th.id
             WHERE c.id = $1`,
            [id]
        );
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'シャーシが見つかりません' });
        }
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching chassis:', error);
        res.status(500).json({ error: 'シャーシの取得に失敗しました' });
    }
};

// シャーシ登録
export const createChassis = async (req: Request, res: Response) => {
    try {
        const {
            company_id, chassis_number, chassis_type, length_feet,
            max_payload_weight, tare_weight, axle_count,
            is_owned, lease_company, lease_start_date, lease_end_date,
            inspection_expiry, current_location, notes
        } = req.body;

        const result = await pool.query(
            `INSERT INTO chassis (
                company_id, chassis_number, chassis_type, length_feet,
                max_payload_weight, tare_weight, axle_count,
                is_owned, lease_company, lease_start_date, lease_end_date,
                inspection_expiry, current_location, notes
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
            RETURNING *`,
            [company_id, chassis_number, chassis_type, length_feet,
             max_payload_weight, tare_weight, axle_count,
             is_owned, lease_company, lease_start_date, lease_end_date,
             inspection_expiry, current_location, notes]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error creating chassis:', error);
        res.status(500).json({ error: 'シャーシの登録に失敗しました' });
    }
};

// シャーシ更新
export const updateChassis = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const {
            chassis_number, chassis_type, length_feet,
            max_payload_weight, tare_weight, axle_count,
            is_owned, lease_company, lease_start_date, lease_end_date,
            inspection_expiry, status, current_location, notes
        } = req.body;

        const result = await pool.query(
            `UPDATE chassis SET
                chassis_number = COALESCE($1, chassis_number),
                chassis_type = COALESCE($2, chassis_type),
                length_feet = COALESCE($3, length_feet),
                max_payload_weight = COALESCE($4, max_payload_weight),
                tare_weight = COALESCE($5, tare_weight),
                axle_count = COALESCE($6, axle_count),
                is_owned = COALESCE($7, is_owned),
                lease_company = COALESCE($8, lease_company),
                lease_start_date = COALESCE($9, lease_start_date),
                lease_end_date = COALESCE($10, lease_end_date),
                inspection_expiry = COALESCE($11, inspection_expiry),
                status = COALESCE($12, status),
                current_location = COALESCE($13, current_location),
                notes = COALESCE($14, notes),
                updated_at = NOW()
             WHERE id = $15
             RETURNING *`,
            [chassis_number, chassis_type, length_feet, max_payload_weight,
             tare_weight, axle_count, is_owned, lease_company,
             lease_start_date, lease_end_date, inspection_expiry,
             status, current_location, notes, id]
        );
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating chassis:', error);
        res.status(500).json({ error: 'シャーシの更新に失敗しました' });
    }
};

// 空きシャーシ検索
export const getAvailableChassis = async (req: Request, res: Response) => {
    try {
        const { companyId, chassisType, startDate, endDate } = req.query;

        // 指定期間にスケジュールされていないシャーシを検索
        const result = await pool.query(
            `SELECT c.*
             FROM chassis c
             WHERE c.company_id = $1
               AND c.status = 'available'
               AND ($2::varchar IS NULL OR c.chassis_type = $2)
               AND c.id NOT IN (
                   SELECT cs.chassis_id FROM chassis_schedules cs
                   WHERE cs.status IN ('scheduled', 'in_progress')
                     AND cs.scheduled_start < $4::timestamp
                     AND cs.scheduled_end > $3::timestamp
               )
             ORDER BY c.chassis_number`,
            [companyId, chassisType || null, startDate, endDate]
        );
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching available chassis:', error);
        res.status(500).json({ error: '空きシャーシの検索に失敗しました' });
    }
};

// ============================================
// 連結・連結解除記録
// ============================================

// 連結記録一覧取得
export const getCouplingRecords = async (req: Request, res: Response) => {
    try {
        const { companyId, tractorId, chassisId, startDate, endDate } = req.query;
        let query = `
            SELECT cr.*, th.tractor_number, c.chassis_number, u.name as driver_name
            FROM coupling_records cr
            LEFT JOIN tractor_heads th ON cr.tractor_id = th.id
            LEFT JOIN chassis c ON cr.chassis_id = c.id
            LEFT JOIN users u ON cr.driver_id = u.id
            WHERE cr.company_id = $1
        `;
        const params: any[] = [companyId];

        if (tractorId) {
            params.push(tractorId);
            query += ` AND cr.tractor_id = $${params.length}`;
        }
        if (chassisId) {
            params.push(chassisId);
            query += ` AND cr.chassis_id = $${params.length}`;
        }
        if (startDate) {
            params.push(startDate);
            query += ` AND cr.action_datetime >= $${params.length}`;
        }
        if (endDate) {
            params.push(endDate);
            query += ` AND cr.action_datetime <= $${params.length}`;
        }

        query += ` ORDER BY cr.action_datetime DESC`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching coupling records:', error);
        res.status(500).json({ error: '連結記録の取得に失敗しました' });
    }
};

// 連結実行
export const coupleTrailerChassis = async (req: Request, res: Response) => {
    const client = await pool.connect();
    try {
        const {
            company_id, tractor_id, chassis_id, driver_id,
            action_datetime, location, latitude, longitude,
            odometer_reading, seal_number, inspection_done, notes
        } = req.body;

        await client.query('BEGIN');

        // 連結記録作成
        const recordResult = await client.query(
            `INSERT INTO coupling_records (
                company_id, tractor_id, chassis_id, driver_id, action_type,
                action_datetime, location, latitude, longitude,
                odometer_reading, seal_number, inspection_done, notes
            ) VALUES ($1, $2, $3, $4, 'couple', $5, $6, $7, $8, $9, $10, $11, $12)
            RETURNING *`,
            [company_id, tractor_id, chassis_id, driver_id, action_datetime,
             location, latitude, longitude, odometer_reading, seal_number,
             inspection_done, notes]
        );

        // トラクタヘッドの現在シャーシ更新
        await client.query(
            `UPDATE tractor_heads SET current_chassis_id = $1, status = 'in_use', updated_at = NOW()
             WHERE id = $2`,
            [chassis_id, tractor_id]
        );

        // シャーシの現在トラクタ・ステータス更新
        await client.query(
            `UPDATE chassis SET current_tractor_id = $1, status = 'in_use', updated_at = NOW()
             WHERE id = $2`,
            [tractor_id, chassis_id]
        );

        await client.query('COMMIT');
        res.status(201).json(recordResult.rows[0]);
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Error coupling trailer:', error);
        res.status(500).json({ error: '連結処理に失敗しました' });
    } finally {
        client.release();
    }
};

// 連結解除実行
export const uncoupleTrailerChassis = async (req: Request, res: Response) => {
    const client = await pool.connect();
    try {
        const {
            company_id, tractor_id, chassis_id, driver_id,
            action_datetime, location, latitude, longitude,
            odometer_reading, notes
        } = req.body;

        await client.query('BEGIN');

        // 連結解除記録作成
        const recordResult = await client.query(
            `INSERT INTO coupling_records (
                company_id, tractor_id, chassis_id, driver_id, action_type,
                action_datetime, location, latitude, longitude, odometer_reading, notes
            ) VALUES ($1, $2, $3, $4, 'uncouple', $5, $6, $7, $8, $9, $10)
            RETURNING *`,
            [company_id, tractor_id, chassis_id, driver_id, action_datetime,
             location, latitude, longitude, odometer_reading, notes]
        );

        // トラクタヘッドの現在シャーシクリア
        await client.query(
            `UPDATE tractor_heads SET current_chassis_id = NULL, status = 'available', updated_at = NOW()
             WHERE id = $1`,
            [tractor_id]
        );

        // シャーシの現在トラクタクリア・位置更新
        await client.query(
            `UPDATE chassis SET current_tractor_id = NULL, status = 'available',
                    current_location = $1, updated_at = NOW()
             WHERE id = $2`,
            [location, chassis_id]
        );

        await client.query('COMMIT');
        res.status(201).json(recordResult.rows[0]);
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Error uncoupling trailer:', error);
        res.status(500).json({ error: '連結解除処理に失敗しました' });
    } finally {
        client.release();
    }
};

// ============================================
// シャーシスケジュール
// ============================================

// シャーシスケジュール一覧取得
export const getChassisSchedules = async (req: Request, res: Response) => {
    try {
        const { companyId, startDate, endDate, chassisId } = req.query;
        let query = `
            SELECT cs.*, c.chassis_number, c.chassis_type,
                   th.tractor_number, u.name as driver_name
            FROM chassis_schedules cs
            LEFT JOIN chassis c ON cs.chassis_id = c.id
            LEFT JOIN tractor_heads th ON cs.tractor_id = th.id
            LEFT JOIN users u ON cs.driver_id = u.id
            WHERE cs.company_id = $1
        `;
        const params: any[] = [companyId];

        if (startDate) {
            params.push(startDate);
            query += ` AND cs.scheduled_end >= $${params.length}`;
        }
        if (endDate) {
            params.push(endDate);
            query += ` AND cs.scheduled_start <= $${params.length}`;
        }
        if (chassisId) {
            params.push(chassisId);
            query += ` AND cs.chassis_id = $${params.length}`;
        }

        query += ` ORDER BY cs.scheduled_start`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching chassis schedules:', error);
        res.status(500).json({ error: 'シャーシスケジュールの取得に失敗しました' });
    }
};

// シャーシスケジュール登録
export const createChassisSchedule = async (req: Request, res: Response) => {
    try {
        const {
            company_id, chassis_id, tractor_id, driver_id, dispatch_id,
            scheduled_start, scheduled_end, pickup_location, delivery_location,
            priority, notes
        } = req.body;

        // 重複チェック
        const conflictCheck = await pool.query(
            `SELECT id FROM chassis_schedules
             WHERE chassis_id = $1 AND status IN ('scheduled', 'in_progress')
               AND scheduled_start < $3 AND scheduled_end > $2`,
            [chassis_id, scheduled_start, scheduled_end]
        );

        if (conflictCheck.rows.length > 0) {
            return res.status(400).json({ error: '指定期間に既存の予約があります' });
        }

        const result = await pool.query(
            `INSERT INTO chassis_schedules (
                company_id, chassis_id, tractor_id, driver_id, dispatch_id,
                scheduled_start, scheduled_end, pickup_location, delivery_location,
                priority, notes
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            RETURNING *`,
            [company_id, chassis_id, tractor_id, driver_id, dispatch_id,
             scheduled_start, scheduled_end, pickup_location, delivery_location,
             priority, notes]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error creating chassis schedule:', error);
        res.status(500).json({ error: 'シャーシスケジュールの登録に失敗しました' });
    }
};

// シャーシスケジュール更新
export const updateChassisSchedule = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const {
            chassis_id, tractor_id, driver_id, dispatch_id,
            scheduled_start, scheduled_end, actual_start, actual_end,
            pickup_location, delivery_location, status, priority, notes
        } = req.body;

        const result = await pool.query(
            `UPDATE chassis_schedules SET
                chassis_id = COALESCE($1, chassis_id),
                tractor_id = COALESCE($2, tractor_id),
                driver_id = COALESCE($3, driver_id),
                dispatch_id = COALESCE($4, dispatch_id),
                scheduled_start = COALESCE($5, scheduled_start),
                scheduled_end = COALESCE($6, scheduled_end),
                actual_start = COALESCE($7, actual_start),
                actual_end = COALESCE($8, actual_end),
                pickup_location = COALESCE($9, pickup_location),
                delivery_location = COALESCE($10, delivery_location),
                status = COALESCE($11, status),
                priority = COALESCE($12, priority),
                notes = COALESCE($13, notes),
                updated_at = NOW()
             WHERE id = $14
             RETURNING *`,
            [chassis_id, tractor_id, driver_id, dispatch_id,
             scheduled_start, scheduled_end, actual_start, actual_end,
             pickup_location, delivery_location, status, priority, notes, id]
        );
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating chassis schedule:', error);
        res.status(500).json({ error: 'シャーシスケジュールの更新に失敗しました' });
    }
};

// シャーシ予定チャートデータ取得（ガントチャート用）
export const getChassisGanttData = async (req: Request, res: Response) => {
    try {
        const { companyId, startDate, endDate } = req.query;

        // シャーシ一覧
        const chassisResult = await pool.query(
            `SELECT id, chassis_number, chassis_type, status
             FROM chassis WHERE company_id = $1
             ORDER BY chassis_number`,
            [companyId]
        );

        // スケジュール一覧
        const scheduleResult = await pool.query(
            `SELECT cs.*, c.chassis_number, th.tractor_number, u.name as driver_name
             FROM chassis_schedules cs
             LEFT JOIN chassis c ON cs.chassis_id = c.id
             LEFT JOIN tractor_heads th ON cs.tractor_id = th.id
             LEFT JOIN users u ON cs.driver_id = u.id
             WHERE cs.company_id = $1
               AND cs.scheduled_end >= $2
               AND cs.scheduled_start <= $3
             ORDER BY cs.chassis_id, cs.scheduled_start`,
            [companyId, startDate, endDate]
        );

        res.json({
            chassis: chassisResult.rows,
            schedules: scheduleResult.rows
        });
    } catch (error) {
        console.error('Error fetching gantt data:', error);
        res.status(500).json({ error: 'ガントチャートデータの取得に失敗しました' });
    }
};
