/**
 * Order Controller - 受注管理API
 */

import { Request, Response } from 'express';
import { pool } from '../utils/db';

// 受注一覧取得
export const getOrders = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;
    const {
        status,
        shipper_id,
        date_from,
        date_to,
        search,
        limit,
        offset
    } = req.query;

    try {
        let query = `
            SELECT
                o.*,
                s.name as shipper_name,
                pl.name as pickup_location_name,
                dl.name as delivery_location_name,
                da.id as dispatch_id,
                da.status as dispatch_status,
                da.vehicle_id,
                da.driver_id,
                v.vehicle_number,
                u.name as driver_name
            FROM orders o
            LEFT JOIN shippers s ON o.shipper_id = s.id
            LEFT JOIN locations pl ON o.pickup_location_id = pl.id
            LEFT JOIN locations dl ON o.delivery_location_id = dl.id
            LEFT JOIN dispatch_assignments da ON o.id = da.order_id AND da.status != 'cancelled'
            LEFT JOIN vehicles v ON da.vehicle_id = v.id
            LEFT JOIN users u ON da.driver_id = u.id
            WHERE o.company_id = $1
        `;
        const params: any[] = [companyId];
        let paramIndex = 2;

        if (status) {
            query += ` AND o.status = $${paramIndex}`;
            params.push(status);
            paramIndex++;
        }

        if (shipper_id) {
            query += ` AND o.shipper_id = $${paramIndex}`;
            params.push(shipper_id);
            paramIndex++;
        }

        if (date_from) {
            query += ` AND o.pickup_datetime >= $${paramIndex}`;
            params.push(date_from);
            paramIndex++;
        }

        if (date_to) {
            query += ` AND o.pickup_datetime <= $${paramIndex}`;
            params.push(date_to);
            paramIndex++;
        }

        if (search) {
            query += ` AND (o.order_number ILIKE $${paramIndex} OR o.cargo_name ILIKE $${paramIndex} OR s.name ILIKE $${paramIndex})`;
            params.push(`%${search}%`);
            paramIndex++;
        }

        query += ' ORDER BY o.pickup_datetime DESC';

        if (limit) {
            query += ` LIMIT $${paramIndex}`;
            params.push(parseInt(limit as string));
            paramIndex++;
        }

        if (offset) {
            query += ` OFFSET $${paramIndex}`;
            params.push(parseInt(offset as string));
            paramIndex++;
        }

        const result = await pool.query(query, params);

        // 総件数も取得
        const countResult = await pool.query(`
            SELECT COUNT(*) FROM orders o WHERE o.company_id = $1
            ${status ? `AND o.status = '${status}'` : ''}
        `, [companyId]);

        res.json({
            orders: result.rows,
            total: parseInt(countResult.rows[0].count)
        });
    } catch (error) {
        console.error('Error fetching orders:', error);
        res.status(500).json({ error: 'Failed to fetch orders' });
    }
};

// 未割当受注一覧取得
export const getUnassignedOrders = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;
    const { date } = req.query;

    try {
        let query = `
            SELECT
                o.*,
                s.name as shipper_name,
                pl.name as pickup_location_name,
                dl.name as delivery_location_name
            FROM orders o
            LEFT JOIN shippers s ON o.shipper_id = s.id
            LEFT JOIN locations pl ON o.pickup_location_id = pl.id
            LEFT JOIN locations dl ON o.delivery_location_id = dl.id
            LEFT JOIN dispatch_assignments da ON o.id = da.order_id AND da.status != 'cancelled'
            WHERE o.company_id = $1 AND o.status = 'pending' AND da.id IS NULL
        `;
        const params: any[] = [companyId];

        if (date) {
            query += ` AND DATE(o.pickup_datetime) = $2`;
            params.push(date);
        }

        query += ' ORDER BY o.priority ASC, o.pickup_datetime ASC';

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching unassigned orders:', error);
        res.status(500).json({ error: 'Failed to fetch unassigned orders' });
    }
};

