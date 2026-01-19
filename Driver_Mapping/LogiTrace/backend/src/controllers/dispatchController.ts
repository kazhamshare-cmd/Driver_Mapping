/**
 * Dispatch Controller - 配車割当API
 */

import { Request, Response } from 'express';
import { pool } from '../utils/db';
import * as autoAssignService from '../services/autoAssignService';

// 配車一覧取得
export const getDispatches = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;
    const { date, driver_id, vehicle_id, status } = req.query;

    try {
        let query = `
            SELECT
                da.*,
                o.order_number,
                o.cargo_name,
                o.pickup_datetime,
                o.delivery_datetime,
                s.name as shipper_name,
                pl.name as pickup_location_name,
                dl.name as delivery_location_name,
                v.vehicle_number,
                u.name as driver_name,
                u.employee_number,
                assigner.name as assigned_by_name
            FROM dispatch_assignments da
            JOIN orders o ON da.order_id = o.id
            LEFT JOIN shippers s ON o.shipper_id = s.id
            LEFT JOIN locations pl ON o.pickup_location_id = pl.id
            LEFT JOIN locations dl ON o.delivery_location_id = dl.id
            LEFT JOIN vehicles v ON da.vehicle_id = v.id
            LEFT JOIN users u ON da.driver_id = u.id
            LEFT JOIN users assigner ON da.assigned_by = assigner.id
            WHERE da.company_id = $1
        `;
        const params: any[] = [companyId];
        let paramIndex = 2;

        if (date) {
            query += ` AND DATE(da.scheduled_start) = $${paramIndex}`;
            params.push(date);
            paramIndex++;
        }

        if (driver_id) {
            query += ` AND da.driver_id = $${paramIndex}`;
            params.push(driver_id);
            paramIndex++;
        }

        if (vehicle_id) {
            query += ` AND da.vehicle_id = $${paramIndex}`;
            params.push(vehicle_id);
            paramIndex++;
        }

        if (status) {
            query += ` AND da.status = $${paramIndex}`;
            params.push(status);
            paramIndex++;
        }

        query += ' ORDER BY da.scheduled_start';

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching dispatches:', error);
        res.status(500).json({ error: 'Failed to fetch dispatches' });
    }
};

// 本日の配車サマリー
export const getTodayDispatchSummary = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;
    const today = new Date().toISOString().split('T')[0];

    try {
        const result = await pool.query(`
            SELECT
                COUNT(DISTINCT da.id) as total_dispatches,
                COUNT(DISTINCT CASE WHEN da.status = 'assigned' THEN da.id END) as assigned_count,
                COUNT(DISTINCT CASE WHEN da.status = 'started' THEN da.id END) as in_progress_count,
                COUNT(DISTINCT CASE WHEN da.status = 'completed' THEN da.id END) as completed_count,
                COUNT(DISTINCT da.vehicle_id) as vehicles_used,
                COUNT(DISTINCT da.driver_id) as drivers_assigned,
                COUNT(DISTINCT CASE WHEN da.binding_warning = TRUE THEN da.driver_id END) as drivers_with_warning
            FROM dispatch_assignments da
            WHERE da.company_id = $1 AND DATE(da.scheduled_start) = $2
        `, [companyId, today]);

        // 未割当受注数も取得
        const unassignedResult = await pool.query(`
            SELECT COUNT(*) FROM orders o
            LEFT JOIN dispatch_assignments da ON o.id = da.order_id AND da.status != 'cancelled'
            WHERE o.company_id = $1 AND o.status = 'pending' AND da.id IS NULL
              AND DATE(o.pickup_datetime) = $2
        `, [companyId, today]);

        res.json({
            date: today,
            ...result.rows[0],
            unassigned_orders: parseInt(unassignedResult.rows[0].count)
        });
    } catch (error) {
        console.error('Error fetching dispatch summary:', error);
        res.status(500).json({ error: 'Failed to fetch summary' });
    }
};

