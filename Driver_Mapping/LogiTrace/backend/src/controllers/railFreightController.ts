/**
 * Rail Freight Controller
 * 通運事業対応（JR貨物連携・コンテナ管理）
 */

import { Request, Response } from 'express';
import { pool } from '../index';

// ============================================
// コンテナ管理
// ============================================

// コンテナ一覧取得
export const getContainers = async (req: Request, res: Response) => {
    try {
        const { companyId, status, containerType, containerCategory } = req.query;
        let query = `SELECT * FROM containers WHERE company_id = $1`;
        const params: any[] = [companyId];

        if (status) {
            params.push(status);
            query += ` AND status = $${params.length}`;
        }
        if (containerType) {
            params.push(containerType);
            query += ` AND container_type = $${params.length}`;
        }
        if (containerCategory) {
            params.push(containerCategory);
            query += ` AND container_category = $${params.length}`;
        }

        query += ` ORDER BY container_number`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching containers:', error);
        res.status(500).json({ error: 'コンテナ一覧の取得に失敗しました' });
    }
};

// コンテナ詳細取得
export const getContainerById = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const result = await pool.query(
            `SELECT * FROM containers WHERE id = $1`,
            [id]
        );
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'コンテナが見つかりません' });
        }
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching container:', error);
        res.status(500).json({ error: 'コンテナの取得に失敗しました' });
    }
};

// コンテナ登録
export const createContainer = async (req: Request, res: Response) => {
    try {
        const {
            company_id, container_number, container_type, container_category,
            is_owned, owner_company, max_payload_kg, tare_weight_kg,
            internal_length_mm, internal_width_mm, internal_height_mm,
            cubic_capacity_m3, temperature_control, min_temperature,
            max_temperature, current_location, notes
        } = req.body;

        const result = await pool.query(
            `INSERT INTO containers (
                company_id, container_number, container_type, container_category,
                is_owned, owner_company, max_payload_kg, tare_weight_kg,
                internal_length_mm, internal_width_mm, internal_height_mm,
                cubic_capacity_m3, temperature_control, min_temperature,
                max_temperature, current_location, notes
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
            RETURNING *`,
            [company_id, container_number, container_type, container_category,
             is_owned, owner_company, max_payload_kg, tare_weight_kg,
             internal_length_mm, internal_width_mm, internal_height_mm,
             cubic_capacity_m3, temperature_control, min_temperature,
             max_temperature, current_location, notes]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error creating container:', error);
        res.status(500).json({ error: 'コンテナの登録に失敗しました' });
    }
};

// コンテナ更新
export const updateContainer = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const {
            container_number, container_type, container_category,
            is_owned, owner_company, max_payload_kg, tare_weight_kg,
            cubic_capacity_m3, temperature_control, min_temperature,
            max_temperature, status, current_location, last_inspection_date, notes
        } = req.body;

        const result = await pool.query(
            `UPDATE containers SET
                container_number = COALESCE($1, container_number),
                container_type = COALESCE($2, container_type),
                container_category = COALESCE($3, container_category),
                is_owned = COALESCE($4, is_owned),
                owner_company = COALESCE($5, owner_company),
                max_payload_kg = COALESCE($6, max_payload_kg),
                tare_weight_kg = COALESCE($7, tare_weight_kg),
                cubic_capacity_m3 = COALESCE($8, cubic_capacity_m3),
                temperature_control = COALESCE($9, temperature_control),
                min_temperature = COALESCE($10, min_temperature),
                max_temperature = COALESCE($11, max_temperature),
                status = COALESCE($12, status),
                current_location = COALESCE($13, current_location),
                last_inspection_date = COALESCE($14, last_inspection_date),
                notes = COALESCE($15, notes),
                updated_at = NOW()
             WHERE id = $16
             RETURNING *`,
            [container_number, container_type, container_category,
             is_owned, owner_company, max_payload_kg, tare_weight_kg,
             cubic_capacity_m3, temperature_control, min_temperature,
             max_temperature, status, current_location, last_inspection_date, notes, id]
        );
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating container:', error);
        res.status(500).json({ error: 'コンテナの更新に失敗しました' });
    }
};