// 受注詳細取得
export const getOrderById = async (req: Request, res: Response) => {
    const { id } = req.params;
    const companyId = (req as any).user?.companyId;

    try {
        const result = await pool.query(`
            SELECT
                o.*,
                s.name as shipper_name,
                s.phone as shipper_phone,
                pl.name as pickup_location_name,
                pl.address as pickup_location_address,
                dl.name as delivery_location_name,
                dl.address as delivery_location_address,
                receiver.name as received_by_name
            FROM orders o
            LEFT JOIN shippers s ON o.shipper_id = s.id
            LEFT JOIN locations pl ON o.pickup_location_id = pl.id
            LEFT JOIN locations dl ON o.delivery_location_id = dl.id
            LEFT JOIN users receiver ON o.received_by = receiver.id
            WHERE o.id = $1 AND o.company_id = $2
        `, [id, companyId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Order not found' });
        }

        // 配車情報も取得
        const dispatchResult = await pool.query(`
            SELECT
                da.*,
                v.vehicle_number,
                u.name as driver_name
            FROM dispatch_assignments da
            LEFT JOIN vehicles v ON da.vehicle_id = v.id
            LEFT JOIN users u ON da.driver_id = u.id
            WHERE da.order_id = $1
            ORDER BY da.created_at DESC
        `, [id]);

        res.json({
            ...result.rows[0],
            dispatches: dispatchResult.rows
        });
    } catch (error) {
        console.error('Error fetching order:', error);
        res.status(500).json({ error: 'Failed to fetch order' });
    }
};

// 受注番号生成
const generateOrderNumber = async (companyId: number): Promise<string> => {
    const today = new Date();
    const prefix = `ORD${today.getFullYear()}${String(today.getMonth() + 1).padStart(2, '0')}${String(today.getDate()).padStart(2, '0')}`;

    const result = await pool.query(`
        SELECT COUNT(*) FROM orders
        WHERE company_id = $1 AND order_number LIKE $2
    `, [companyId, `${prefix}%`]);

    const count = parseInt(result.rows[0].count) + 1;
    return `${prefix}-${String(count).padStart(4, '0')}`;
};

// 受注作成
export const createOrder = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;
    const userId = (req as any).user?.userId;
    const {
        order_number,
        shipper_id,
        pickup_location_id,
        pickup_address,
        pickup_datetime,
        pickup_datetime_end,
        delivery_location_id,
        delivery_address,
        delivery_datetime,
        delivery_datetime_end,
        cargo_type,
        cargo_name,
        cargo_weight,
        cargo_volume,
        cargo_quantity,
        cargo_unit,
        is_fragile,
        requires_temperature_control,
        temperature_min,
        temperature_max,
        required_vehicle_type,
        required_license_type,
        base_fare,
        additional_charges,
        toll_fee,
        priority,
        customer_notes,
        internal_notes
    } = req.body;

    if (!pickup_datetime) {
        return res.status(400).json({ error: 'Pickup datetime is required' });
    }

    try {
        // 受注番号を自動生成（指定がない場合）
        const orderNum = order_number || await generateOrderNumber(companyId);

        // 合計運賃計算
        const totalFare = (parseFloat(base_fare) || 0) +
            (parseFloat(additional_charges) || 0) +
            (parseFloat(toll_fee) || 0);

        const result = await pool.query(`
            INSERT INTO orders (
                company_id, order_number, shipper_id,
                pickup_location_id, pickup_address, pickup_datetime, pickup_datetime_end,
                delivery_location_id, delivery_address, delivery_datetime, delivery_datetime_end,
                cargo_type, cargo_name, cargo_weight, cargo_volume, cargo_quantity, cargo_unit,
                is_fragile, requires_temperature_control, temperature_min, temperature_max,
                required_vehicle_type, required_license_type,
                base_fare, additional_charges, toll_fee, total_fare,
                priority, customer_notes, internal_notes, received_by
            ) VALUES (
                $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17,
                $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31
            )
            RETURNING *
        `, [
            companyId, orderNum, shipper_id,
            pickup_location_id, pickup_address, pickup_datetime, pickup_datetime_end,
            delivery_location_id, delivery_address, delivery_datetime, delivery_datetime_end,
            cargo_type, cargo_name, cargo_weight, cargo_volume, cargo_quantity, cargo_unit,
            is_fragile || false, requires_temperature_control || false, temperature_min, temperature_max,
            required_vehicle_type, required_license_type,
            base_fare, additional_charges || 0, toll_fee || 0, totalFare,
            priority || 3, customer_notes, internal_notes, userId
        ]);

        res.status(201).json(result.rows[0]);
    } catch (error: any) {
        if (error.code === '23505') {
            return res.status(400).json({ error: 'Order number already exists' });
        }
        console.error('Error creating order:', error);
        res.status(500).json({ error: 'Failed to create order' });
    }
};