// ドライバー別スケジュール取得
export const getDriverSchedule = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;
    const { date, driver_id } = req.query;
    const targetDate = date || new Date().toISOString().split('T')[0];

    try {
        let query = `
            SELECT
                u.id as driver_id,
                u.name as driver_name,
                u.employee_number,
                COALESCE(
                    json_agg(
                        json_build_object(
                            'dispatch_id', da.id,
                            'order_number', o.order_number,
                            'shipper_name', s.name,
                            'scheduled_start', da.scheduled_start,
                            'scheduled_end', da.scheduled_end,
                            'status', da.status,
                            'pickup_location', pl.name,
                            'delivery_location', dl.name,
                            'cargo_name', o.cargo_name,
                            'binding_warning', da.binding_warning,
                            'vehicle_number', v.vehicle_number
                        ) ORDER BY da.scheduled_start
                    ) FILTER (WHERE da.id IS NOT NULL),
                    '[]'
                ) as dispatches
            FROM users u
            LEFT JOIN dispatch_assignments da ON u.id = da.driver_id AND DATE(da.scheduled_start) = $2 AND da.status != 'cancelled'
            LEFT JOIN orders o ON da.order_id = o.id
            LEFT JOIN shippers s ON o.shipper_id = s.id
            LEFT JOIN locations pl ON o.pickup_location_id = pl.id
            LEFT JOIN locations dl ON o.delivery_location_id = dl.id
            LEFT JOIN vehicles v ON da.vehicle_id = v.id
            WHERE u.company_id = $1 AND u.role = 'driver' AND u.is_active = TRUE
        `;
        const params: any[] = [companyId, targetDate];

        if (driver_id) {
            query += ` AND u.id = $3`;
            params.push(driver_id);
        }

        query += ' GROUP BY u.id, u.name, u.employee_number ORDER BY u.name';

        const result = await pool.query(query, params);
        res.json({
            date: targetDate,
            drivers: result.rows
        });
    } catch (error) {
        console.error('Error fetching driver schedule:', error);
        res.status(500).json({ error: 'Failed to fetch schedule' });
    }
};

// 車両別スケジュール取得
export const getVehicleSchedule = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;
    const { date, vehicle_id } = req.query;
    const targetDate = date || new Date().toISOString().split('T')[0];

    try {
        let query = `
            SELECT
                v.id as vehicle_id,
                v.vehicle_number,
                v.vehicle_type,
                COALESCE(
                    json_agg(
                        json_build_object(
                            'dispatch_id', da.id,
                            'order_number', o.order_number,
                            'driver_id', da.driver_id,
                            'driver_name', u.name,
                            'scheduled_start', da.scheduled_start,
                            'scheduled_end', da.scheduled_end,
                            'status', da.status,
                            'pickup_location', pl.name,
                            'delivery_location', dl.name
                        ) ORDER BY da.scheduled_start
                    ) FILTER (WHERE da.id IS NOT NULL),
                    '[]'
                ) as dispatches
            FROM vehicles v
            LEFT JOIN dispatch_assignments da ON v.id = da.vehicle_id AND DATE(da.scheduled_start) = $2 AND da.status != 'cancelled'
            LEFT JOIN orders o ON da.order_id = o.id
            LEFT JOIN users u ON da.driver_id = u.id
            LEFT JOIN locations pl ON o.pickup_location_id = pl.id
            LEFT JOIN locations dl ON o.delivery_location_id = dl.id
            WHERE v.company_id = $1 AND v.is_active = TRUE
        `;
        const params: any[] = [companyId, targetDate];

        if (vehicle_id) {
            query += ` AND v.id = $3`;
            params.push(vehicle_id);
        }

        query += ' GROUP BY v.id, v.vehicle_number, v.vehicle_type ORDER BY v.vehicle_number';

        const result = await pool.query(query, params);
        res.json({
            date: targetDate,
            vehicles: result.rows
        });
    } catch (error) {
        console.error('Error fetching vehicle schedule:', error);
        res.status(500).json({ error: 'Failed to fetch schedule' });
    }
};