// ============================================
// 貨物駅マスタ
// ============================================

// 貨物駅一覧取得
export const getFreightStations = async (req: Request, res: Response) => {
    try {
        const { prefecture, stationType, isActive } = req.query;
        let query = `SELECT * FROM freight_stations WHERE 1=1`;
        const params: any[] = [];

        if (prefecture) {
            params.push(prefecture);
            query += ` AND prefecture = $${params.length}`;
        }
        if (stationType) {
            params.push(stationType);
            query += ` AND station_type = $${params.length}`;
        }
        if (isActive !== undefined) {
            params.push(isActive === 'true');
            query += ` AND is_active = $${params.length}`;
        }

        query += ` ORDER BY station_name`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching freight stations:', error);
        res.status(500).json({ error: '貨物駅一覧の取得に失敗しました' });
    }
};

// 貨物駅詳細取得
export const getFreightStationById = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const result = await pool.query(
            `SELECT * FROM freight_stations WHERE id = $1`,
            [id]
        );
        if (result.rows.length === 0) {
            return res.status(404).json({ error: '貨物駅が見つかりません' });
        }
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching freight station:', error);
        res.status(500).json({ error: '貨物駅の取得に失敗しました' });
    }
};

// ============================================
// 鉄道輸送ルート
// ============================================

// 鉄道ルート一覧取得
export const getRailRoutes = async (req: Request, res: Response) => {
    try {
        const { departureStationId, arrivalStationId, isActive } = req.query;
        let query = `
            SELECT rr.*,
                   ds.station_name as departure_station_name,
                   as2.station_name as arrival_station_name
            FROM rail_routes rr
            LEFT JOIN freight_stations ds ON rr.departure_station_id = ds.id
            LEFT JOIN freight_stations as2 ON rr.arrival_station_id = as2.id
            WHERE 1=1
        `;
        const params: any[] = [];

        if (departureStationId) {
            params.push(departureStationId);
            query += ` AND rr.departure_station_id = $${params.length}`;
        }
        if (arrivalStationId) {
            params.push(arrivalStationId);
            query += ` AND rr.arrival_station_id = $${params.length}`;
        }
        if (isActive !== undefined) {
            params.push(isActive === 'true');
            query += ` AND rr.is_active = $${params.length}`;
        }

        query += ` ORDER BY rr.route_name`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching rail routes:', error);
        res.status(500).json({ error: '鉄道ルート一覧の取得に失敗しました' });
    }
};

// ============================================
// 鉄道輸送予約
// ============================================

// 鉄道予約一覧取得
export const getRailBookings = async (req: Request, res: Response) => {
    try {
        const { companyId, startDate, endDate, status } = req.query;
        let query = `
            SELECT rb.*,
                   rr.route_name,
                   ds.station_name as departure_station_name,
                   as2.station_name as arrival_station_name,
                   c.container_number, c.container_type,
                   s.name as shipper_name,
                   pt.tractor_number as pickup_tractor_number,
                   pu.name as pickup_driver_name,
                   dt.tractor_number as delivery_tractor_number,
                   du.name as delivery_driver_name
            FROM rail_bookings rb
            LEFT JOIN rail_routes rr ON rb.route_id = rr.id
            LEFT JOIN freight_stations ds ON rr.departure_station_id = ds.id
            LEFT JOIN freight_stations as2 ON rr.arrival_station_id = as2.id
            LEFT JOIN containers c ON rb.container_id = c.id
            LEFT JOIN shippers s ON rb.shipper_id = s.id
            LEFT JOIN tractor_heads pt ON rb.pickup_tractor_id = pt.id
            LEFT JOIN users pu ON rb.pickup_driver_id = pu.id
            LEFT JOIN tractor_heads dt ON rb.delivery_tractor_id = dt.id
            LEFT JOIN users du ON rb.delivery_driver_id = du.id
            WHERE rb.company_id = $1
        `;
        const params: any[] = [companyId];

        if (startDate) {
            params.push(startDate);
            query += ` AND rb.departure_date >= $${params.length}`;
        }
        if (endDate) {
            params.push(endDate);
            query += ` AND rb.departure_date <= $${params.length}`;
        }
        if (status) {
            params.push(status);
            query += ` AND rb.booking_status = $${params.length}`;
        }

        query += ` ORDER BY rb.departure_date, rb.departure_time`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching rail bookings:', error);
        res.status(500).json({ error: '鉄道予約一覧の取得に失敗しました' });
    }
};

