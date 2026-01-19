/**
 * Maritime Transport Controller
 * 海上輸送連携（RORO船・フェリー・港湾作業）
 */

import { Request, Response } from 'express';
import { pool } from '../index';

// ============================================
// 港湾マスタ
// ============================================

// 港湾一覧取得
export const getPorts = async (req: Request, res: Response) => {
    try {
        const { countryCode, isActive } = req.query;
        let query = `SELECT * FROM ports WHERE 1=1`;
        const params: any[] = [];

        if (countryCode) {
            params.push(countryCode);
            query += ` AND country_code = $${params.length}`;
        }
        if (isActive !== undefined) {
            params.push(isActive === 'true');
            query += ` AND is_active = $${params.length}`;
        }

        query += ` ORDER BY port_name`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching ports:', error);
        res.status(500).json({ error: '港湾一覧の取得に失敗しました' });
    }
};

// 港湾詳細取得
export const getPortById = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const result = await pool.query(
            `SELECT * FROM ports WHERE id = $1`,
            [id]
        );
        if (result.rows.length === 0) {
            return res.status(404).json({ error: '港湾が見つかりません' });
        }
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching port:', error);
        res.status(500).json({ error: '港湾の取得に失敗しました' });
    }
};

// ============================================
// フェリー航路
// ============================================

// フェリー航路一覧取得
export const getFerryRoutes = async (req: Request, res: Response) => {
    try {
        const { departurePortId, arrivalPortId, isActive } = req.query;
        let query = `
            SELECT fr.*,
                   dp.port_name as departure_port_name, dp.port_code as departure_port_code,
                   ap.port_name as arrival_port_name, ap.port_code as arrival_port_code
            FROM ferry_routes fr
            LEFT JOIN ports dp ON fr.departure_port_id = dp.id
            LEFT JOIN ports ap ON fr.arrival_port_id = ap.id
            WHERE 1=1
        `;
        const params: any[] = [];

        if (departurePortId) {
            params.push(departurePortId);
            query += ` AND fr.departure_port_id = $${params.length}`;
        }
        if (arrivalPortId) {
            params.push(arrivalPortId);
            query += ` AND fr.arrival_port_id = $${params.length}`;
        }
        if (isActive !== undefined) {
            params.push(isActive === 'true');
            query += ` AND fr.is_active = $${params.length}`;
        }

        query += ` ORDER BY fr.route_name`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching ferry routes:', error);
        res.status(500).json({ error: 'フェリー航路一覧の取得に失敗しました' });
    }
};

// ============================================
// フェリースケジュール
// ============================================

// フェリースケジュール一覧取得
export const getFerrySchedules = async (req: Request, res: Response) => {
    try {
        const { routeId, startDate, endDate, status } = req.query;
        let query = `
            SELECT fs.*, fr.route_name, fr.shipping_company,
                   dp.port_name as departure_port_name,
                   ap.port_name as arrival_port_name
            FROM ferry_schedules fs
            LEFT JOIN ferry_routes fr ON fs.route_id = fr.id
            LEFT JOIN ports dp ON fr.departure_port_id = dp.id
            LEFT JOIN ports ap ON fr.arrival_port_id = ap.id
            WHERE 1=1
        `;
        const params: any[] = [];

        if (routeId) {
            params.push(routeId);
            query += ` AND fs.route_id = $${params.length}`;
        }
        if (startDate) {
            params.push(startDate);
            query += ` AND fs.departure_date >= $${params.length}`;
        }
        if (endDate) {
            params.push(endDate);
            query += ` AND fs.departure_date <= $${params.length}`;
        }
        if (status) {
            params.push(status);
            query += ` AND fs.status = $${params.length}`;
        }

        query += ` ORDER BY fs.departure_date, fs.departure_time`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching ferry schedules:', error);
        res.status(500).json({ error: 'フェリースケジュールの取得に失敗しました' });
    }
};