// 配車割当作成
export const createDispatch = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;
    const userId = (req as any).user?.userId;
    const {
        order_id,
        vehicle_id,
        driver_id,
        scheduled_start,
        scheduled_end,
        estimated_distance,
        estimated_duration_minutes,
        notes
    } = req.body;

    if (!order_id || !vehicle_id || !driver_id || !scheduled_start) {
        return res.status(400).json({ error: 'order_id, vehicle_id, driver_id, scheduled_start are required' });
    }

    try {
        // 受注の存在確認
        const orderCheck = await pool.query(
            'SELECT * FROM orders WHERE id = $1 AND company_id = $2',
            [order_id, companyId]
        );
        if (orderCheck.rows.length === 0) {
            return res.status(404).json({ error: 'Order not found' });
        }

        // 重複チェック（同じ受注に対する有効な配車）
        const duplicateCheck = await pool.query(
            'SELECT id FROM dispatch_assignments WHERE order_id = $1 AND status != \'cancelled\'',
            [order_id]
        );
        if (duplicateCheck.rows.length > 0) {
            return res.status(400).json({ error: 'Order already has an active dispatch' });
        }

        // 車両の空き確認
        const vehicleConflict = await pool.query(`
            SELECT id FROM dispatch_assignments
            WHERE vehicle_id = $1 AND status NOT IN ('completed', 'cancelled')
              AND scheduled_start < $3 AND scheduled_end > $2
        `, [vehicle_id, scheduled_start, scheduled_end || scheduled_start]);
        if (vehicleConflict.rows.length > 0) {
            return res.status(400).json({ error: 'Vehicle is not available at this time' });
        }

        // ドライバーの空き確認
        const driverConflict = await pool.query(`
            SELECT id FROM dispatch_assignments
            WHERE driver_id = $1 AND status NOT IN ('completed', 'cancelled')
              AND scheduled_start < $3 AND scheduled_end > $2
        `, [driver_id, scheduled_start, scheduled_end || scheduled_start]);
        if (driverConflict.rows.length > 0) {
            return res.status(400).json({ error: 'Driver is not available at this time' });
        }

        // 拘束時間チェック
        const workDate = new Date(scheduled_start).toISOString().split('T')[0];
        const durationMinutes = estimated_duration_minutes || 240;

        const bindingCheck = await pool.query(`
            SELECT COALESCE(SUM(
                EXTRACT(EPOCH FROM (scheduled_end - scheduled_start)) / 60
            ), 0)::INTEGER as current_binding
            FROM dispatch_assignments
            WHERE driver_id = $1 AND DATE(scheduled_start) = $2 AND status NOT IN ('cancelled')
        `, [driver_id, workDate]);

        const currentBinding = parseInt(bindingCheck.rows[0].current_binding);
        const projectedBinding = currentBinding + durationMinutes;
        const bindingWarning = projectedBinding >= 780 * 0.9; // 13時間の90%

        // 配車作成
        const result = await pool.query(`
            INSERT INTO dispatch_assignments (
                company_id, order_id, vehicle_id, driver_id,
                scheduled_start, scheduled_end,
                estimated_distance, estimated_duration_minutes,
                driver_binding_before, driver_binding_after, binding_warning,
                notes, assigned_by
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
            RETURNING *
        `, [
            companyId, order_id, vehicle_id, driver_id,
            scheduled_start, scheduled_end,
            estimated_distance, durationMinutes,
            currentBinding, projectedBinding, bindingWarning,
            notes, userId
        ]);

        // 受注ステータス更新
        await pool.query(
            'UPDATE orders SET status = \'assigned\', updated_at = CURRENT_TIMESTAMP WHERE id = $1',
            [order_id]
        );

        // 履歴記録
        await pool.query(`
            INSERT INTO dispatch_history (dispatch_id, action, new_vehicle_id, new_driver_id, changed_by)
            VALUES ($1, 'created', $2, $3, $4)
        `, [result.rows[0].id, vehicle_id, driver_id, userId]);

        res.status(201).json({
            ...result.rows[0],
            binding_warning_message: bindingWarning
                ? `この配車により拘束時間が${Math.floor(projectedBinding / 60)}時間${projectedBinding % 60}分になります`
                : null
        });
    } catch (error) {
        console.error('Error creating dispatch:', error);
        res.status(500).json({ error: 'Failed to create dispatch' });
    }
};