// 鉄道予約詳細取得
export const getRailBookingById = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const result = await pool.query(
            `SELECT rb.*,
                    rr.route_name, rr.transit_time_hours, rr.distance_km,
                    ds.station_name as departure_station_name,
                    as2.station_name as arrival_station_name,
                    c.container_number, c.container_type, c.container_category,
                    s.name as shipper_name,
                    pt.tractor_number as pickup_tractor_number,
                    pu.name as pickup_driver_name,
                    dt.tractor_number as delivery_tractor_number,
                    du.name as delivery_driver_name
             FROM rail_bookings rb
             LEFT JOIN rail_routes rr ON rb.route_id = rr.id
             LEFT JOIN freight_stations ds ON rr.departure_station_id = ds.id
             LEFT JOIN freight_stations as2 ON rr.arrival_station_id = as2.id
             LEFT JOIN containers c ON rb.container_id = c.id
             LEFT JOIN shippers s ON rb.shipper_id = s.id
             LEFT JOIN tractor_heads pt ON rb.pickup_tractor_id = pt.id
             LEFT JOIN users pu ON rb.pickup_driver_id = pu.id
             LEFT JOIN tractor_heads dt ON rb.delivery_tractor_id = dt.id
             LEFT JOIN users du ON rb.delivery_driver_id = du.id
             WHERE rb.id = $1`,
            [id]
        );
        if (result.rows.length === 0) {
            return res.status(404).json({ error: '鉄道予約が見つかりません' });
        }
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching rail booking:', error);
        res.status(500).json({ error: '鉄道予約の取得に失敗しました' });
    }
};

// 鉄道予約登録
export const createRailBooking = async (req: Request, res: Response) => {
    const client = await pool.connect();
    try {
        const {
            company_id, route_id, container_id, shipper_id, dispatch_id,
            departure_date, departure_time, arrival_date, arrival_time,
            cargo_description, cargo_weight_kg,
            pickup_tractor_id, pickup_driver_id,
            delivery_tractor_id, delivery_driver_id,
            rail_fare, pickup_fare, delivery_fare, notes
        } = req.body;

        await client.query('BEGIN');

        // 予約番号生成
        const booking_number = `RB${Date.now()}`;

        // 合計運賃計算
        const total_fare = (rail_fare || 0) + (pickup_fare || 0) + (delivery_fare || 0);

        // 予約作成
        const result = await client.query(
            `INSERT INTO rail_bookings (
                company_id, route_id, booking_number, container_id, shipper_id, dispatch_id,
                departure_date, departure_time, arrival_date, arrival_time,
                cargo_description, cargo_weight_kg,
                pickup_tractor_id, pickup_driver_id,
                delivery_tractor_id, delivery_driver_id,
                rail_fare, pickup_fare, delivery_fare, total_fare, notes
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21)
            RETURNING *`,
            [company_id, route_id, booking_number, container_id, shipper_id, dispatch_id,
             departure_date, departure_time, arrival_date, arrival_time,
             cargo_description, cargo_weight_kg,
             pickup_tractor_id, pickup_driver_id,
             delivery_tractor_id, delivery_driver_id,
             rail_fare, pickup_fare, delivery_fare, total_fare, notes]
        );

        // コンテナステータス更新
        if (container_id) {
            await client.query(
                `UPDATE containers SET status = 'loaded', updated_at = NOW() WHERE id = $1`,
                [container_id]
            );
        }

        await client.query('COMMIT');
        res.status(201).json(result.rows[0]);
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Error creating rail booking:', error);
        res.status(500).json({ error: '鉄道予約の登録に失敗しました' });
    } finally {
        client.release();
    }
};