// フェリースケジュール登録
export const createFerrySchedule = async (req: Request, res: Response) => {
    try {
        const {
            route_id, departure_date, departure_time,
            arrival_date, arrival_time, vessel_name,
            available_vehicle_slots, available_trailer_slots, notes
        } = req.body;

        const result = await pool.query(
            `INSERT INTO ferry_schedules (
                route_id, departure_date, departure_time,
                arrival_date, arrival_time, vessel_name,
                available_vehicle_slots, available_trailer_slots, notes
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING *`,
            [route_id, departure_date, departure_time, arrival_date,
             arrival_time, vessel_name, available_vehicle_slots,
             available_trailer_slots, notes]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error creating ferry schedule:', error);
        res.status(500).json({ error: 'フェリースケジュールの登録に失敗しました' });
    }
};

// フェリースケジュール更新
export const updateFerrySchedule = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const {
            departure_date, departure_time, arrival_date, arrival_time,
            vessel_name, status, delay_minutes, available_vehicle_slots,
            available_trailer_slots, weather_warning, notes
        } = req.body;

        const result = await pool.query(
            `UPDATE ferry_schedules SET
                departure_date = COALESCE($1, departure_date),
                departure_time = COALESCE($2, departure_time),
                arrival_date = COALESCE($3, arrival_date),
                arrival_time = COALESCE($4, arrival_time),
                vessel_name = COALESCE($5, vessel_name),
                status = COALESCE($6, status),
                delay_minutes = COALESCE($7, delay_minutes),
                available_vehicle_slots = COALESCE($8, available_vehicle_slots),
                available_trailer_slots = COALESCE($9, available_trailer_slots),
                weather_warning = COALESCE($10, weather_warning),
                notes = COALESCE($11, notes),
                updated_at = NOW()
             WHERE id = $12
             RETURNING *`,
            [departure_date, departure_time, arrival_date, arrival_time,
             vessel_name, status, delay_minutes, available_vehicle_slots,
             available_trailer_slots, weather_warning, notes, id]
        );
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating ferry schedule:', error);
        res.status(500).json({ error: 'フェリースケジュールの更新に失敗しました' });
    }
};

// ============================================
// フェリー予約
// ============================================

// フェリー予約一覧取得
export const getFerryBookings = async (req: Request, res: Response) => {
    try {
        const { companyId, scheduleId, startDate, endDate, status } = req.query;
        let query = `
            SELECT fb.*, fs.departure_date, fs.departure_time, fs.arrival_date, fs.arrival_time,
                   fr.route_name, fr.shipping_company,
                   dp.port_name as departure_port_name,
                   ap.port_name as arrival_port_name,
                   th.tractor_number, c.chassis_number, v.vehicle_number,
                   u.name as driver_name
            FROM ferry_bookings fb
            LEFT JOIN ferry_schedules fs ON fb.schedule_id = fs.id
            LEFT JOIN ferry_routes fr ON fs.route_id = fr.id
            LEFT JOIN ports dp ON fr.departure_port_id = dp.id
            LEFT JOIN ports ap ON fr.arrival_port_id = ap.id
            LEFT JOIN tractor_heads th ON fb.tractor_id = th.id
            LEFT JOIN chassis c ON fb.chassis_id = c.id
            LEFT JOIN vehicles v ON fb.vehicle_id = v.id
            LEFT JOIN users u ON fb.driver_id = u.id
            WHERE fb.company_id = $1
        `;
        const params: any[] = [companyId];

        if (scheduleId) {
            params.push(scheduleId);
            query += ` AND fb.schedule_id = $${params.length}`;
        }
        if (startDate) {
            params.push(startDate);
            query += ` AND fs.departure_date >= $${params.length}`;
        }
        if (endDate) {
            params.push(endDate);
            query += ` AND fs.departure_date <= $${params.length}`;
        }
        if (status) {
            params.push(status);
            query += ` AND fb.boarding_status = $${params.length}`;
        }

        query += ` ORDER BY fs.departure_date, fs.departure_time`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching ferry bookings:', error);
        res.status(500).json({ error: 'フェリー予約一覧の取得に失敗しました' });
    }
};