// 受注更新
export const updateOrder = async (req: Request, res: Response) => {
    const { id } = req.params;
    const companyId = (req as any).user?.companyId;
    const updates = req.body;

    try {
        // 動的にUPDATE文を構築
        const allowedFields = [
            'shipper_id', 'pickup_location_id', 'pickup_address', 'pickup_datetime', 'pickup_datetime_end',
            'delivery_location_id', 'delivery_address', 'delivery_datetime', 'delivery_datetime_end',
            'cargo_type', 'cargo_name', 'cargo_weight', 'cargo_volume', 'cargo_quantity', 'cargo_unit',
            'is_fragile', 'requires_temperature_control', 'temperature_min', 'temperature_max',
            'required_vehicle_type', 'required_license_type',
            'base_fare', 'additional_charges', 'toll_fee',
            'priority', 'customer_notes', 'internal_notes', 'status'
        ];

        const setClauses: string[] = [];
        const values: any[] = [];
        let paramIndex = 1;

        for (const field of allowedFields) {
            if (updates[field] !== undefined) {
                setClauses.push(`${field} = $${paramIndex}`);
                values.push(updates[field]);
                paramIndex++;
            }
        }

        if (setClauses.length === 0) {
            return res.status(400).json({ error: 'No valid fields to update' });
        }

        // 合計運賃を再計算
        if (updates.base_fare !== undefined || updates.additional_charges !== undefined || updates.toll_fee !== undefined) {
            const currentOrder = await pool.query('SELECT base_fare, additional_charges, toll_fee FROM orders WHERE id = $1', [id]);
            if (currentOrder.rows.length > 0) {
                const current = currentOrder.rows[0];
                const totalFare =
                    (parseFloat(updates.base_fare ?? current.base_fare) || 0) +
                    (parseFloat(updates.additional_charges ?? current.additional_charges) || 0) +
                    (parseFloat(updates.toll_fee ?? current.toll_fee) || 0);
                setClauses.push(`total_fare = $${paramIndex}`);
                values.push(totalFare);
                paramIndex++;
            }
        }

        setClauses.push('updated_at = CURRENT_TIMESTAMP');

        values.push(id, companyId);

        const result = await pool.query(`
            UPDATE orders SET ${setClauses.join(', ')}
            WHERE id = $${paramIndex} AND company_id = $${paramIndex + 1}
            RETURNING *
        `, values);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Order not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating order:', error);
        res.status(500).json({ error: 'Failed to update order' });
    }
};

// 受注キャンセル
export const cancelOrder = async (req: Request, res: Response) => {
    const { id } = req.params;
    const companyId = (req as any).user?.companyId;
    const { reason } = req.body;

    try {
        // まず配車をキャンセル
        await pool.query(`
            UPDATE dispatch_assignments SET status = 'cancelled', updated_at = CURRENT_TIMESTAMP
            WHERE order_id = $1
        `, [id]);

        // 受注をキャンセル
        const result = await pool.query(`
            UPDATE orders SET
                status = 'cancelled',
                internal_notes = COALESCE(internal_notes, '') || $1,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $2 AND company_id = $3
            RETURNING *
        `, [reason ? `\n[キャンセル理由] ${reason}` : '', id, companyId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Order not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error cancelling order:', error);
        res.status(500).json({ error: 'Failed to cancel order' });
    }
};

// 受注削除
export const deleteOrder = async (req: Request, res: Response) => {
    const { id } = req.params;
    const companyId = (req as any).user?.companyId;

    try {
        // 配車があるか確認
        const dispatchCheck = await pool.query(
            'SELECT COUNT(*) FROM dispatch_assignments WHERE order_id = $1 AND status != \'cancelled\'',
            [id]
        );

        if (parseInt(dispatchCheck.rows[0].count) > 0) {
            return res.status(400).json({ error: 'Cannot delete order with active dispatch. Cancel first.' });
        }

        const result = await pool.query(
            'DELETE FROM orders WHERE id = $1 AND company_id = $2 AND status IN (\'pending\', \'cancelled\') RETURNING id',
            [id, companyId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Order not found or cannot be deleted' });
        }

        res.json({ message: 'Order deleted' });
    } catch (error) {
        console.error('Error deleting order:', error);
        res.status(500).json({ error: 'Failed to delete order' });
    }
};

// 受注統計取得
export const getOrderStats = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;
    const { date_from, date_to } = req.query;

    const fromDate = date_from || new Date().toISOString().split('T')[0];
    const toDate = date_to || new Date().toISOString().split('T')[0];

    try {
        const result = await pool.query(`
            SELECT
                COUNT(*) as total_orders,
                COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_count,
                COUNT(CASE WHEN status = 'assigned' THEN 1 END) as assigned_count,
                COUNT(CASE WHEN status = 'in_progress' THEN 1 END) as in_progress_count,
                COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_count,
                COUNT(CASE WHEN status = 'cancelled' THEN 1 END) as cancelled_count,
                COALESCE(SUM(total_fare), 0) as total_fare_sum,
                COALESCE(AVG(total_fare), 0) as avg_fare
            FROM orders
            WHERE company_id = $1 AND pickup_datetime >= $2 AND pickup_datetime <= $3
        `, [companyId, fromDate, toDate + ' 23:59:59']);

        res.json({
            period: { from: fromDate, to: toDate },
            ...result.rows[0]
        });
    } catch (error) {
        console.error('Error fetching order stats:', error);
        res.status(500).json({ error: 'Failed to fetch order stats' });
    }
};