// 鉄道予約更新
export const updateRailBooking = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const {
            departure_date, departure_time, arrival_date, arrival_time,
            cargo_description, cargo_weight_kg, booking_status,
            pickup_tractor_id, pickup_driver_id,
            delivery_tractor_id, delivery_driver_id,
            rail_fare, pickup_fare, delivery_fare, payment_status, notes
        } = req.body;

        // 合計運賃計算
        const total_fare = (rail_fare || 0) + (pickup_fare || 0) + (delivery_fare || 0);

        const result = await pool.query(
            `UPDATE rail_bookings SET
                departure_date = COALESCE($1, departure_date),
                departure_time = COALESCE($2, departure_time),
                arrival_date = COALESCE($3, arrival_date),
                arrival_time = COALESCE($4, arrival_time),
                cargo_description = COALESCE($5, cargo_description),
                cargo_weight_kg = COALESCE($6, cargo_weight_kg),
                booking_status = COALESCE($7, booking_status),
                pickup_tractor_id = COALESCE($8, pickup_tractor_id),
                pickup_driver_id = COALESCE($9, pickup_driver_id),
                delivery_tractor_id = COALESCE($10, delivery_tractor_id),
                delivery_driver_id = COALESCE($11, delivery_driver_id),
                rail_fare = COALESCE($12, rail_fare),
                pickup_fare = COALESCE($13, pickup_fare),
                delivery_fare = COALESCE($14, delivery_fare),
                total_fare = $15,
                payment_status = COALESCE($16, payment_status),
                notes = COALESCE($17, notes),
                updated_at = NOW()
             WHERE id = $18
             RETURNING *`,
            [departure_date, departure_time, arrival_date, arrival_time,
             cargo_description, cargo_weight_kg, booking_status,
             pickup_tractor_id, pickup_driver_id,
             delivery_tractor_id, delivery_driver_id,
             rail_fare, pickup_fare, delivery_fare, total_fare || null,
             payment_status, notes, id]
        );
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating rail booking:', error);
        res.status(500).json({ error: '鉄道予約の更新に失敗しました' });
    }
};

// ============================================
// コンテナ追跡
// ============================================

// コンテナ追跡履歴取得
export const getContainerTracking = async (req: Request, res: Response) => {
    try {
        const { containerId, railBookingId, startDate, endDate } = req.query;
        let query = `
            SELECT ct.*,
                   fs.station_name, p.port_name
            FROM container_tracking ct
            LEFT JOIN freight_stations fs ON ct.station_id = fs.id
            LEFT JOIN ports p ON ct.port_id = p.id
            WHERE 1=1
        `;
        const params: any[] = [];

        if (containerId) {
            params.push(containerId);
            query += ` AND ct.container_id = $${params.length}`;
        }
        if (railBookingId) {
            params.push(railBookingId);
            query += ` AND ct.rail_booking_id = $${params.length}`;
        }
        if (startDate) {
            params.push(startDate);
            query += ` AND ct.tracked_at >= $${params.length}`;
        }
        if (endDate) {
            params.push(endDate);
            query += ` AND ct.tracked_at <= $${params.length}`;
        }

        query += ` ORDER BY ct.tracked_at DESC`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching container tracking:', error);
        res.status(500).json({ error: 'コンテナ追跡履歴の取得に失敗しました' });
    }
};