// フェリー予約登録
export const createFerryBooking = async (req: Request, res: Response) => {
    const client = await pool.connect();
    try {
        const {
            company_id, schedule_id, booking_type,
            tractor_id, chassis_id, vehicle_id, driver_id, dispatch_id,
            cabin_type, fare_amount, additional_charges, notes
        } = req.body;

        await client.query('BEGIN');

        // 予約番号生成
        const booking_number = `FB${Date.now()}`;

        // 空き枠確認
        const scheduleResult = await client.query(
            `SELECT available_vehicle_slots, available_trailer_slots
             FROM ferry_schedules WHERE id = $1`,
            [schedule_id]
        );

        if (scheduleResult.rows.length === 0) {
            throw new Error('スケジュールが見つかりません');
        }

        const schedule = scheduleResult.rows[0];
        const isTrailer = booking_type === 'trailer';

        if (isTrailer && schedule.available_trailer_slots <= 0) {
            throw new Error('トレーラー枠に空きがありません');
        }
        if (!isTrailer && booking_type === 'vehicle' && schedule.available_vehicle_slots <= 0) {
            throw new Error('車両枠に空きがありません');
        }

        // 予約作成
        const result = await client.query(
            `INSERT INTO ferry_bookings (
                company_id, schedule_id, booking_number, booking_type,
                tractor_id, chassis_id, vehicle_id, driver_id, dispatch_id,
                cabin_type, fare_amount, additional_charges, notes
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
            RETURNING *`,
            [company_id, schedule_id, booking_number, booking_type,
             tractor_id, chassis_id, vehicle_id, driver_id, dispatch_id,
             cabin_type, fare_amount, additional_charges, notes]
        );

        // 空き枠更新
        if (isTrailer) {
            await client.query(
                `UPDATE ferry_schedules SET available_trailer_slots = available_trailer_slots - 1
                 WHERE id = $1`,
                [schedule_id]
            );
        } else if (booking_type === 'vehicle') {
            await client.query(
                `UPDATE ferry_schedules SET available_vehicle_slots = available_vehicle_slots - 1
                 WHERE id = $1`,
                [schedule_id]
            );
        }

        await client.query('COMMIT');
        res.status(201).json(result.rows[0]);
    } catch (error: any) {
        await client.query('ROLLBACK');
        console.error('Error creating ferry booking:', error);
        res.status(500).json({ error: error.message || 'フェリー予約の登録に失敗しました' });
    } finally {
        client.release();
    }
};

// フェリー予約更新
export const updateFerryBooking = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const {
            driver_id, cabin_type, boarding_status,
            check_in_time, boarding_time, fare_amount,
            additional_charges, payment_status, notes
        } = req.body;

        const result = await pool.query(
            `UPDATE ferry_bookings SET
                driver_id = COALESCE($1, driver_id),
                cabin_type = COALESCE($2, cabin_type),
                boarding_status = COALESCE($3, boarding_status),
                check_in_time = COALESCE($4, check_in_time),
                boarding_time = COALESCE($5, boarding_time),
                fare_amount = COALESCE($6, fare_amount),
                additional_charges = COALESCE($7, additional_charges),
                payment_status = COALESCE($8, payment_status),
                notes = COALESCE($9, notes),
                updated_at = NOW()
             WHERE id = $10
             RETURNING *`,
            [driver_id, cabin_type, boarding_status, check_in_time,
             boarding_time, fare_amount, additional_charges, payment_status, notes, id]
        );
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating ferry booking:', error);
        res.status(500).json({ error: 'フェリー予約の更新に失敗しました' });
    }
};

// フェリー予約キャンセル
export const cancelFerryBooking = async (req: Request, res: Response) => {
    const client = await pool.connect();
    try {
        const { id } = req.params;

        await client.query('BEGIN');

        // 予約情報取得
        const bookingResult = await client.query(
            `SELECT * FROM ferry_bookings WHERE id = $1`,
            [id]
        );

        if (bookingResult.rows.length === 0) {
            throw new Error('予約が見つかりません');
        }

        const booking = bookingResult.rows[0];

        if (booking.boarding_status !== 'booked') {
            throw new Error('この予約はキャンセルできません');
        }

        // ステータス更新
        await client.query(
            `UPDATE ferry_bookings SET boarding_status = 'cancelled', updated_at = NOW()
             WHERE id = $1`,
            [id]
        );

        // 空き枠を戻す
        if (booking.booking_type === 'trailer') {
            await client.query(
                `UPDATE ferry_schedules SET available_trailer_slots = available_trailer_slots + 1
                 WHERE id = $1`,
                [booking.schedule_id]
            );
        } else if (booking.booking_type === 'vehicle') {
            await client.query(
                `UPDATE ferry_schedules SET available_vehicle_slots = available_vehicle_slots + 1
                 WHERE id = $1`,
                [booking.schedule_id]
            );
        }

        await client.query('COMMIT');
        res.json({ message: '予約をキャンセルしました' });
    } catch (error: any) {
        await client.query('ROLLBACK');
        console.error('Error cancelling ferry booking:', error);
        res.status(500).json({ error: error.message || 'フェリー予約のキャンセルに失敗しました' });
    } finally {
        client.release();
    }
};

// ============================================
// 港湾作業記録
// ============================================