// 配車更新（再割当）
export const updateDispatch = async (req: Request, res: Response) => {
    const { id } = req.params;
    const companyId = (req as any).user?.companyId;
    const userId = (req as any).user?.userId;
    const { vehicle_id, driver_id, scheduled_start, scheduled_end, notes, reason } = req.body;

    try {
        // 既存の配車を取得
        const current = await pool.query(
            'SELECT * FROM dispatch_assignments WHERE id = $1 AND company_id = $2',
            [id, companyId]
        );
        if (current.rows.length === 0) {
            return res.status(404).json({ error: 'Dispatch not found' });
        }

        const currentDispatch = current.rows[0];

        // 開始済みの配車は変更不可
        if (currentDispatch.status !== 'assigned') {
            return res.status(400).json({ error: 'Cannot modify dispatch that has already started' });
        }

        const newVehicleId = vehicle_id || currentDispatch.vehicle_id;
        const newDriverId = driver_id || currentDispatch.driver_id;
        const newStart = scheduled_start || currentDispatch.scheduled_start;
        const newEnd = scheduled_end || currentDispatch.scheduled_end;

        // 車両変更時の空き確認
        if (vehicle_id && vehicle_id !== currentDispatch.vehicle_id) {
            const conflict = await pool.query(`
                SELECT id FROM dispatch_assignments
                WHERE vehicle_id = $1 AND id != $2 AND status NOT IN ('completed', 'cancelled')
                  AND scheduled_start < $4 AND scheduled_end > $3
            `, [vehicle_id, id, newStart, newEnd]);
            if (conflict.rows.length > 0) {
                return res.status(400).json({ error: 'Vehicle is not available at this time' });
            }
        }

        // ドライバー変更時の空き確認
        if (driver_id && driver_id !== currentDispatch.driver_id) {
            const conflict = await pool.query(`
                SELECT id FROM dispatch_assignments
                WHERE driver_id = $1 AND id != $2 AND status NOT IN ('completed', 'cancelled')
                  AND scheduled_start < $4 AND scheduled_end > $3
            `, [driver_id, id, newStart, newEnd]);
            if (conflict.rows.length > 0) {
                return res.status(400).json({ error: 'Driver is not available at this time' });
            }
        }

        // 更新実行
        const result = await pool.query(`
            UPDATE dispatch_assignments SET
                vehicle_id = $1,
                driver_id = $2,
                scheduled_start = $3,
                scheduled_end = $4,
                notes = COALESCE($5, notes),
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $6
            RETURNING *
        `, [newVehicleId, newDriverId, newStart, newEnd, notes, id]);

        // 履歴記録
        if (vehicle_id !== currentDispatch.vehicle_id || driver_id !== currentDispatch.driver_id) {
            await pool.query(`
                INSERT INTO dispatch_history (
                    dispatch_id, action,
                    old_vehicle_id, new_vehicle_id,
                    old_driver_id, new_driver_id,
                    reason, changed_by
                ) VALUES ($1, 'reassigned', $2, $3, $4, $5, $6, $7)
            `, [
                id,
                currentDispatch.vehicle_id, newVehicleId,
                currentDispatch.driver_id, newDriverId,
                reason, userId
            ]);
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating dispatch:', error);
        res.status(500).json({ error: 'Failed to update dispatch' });
    }
};

// 配車開始
export const startDispatch = async (req: Request, res: Response) => {
    const { id } = req.params;
    const companyId = (req as any).user?.companyId;
    const userId = (req as any).user?.userId;

    try {
        const result = await pool.query(`
            UPDATE dispatch_assignments SET
                status = 'started',
                actual_start = CURRENT_TIMESTAMP,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $1 AND company_id = $2 AND status = 'assigned'
            RETURNING *
        `, [id, companyId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Dispatch not found or cannot be started' });
        }

        // 受注ステータス更新
        await pool.query(
            'UPDATE orders SET status = \'in_progress\', updated_at = CURRENT_TIMESTAMP WHERE id = $1',
            [result.rows[0].order_id]
        );

        // 履歴記録
        await pool.query(`
            INSERT INTO dispatch_history (dispatch_id, action, changed_by)
            VALUES ($1, 'started', $2)
        `, [id, userId]);

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error starting dispatch:', error);
        res.status(500).json({ error: 'Failed to start dispatch' });
    }
};

// 配車完了
export const completeDispatch = async (req: Request, res: Response) => {
    const { id } = req.params;
    const companyId = (req as any).user?.companyId;
    const userId = (req as any).user?.userId;
    const { actual_distance } = req.body;

    try {
        const result = await pool.query(`
            UPDATE dispatch_assignments SET
                status = 'completed',
                actual_end = CURRENT_TIMESTAMP,
                actual_distance = COALESCE($1, actual_distance),
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $2 AND company_id = $3 AND status = 'started'
            RETURNING *
        `, [actual_distance, id, companyId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Dispatch not found or cannot be completed' });
        }

        // 受注ステータス更新
        await pool.query(
            'UPDATE orders SET status = \'completed\', updated_at = CURRENT_TIMESTAMP WHERE id = $1',
            [result.rows[0].order_id]
        );

        // 履歴記録
        await pool.query(`
            INSERT INTO dispatch_history (dispatch_id, action, changed_by)
            VALUES ($1, 'completed', $2)
        `, [id, userId]);

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error completing dispatch:', error);
        res.status(500).json({ error: 'Failed to complete dispatch' });
    }
};

// 配車キャンセル
export const cancelDispatch = async (req: Request, res: Response) => {
    const { id } = req.params;
    const companyId = (req as any).user?.companyId;
    const userId = (req as any).user?.userId;
    const { reason } = req.body;

    try {
        const result = await pool.query(`
            UPDATE dispatch_assignments SET
                status = 'cancelled',
                notes = COALESCE(notes, '') || $1,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $2 AND company_id = $3 AND status IN ('assigned', 'started')
            RETURNING *
        `, [reason ? `\n[キャンセル理由] ${reason}` : '', id, companyId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Dispatch not found or cannot be cancelled' });
        }

        // 受注ステータスを戻す
        await pool.query(
            'UPDATE orders SET status = \'pending\', updated_at = CURRENT_TIMESTAMP WHERE id = $1',
            [result.rows[0].order_id]
        );

        // 履歴記録
        await pool.query(`
            INSERT INTO dispatch_history (dispatch_id, action, reason, changed_by)
            VALUES ($1, 'cancelled', $2, $3)
        `, [id, reason, userId]);

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error cancelling dispatch:', error);
        res.status(500).json({ error: 'Failed to cancel dispatch' });
    }
};

// 自動割当候補取得
export const getSuggestions = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;
    const { order_id } = req.query;

    if (!order_id) {
        return res.status(400).json({ error: 'order_id is required' });
    }

    try {
        // 受注を取得
        const orderResult = await pool.query(
            'SELECT * FROM orders WHERE id = $1 AND company_id = $2',
            [order_id, companyId]
        );

        if (orderResult.rows.length === 0) {
            return res.status(404).json({ error: 'Order not found' });
        }

        const order = orderResult.rows[0];

        // 所要時間見積もり
        const estimate = await autoAssignService.estimateDispatchDuration(
            order.pickup_location_id,
            order.delivery_location_id,
            order.pickup_address,
            order.delivery_address
        );

        // 割当候補を取得
        const suggestions = await autoAssignService.suggestAssignments(
            order,
            estimate.duration_minutes
        );

        res.json({
            order_id: parseInt(order_id as string),
            estimated_distance_km: estimate.distance_km,
            estimated_duration_minutes: estimate.duration_minutes,
            suggestions: suggestions.slice(0, 10) // 上位10件
        });
    } catch (error) {
        console.error('Error getting suggestions:', error);
        res.status(500).json({ error: 'Failed to get suggestions' });
    }
};

// 空き車両取得
export const getAvailableVehicles = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;
    const { start_time, end_time, vehicle_type, min_load_weight } = req.query;

    if (!start_time) {
        return res.status(400).json({ error: 'start_time is required' });
    }

    try {
        const vehicles = await autoAssignService.getAvailableVehicles(
            companyId,
            new Date(start_time as string),
            end_time ? new Date(end_time as string) : null,
            {
                vehicleType: vehicle_type as string,
                minLoadWeight: min_load_weight ? parseFloat(min_load_weight as string) : undefined
            }
        );

        res.json(vehicles);
    } catch (error) {
        console.error('Error getting available vehicles:', error);
        res.status(500).json({ error: 'Failed to get available vehicles' });
    }
};

// 空きドライバー取得
export const getAvailableDrivers = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;
    const { start_time, end_time, duration_minutes, license_type } = req.query;

    if (!start_time) {
        return res.status(400).json({ error: 'start_time is required' });
    }

    try {
        const drivers = await autoAssignService.getAvailableDrivers(
            companyId,
            new Date(start_time as string),
            end_time ? new Date(end_time as string) : null,
            parseInt(duration_minutes as string) || 240,
            {
                licenseType: license_type as string
            }
        );

        res.json(drivers);
    } catch (error) {
        console.error('Error getting available drivers:', error);
        res.status(500).json({ error: 'Failed to get available drivers' });
    }
};