// コンテナ追跡登録
export const addContainerTracking = async (req: Request, res: Response) => {
    const client = await pool.connect();
    try {
        const {
            container_id, rail_booking_id, tracked_at,
            location_type, location_name, station_id, port_id,
            latitude, longitude, status, temperature, humidity, notes
        } = req.body;

        await client.query('BEGIN');

        // 追跡記録作成
        const result = await client.query(
            `INSERT INTO container_tracking (
                container_id, rail_booking_id, tracked_at,
                location_type, location_name, station_id, port_id,
                latitude, longitude, status, temperature, humidity, notes
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
            RETURNING *`,
            [container_id, rail_booking_id, tracked_at,
             location_type, location_name, station_id, port_id,
             latitude, longitude, status, temperature, humidity, notes]
        );

        // コンテナの現在位置・ステータス更新
        await client.query(
            `UPDATE containers SET
                current_location = $1,
                status = $2,
                updated_at = NOW()
             WHERE id = $3`,
            [location_name, status, container_id]
        );

        // 鉄道予約のステータス更新（必要に応じて）
        if (rail_booking_id && status) {
            let bookingStatus = null;
            switch (status) {
                case 'loaded':
                    bookingStatus = 'loaded';
                    break;
                case 'in_transit':
                    bookingStatus = 'in_transit';
                    break;
                case 'delivered':
                    bookingStatus = 'delivered';
                    break;
            }
            if (bookingStatus) {
                await client.query(
                    `UPDATE rail_bookings SET booking_status = $1, updated_at = NOW()
                     WHERE id = $2`,
                    [bookingStatus, rail_booking_id]
                );
            }
        }

        await client.query('COMMIT');
        res.status(201).json(result.rows[0]);
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Error adding container tracking:', error);
        res.status(500).json({ error: 'コンテナ追跡の登録に失敗しました' });
    } finally {
        client.release();
    }
};

// コンテナ現在位置一覧
export const getCurrentContainerLocations = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.query;

        const result = await pool.query(
            `SELECT c.*,
                    ct.tracked_at as last_tracked_at,
                    ct.location_type, ct.location_name,
                    ct.latitude, ct.longitude,
                    ct.temperature, ct.humidity
             FROM containers c
             LEFT JOIN LATERAL (
                 SELECT * FROM container_tracking
                 WHERE container_id = c.id
                 ORDER BY tracked_at DESC
                 LIMIT 1
             ) ct ON true
             WHERE c.company_id = $1
               AND c.status NOT IN ('available', 'maintenance')
             ORDER BY ct.tracked_at DESC NULLS LAST`,
            [companyId]
        );
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching container locations:', error);
        res.status(500).json({ error: 'コンテナ位置情報の取得に失敗しました' });
    }
};

// 鉄道輸送統計
export const getRailStatistics = async (req: Request, res: Response) => {
    try {
        const { companyId, startDate, endDate } = req.query;

        const result = await pool.query(
            `SELECT
                COUNT(*) as total_bookings,
                COUNT(CASE WHEN booking_status = 'delivered' THEN 1 END) as completed_bookings,
                COUNT(CASE WHEN booking_status = 'cancelled' THEN 1 END) as cancelled_bookings,
                SUM(cargo_weight_kg) as total_weight_kg,
                SUM(total_fare) as total_revenue,
                AVG(total_fare)::integer as avg_fare,
                COUNT(DISTINCT container_id) as unique_containers,
                COUNT(DISTINCT route_id) as unique_routes
             FROM rail_bookings
             WHERE company_id = $1
               AND departure_date >= $2
               AND departure_date <= $3`,
            [companyId, startDate, endDate]
        );

        // ルート別統計
        const routeStats = await pool.query(
            `SELECT
                rr.route_name,
                COUNT(*) as booking_count,
                SUM(rb.cargo_weight_kg) as total_weight,
                SUM(rb.total_fare) as total_revenue
             FROM rail_bookings rb
             LEFT JOIN rail_routes rr ON rb.route_id = rr.id
             WHERE rb.company_id = $1
               AND rb.departure_date >= $2
               AND rb.departure_date <= $3
             GROUP BY rr.id, rr.route_name
             ORDER BY booking_count DESC`,
            [companyId, startDate, endDate]
        );

        res.json({
            summary: result.rows[0],
            byRoute: routeStats.rows
        });
    } catch (error) {
        console.error('Error fetching rail statistics:', error);
        res.status(500).json({ error: '鉄道輸送統計の取得に失敗しました' });
    }
};