// 港湾作業一覧取得
export const getPortOperations = async (req: Request, res: Response) => {
    try {
        const { companyId, portId, startDate, endDate, status } = req.query;
        let query = `
            SELECT po.*, p.port_name, p.port_code,
                   th.tractor_number, c.chassis_number, v.vehicle_number,
                   u.name as driver_name
            FROM port_operations po
            LEFT JOIN ports p ON po.port_id = p.id
            LEFT JOIN tractor_heads th ON po.tractor_id = th.id
            LEFT JOIN chassis c ON po.chassis_id = c.id
            LEFT JOIN vehicles v ON po.vehicle_id = v.id
            LEFT JOIN users u ON po.driver_id = u.id
            WHERE po.company_id = $1
        `;
        const params: any[] = [companyId];

        if (portId) {
            params.push(portId);
            query += ` AND po.port_id = $${params.length}`;
        }
        if (startDate) {
            params.push(startDate);
            query += ` AND po.arrival_time >= $${params.length}`;
        }
        if (endDate) {
            params.push(endDate);
            query += ` AND po.arrival_time <= $${params.length}`;
        }
        if (status) {
            params.push(status);
            query += ` AND po.status = $${params.length}`;
        }

        query += ` ORDER BY po.arrival_time DESC`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching port operations:', error);
        res.status(500).json({ error: '港湾作業一覧の取得に失敗しました' });
    }
};

// 港湾作業登録
export const createPortOperation = async (req: Request, res: Response) => {
    try {
        const {
            company_id, port_id, operation_type,
            tractor_id, chassis_id, vehicle_id, driver_id,
            container_id, ferry_booking_id,
            arrival_time, berth_number, notes
        } = req.body;

        const result = await pool.query(
            `INSERT INTO port_operations (
                company_id, port_id, operation_type,
                tractor_id, chassis_id, vehicle_id, driver_id,
                container_id, ferry_booking_id,
                arrival_time, berth_number, notes
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
            RETURNING *`,
            [company_id, port_id, operation_type,
             tractor_id, chassis_id, vehicle_id, driver_id,
             container_id, ferry_booking_id,
             arrival_time, berth_number, notes]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error creating port operation:', error);
        res.status(500).json({ error: '港湾作業の登録に失敗しました' });
    }
};

// 港湾作業更新（ゲートイン/アウト、作業開始/終了）
export const updatePortOperation = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const {
            operation_start, operation_end, departure_time,
            gate_in_number, gate_out_number, berth_number,
            waiting_time_minutes, status, notes
        } = req.body;

        const result = await pool.query(
            `UPDATE port_operations SET
                operation_start = COALESCE($1, operation_start),
                operation_end = COALESCE($2, operation_end),
                departure_time = COALESCE($3, departure_time),
                gate_in_number = COALESCE($4, gate_in_number),
                gate_out_number = COALESCE($5, gate_out_number),
                berth_number = COALESCE($6, berth_number),
                waiting_time_minutes = COALESCE($7, waiting_time_minutes),
                status = COALESCE($8, status),
                notes = COALESCE($9, notes)
             WHERE id = $10
             RETURNING *`,
            [operation_start, operation_end, departure_time, gate_in_number,
             gate_out_number, berth_number, waiting_time_minutes, status, notes, id]
        );
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating port operation:', error);
        res.status(500).json({ error: '港湾作業の更新に失敗しました' });
    }
};

// 港湾作業統計（待機時間分析）
export const getPortStatistics = async (req: Request, res: Response) => {
    try {
        const { companyId, portId, startDate, endDate } = req.query;

        const result = await pool.query(
            `SELECT
                p.port_name,
                COUNT(*) as total_operations,
                AVG(po.waiting_time_minutes)::integer as avg_waiting_time,
                MAX(po.waiting_time_minutes) as max_waiting_time,
                MIN(po.waiting_time_minutes) as min_waiting_time,
                COUNT(CASE WHEN po.operation_type = 'loading' THEN 1 END) as loading_count,
                COUNT(CASE WHEN po.operation_type = 'unloading' THEN 1 END) as unloading_count
             FROM port_operations po
             LEFT JOIN ports p ON po.port_id = p.id
             WHERE po.company_id = $1
               AND ($2::integer IS NULL OR po.port_id = $2)
               AND po.arrival_time >= $3
               AND po.arrival_time <= $4
             GROUP BY p.id, p.port_name
             ORDER BY total_operations DESC`,
            [companyId, portId || null, startDate, endDate]
        );
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching port statistics:', error);
        res.status(500).json({ error: '港湾統計の取得に失敗しました' });
    }
};
