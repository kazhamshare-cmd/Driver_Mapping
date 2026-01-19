/**
 * Invoice Controller - 請求書管理
 */

import { Request, Response } from 'express';
import { pool } from '../index';
import { calculateFare, FareCalculationInput } from '../services/fareCalculationService';

interface AuthRequest extends Request {
    user?: { id: number; companyId: number; role: string };
}

/**
 * 請求書一覧取得
 */
export const getInvoices = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.query.companyId;
        const { status, shipperId, dateFrom, dateTo, page = 1, limit = 20 } = req.query;

        let query = `
            SELECT
                i.*,
                s.name AS shipper_name,
                s.address AS shipper_address,
                u.name AS created_by_name,
                (SELECT COUNT(*) FROM invoice_items WHERE invoice_id = i.id) AS item_count
            FROM invoices i
            LEFT JOIN shippers s ON i.shipper_id = s.id
            LEFT JOIN users u ON i.created_by = u.id
            WHERE i.company_id = $1
        `;
        const params: any[] = [companyId];

        if (status) {
            params.push(status);
            query += ` AND i.status = $${params.length}`;
        }

        if (shipperId) {
            params.push(shipperId);
            query += ` AND i.shipper_id = $${params.length}`;
        }

        if (dateFrom) {
            params.push(dateFrom);
            query += ` AND i.invoice_date >= $${params.length}`;
        }

        if (dateTo) {
            params.push(dateTo);
            query += ` AND i.invoice_date <= $${params.length}`;
        }

        query += ` ORDER BY i.invoice_date DESC, i.created_at DESC`;

        // ページネーション
        const offset = (Number(page) - 1) * Number(limit);
        params.push(limit, offset);
        query += ` LIMIT $${params.length - 1} OFFSET $${params.length}`;

        const result = await pool.query(query, params);

        // 総件数取得
        let countQuery = `SELECT COUNT(*) FROM invoices WHERE company_id = $1`;
        const countParams: any[] = [companyId];

        if (status) {
            countParams.push(status);
            countQuery += ` AND status = $${countParams.length}`;
        }
        if (shipperId) {
            countParams.push(shipperId);
            countQuery += ` AND shipper_id = $${countParams.length}`;
        }

        const countResult = await pool.query(countQuery, countParams);
        const total = parseInt(countResult.rows[0].count);

        res.json({
            invoices: result.rows,
            pagination: {
                page: Number(page),
                limit: Number(limit),
                total,
                totalPages: Math.ceil(total / Number(limit))
            }
        });
    } catch (error) {
        console.error('Failed to get invoices:', error);
        res.status(500).json({ error: '請求書一覧の取得に失敗しました' });
    }
};

/**
 * 請求書詳細取得
 */
export const getInvoiceById = async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const companyId = req.user?.companyId || req.query.companyId;

        // 請求書情報
        const invoiceResult = await pool.query(`
            SELECT
                i.*,
                s.name AS shipper_name,
                s.address AS shipper_address,
                s.contact_person AS shipper_contact,
                s.phone AS shipper_phone,
                s.email AS shipper_email,
                s.invoice_registration_number AS shipper_registration_number,
                c.name AS company_name,
                c.address AS company_address,
                c.phone AS company_phone
            FROM invoices i
            LEFT JOIN shippers s ON i.shipper_id = s.id
            LEFT JOIN companies c ON i.company_id = c.id
            WHERE i.id = $1 AND i.company_id = $2
        `, [id, companyId]);

        if (invoiceResult.rows.length === 0) {
            return res.status(404).json({ error: '請求書が見つかりません' });
        }

        // 明細取得
        const itemsResult = await pool.query(`
            SELECT * FROM invoice_items
            WHERE invoice_id = $1
            ORDER BY sort_order, id
        `, [id]);

        // 入金履歴取得
        const paymentsResult = await pool.query(`
            SELECT * FROM payments
            WHERE invoice_id = $1
            ORDER BY payment_date DESC
        `, [id]);

        res.json({
            invoice: invoiceResult.rows[0],
            items: itemsResult.rows,
            payments: paymentsResult.rows
        });
    } catch (error) {
        console.error('Failed to get invoice:', error);
        res.status(500).json({ error: '請求書の取得に失敗しました' });
    }
};

/**
 * 請求書作成
 */
export const createInvoice = async (req: AuthRequest, res: Response) => {
    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        const companyId = req.user?.companyId || req.body.companyId;
        const userId = req.user?.id;

        const {
            shipperId,
            invoiceDate,
            dueDate,
            billingPeriodStart,
            billingPeriodEnd,
            isQualifiedInvoice = true,
            registrationNumber,
            notes,
            items
        } = req.body;

        // 請求書作成（invoice_numberはトリガーで自動採番）
        const invoiceResult = await client.query(`
            INSERT INTO invoices (
                company_id, shipper_id, invoice_date, due_date,
                billing_period_start, billing_period_end,
                is_qualified_invoice, registration_number,
                notes, created_by, status
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'draft')
            RETURNING *
        `, [
            companyId, shipperId, invoiceDate, dueDate,
            billingPeriodStart, billingPeriodEnd,
            isQualifiedInvoice, registrationNumber,
            notes, userId
        ]);

        const invoiceId = invoiceResult.rows[0].id;

        // 明細追加
        let subtotal = 0;
        let totalTax = 0;

        if (items && items.length > 0) {
            for (let i = 0; i < items.length; i++) {
                const item = items[i];
                const amount = item.quantity * item.unitPrice;
                const taxAmount = Math.floor(amount * (item.taxRate || 10) / 100);

                await client.query(`
                    INSERT INTO invoice_items (
                        invoice_id, order_id, dispatch_id, item_type,
                        description, quantity, unit, unit_price,
                        amount, tax_rate, tax_amount,
                        work_date, route_info, vehicle_number, driver_name,
                        sort_order
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
                `, [
                    invoiceId, item.orderId, item.dispatchId, item.itemType,
                    item.description, item.quantity, item.unit || '式', item.unitPrice,
                    amount, item.taxRate || 10, taxAmount,
                    item.workDate, item.routeInfo, item.vehicleNumber, item.driverName,
                    i
                ]);

                subtotal += amount;
                totalTax += taxAmount;
            }
        }

        // 合計金額を更新
        await client.query(`
            UPDATE invoices SET
                subtotal = $1,
                tax_amount = $2,
                total_amount = $3,
                updated_at = NOW()
            WHERE id = $4
        `, [subtotal, totalTax, subtotal + totalTax, invoiceId]);

        await client.query('COMMIT');

        // 作成した請求書を取得して返す
        const result = await pool.query(`
            SELECT * FROM invoices WHERE id = $1
        `, [invoiceId]);

        res.status(201).json(result.rows[0]);
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Failed to create invoice:', error);
        res.status(500).json({ error: '請求書の作成に失敗しました' });
    } finally {
        client.release();
    }
};

/**
 * 完了した配車から請求書を自動生成
 */
export const generateInvoiceFromDispatches = async (req: AuthRequest, res: Response) => {
    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        const companyId = req.user?.companyId || req.body.companyId;
        const userId = req.user?.id;

        const {
            shipperId,
            dispatchIds,
            invoiceDate,
            dueDate,
            billingPeriodStart,
            billingPeriodEnd,
            isQualifiedInvoice = true,
            registrationNumber
        } = req.body;

        if (!dispatchIds || dispatchIds.length === 0) {
            return res.status(400).json({ error: '配車IDが指定されていません' });
        }

        // 配車情報取得
        const dispatchesResult = await client.query(`
            SELECT
                da.*,
                o.shipper_id,
                o.pickup_location,
                o.delivery_location,
                o.pickup_datetime,
                o.delivery_datetime,
                o.cargo_type,
                o.cargo_weight,
                v.vehicle_number,
                v.vehicle_type,
                u.name AS driver_name,
                EXTRACT(EPOCH FROM (da.actual_end - da.actual_start)) / 60 AS duration_minutes
            FROM dispatch_assignments da
            JOIN orders o ON da.order_id = o.id
            LEFT JOIN vehicles v ON da.vehicle_id = v.id
            LEFT JOIN users u ON da.driver_id = u.id
            WHERE da.id = ANY($1) AND da.status = 'completed'
        `, [dispatchIds]);

        if (dispatchesResult.rows.length === 0) {
            return res.status(400).json({ error: '完了した配車がありません' });
        }

        // 請求書作成
        const invoiceResult = await client.query(`
            INSERT INTO invoices (
                company_id, shipper_id, invoice_date, due_date,
                billing_period_start, billing_period_end,
                is_qualified_invoice, registration_number,
                created_by, status
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'draft')
            RETURNING *
        `, [
            companyId, shipperId, invoiceDate, dueDate,
            billingPeriodStart, billingPeriodEnd,
            isQualifiedInvoice, registrationNumber, userId
        ]);

        const invoiceId = invoiceResult.rows[0].id;

        // 各配車の運賃を計算して明細追加
        let subtotal = 0;
        let totalTax = 0;

        for (let i = 0; i < dispatchesResult.rows.length; i++) {
            const dispatch = dispatchesResult.rows[i];

            // 運賃計算
            const fareInput: FareCalculationInput = {
                companyId,
                shipperId: dispatch.shipper_id,
                workDate: new Date(dispatch.actual_start).toISOString().split('T')[0],
                startTime: new Date(dispatch.actual_start).toTimeString().slice(0, 5),
                endTime: new Date(dispatch.actual_end).toTimeString().slice(0, 5),
                drivingTimeMinutes: dispatch.duration_minutes,
                distanceKm: dispatch.actual_distance,
                vehicleType: dispatch.vehicle_type,
                hasLoading: true,
                hasUnloading: true
            };

            const fareResult = await calculateFare(fareInput);

            // 明細追加
            for (const item of fareResult.breakdown) {
                const taxAmount = Math.floor(item.amount * 10 / 100);

                await client.query(`
                    INSERT INTO invoice_items (
                        invoice_id, order_id, dispatch_id, item_type,
                        description, quantity, unit, unit_price,
                        amount, tax_rate, tax_amount,
                        work_date, route_info, vehicle_number, driver_name,
                        sort_order
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
                `, [
                    invoiceId, dispatch.order_id, dispatch.id, item.itemType,
                    item.description, item.quantity, item.unit, item.unitPrice,
                    item.amount, 10, taxAmount,
                    new Date(dispatch.actual_start).toISOString().split('T')[0],
                    `${dispatch.pickup_location} → ${dispatch.delivery_location}`,
                    dispatch.vehicle_number, dispatch.driver_name,
                    i * 10 + fareResult.breakdown.indexOf(item)
                ]);

                subtotal += item.amount;
                totalTax += taxAmount;
            }
        }

        // 合計金額を更新
        await client.query(`
            UPDATE invoices SET
                subtotal = $1,
                tax_amount = $2,
                total_amount = $3,
                updated_at = NOW()
            WHERE id = $4
        `, [subtotal, totalTax, subtotal + totalTax, invoiceId]);

        await client.query('COMMIT');

        // 作成した請求書を取得
        const result = await pool.query(`
            SELECT * FROM invoices WHERE id = $1
        `, [invoiceId]);

        res.status(201).json(result.rows[0]);
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Failed to generate invoice:', error);
        res.status(500).json({ error: '請求書の自動生成に失敗しました' });
    } finally {
        client.release();
    }
};

/**
 * 請求書ステータス更新
 */
export const updateInvoiceStatus = async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const { status } = req.body;
        const companyId = req.user?.companyId || req.body.companyId;

        const validStatuses = ['draft', 'issued', 'sent', 'paid', 'partial', 'overdue', 'cancelled'];
        if (!validStatuses.includes(status)) {
            return res.status(400).json({ error: '無効なステータスです' });
        }

        let updateFields = 'status = $1, updated_at = NOW()';
        const params: any[] = [status, id, companyId];

        if (status === 'sent') {
            updateFields += ', sent_at = NOW()';
        }

        const result = await pool.query(`
            UPDATE invoices SET ${updateFields}
            WHERE id = $2 AND company_id = $3
            RETURNING *
        `, params);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: '請求書が見つかりません' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Failed to update invoice status:', error);
        res.status(500).json({ error: '請求書ステータスの更新に失敗しました' });
    }
};

/**
 * 請求書削除（下書きのみ）
 */
export const deleteInvoice = async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const companyId = req.user?.companyId || req.query.companyId;

        // 下書きのみ削除可能
        const result = await pool.query(`
            DELETE FROM invoices
            WHERE id = $1 AND company_id = $2 AND status = 'draft'
            RETURNING id
        `, [id, companyId]);

        if (result.rows.length === 0) {
            return res.status(400).json({ error: '下書き状態の請求書のみ削除できます' });
        }

        res.json({ message: '請求書を削除しました' });
    } catch (error) {
        console.error('Failed to delete invoice:', error);
        res.status(500).json({ error: '請求書の削除に失敗しました' });
    }
};

/**
 * 売掛金残高取得
 */
export const getAccountsReceivable = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.query.companyId;

        const result = await pool.query(`
            SELECT * FROM accounts_receivable
            WHERE company_id = $1
            ORDER BY outstanding_balance DESC
        `, [companyId]);

        // サマリー計算
        const summary = result.rows.reduce((acc, row) => ({
            totalBilled: acc.totalBilled + parseFloat(row.total_billed || 0),
            totalPaid: acc.totalPaid + parseFloat(row.total_paid || 0),
            outstandingBalance: acc.outstandingBalance + parseFloat(row.outstanding_balance || 0),
            overdueBalance: acc.overdueBalance + parseFloat(row.overdue_balance || 0)
        }), { totalBilled: 0, totalPaid: 0, outstandingBalance: 0, overdueBalance: 0 });

        res.json({
            accounts: result.rows,
            summary
        });
    } catch (error) {
        console.error('Failed to get accounts receivable:', error);
        res.status(500).json({ error: '売掛金残高の取得に失敗しました' });
    }
};

/**
 * 月別売上サマリー取得
 */
export const getRevenueSummary = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.query.companyId;
        const { year } = req.query;

        let query = `
            SELECT * FROM monthly_revenue_summary
            WHERE company_id = $1
        `;
        const params: any[] = [companyId];

        if (year) {
            params.push(year);
            query += ` AND EXTRACT(YEAR FROM month) = $${params.length}`;
        }

        query += ` ORDER BY month DESC`;

        const result = await pool.query(query, params);

        res.json(result.rows);
    } catch (error) {
        console.error('Failed to get revenue summary:', error);
        res.status(500).json({ error: '売上サマリーの取得に失敗しました' });
    }
};

/**
 * 運賃マスタ一覧取得
 */
export const getFareMasters = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.query.companyId;
        const { shipperId, isActive } = req.query;

        let query = `
            SELECT fm.*, s.name AS shipper_name
            FROM fare_masters fm
            LEFT JOIN shippers s ON fm.shipper_id = s.id
            WHERE fm.company_id = $1
        `;
        const params: any[] = [companyId];

        if (shipperId) {
            params.push(shipperId);
            query += ` AND fm.shipper_id = $${params.length}`;
        }

        if (isActive !== undefined) {
            params.push(isActive === 'true');
            query += ` AND fm.is_active = $${params.length}`;
        }

        query += ` ORDER BY fm.shipper_id NULLS LAST, fm.name`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Failed to get fare masters:', error);
        res.status(500).json({ error: '運賃マスタの取得に失敗しました' });
    }
};

/**
 * 運賃マスタ作成
 */
export const createFareMaster = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.body.companyId;

        const {
            shipperId, name, fareType,
            baseDistanceKm, baseRate, ratePerKm,
            baseTimeHours, ratePerHour, fixedRate,
            nightSurchargeRate, earlyMorningSurchargeRate, holidaySurchargeRate,
            loadingFee, unloadingFee, waitingFeePerHour,
            vehicleTypeCoefficients, effectiveFrom, effectiveTo
        } = req.body;

        const result = await pool.query(`
            INSERT INTO fare_masters (
                company_id, shipper_id, name, fare_type,
                base_distance_km, base_rate, rate_per_km,
                base_time_hours, rate_per_hour, fixed_rate,
                night_surcharge_rate, early_morning_surcharge_rate, holiday_surcharge_rate,
                loading_fee, unloading_fee, waiting_fee_per_hour,
                vehicle_type_coefficients, effective_from, effective_to
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19)
            RETURNING *
        `, [
            companyId, shipperId, name, fareType,
            baseDistanceKm || 0, baseRate || 0, ratePerKm || 0,
            baseTimeHours || 0, ratePerHour || 0, fixedRate || 0,
            nightSurchargeRate || 25, earlyMorningSurchargeRate || 25, holidaySurchargeRate || 35,
            loadingFee || 0, unloadingFee || 0, waitingFeePerHour || 0,
            JSON.stringify(vehicleTypeCoefficients || {}),
            effectiveFrom || new Date().toISOString().split('T')[0],
            effectiveTo
        ]);

        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Failed to create fare master:', error);
        res.status(500).json({ error: '運賃マスタの作成に失敗しました' });
    }
};

/**
 * 運賃マスタ更新
 */
export const updateFareMaster = async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const companyId = req.user?.companyId || req.body.companyId;

        const {
            name, fareType,
            baseDistanceKm, baseRate, ratePerKm,
            baseTimeHours, ratePerHour, fixedRate,
            nightSurchargeRate, earlyMorningSurchargeRate, holidaySurchargeRate,
            loadingFee, unloadingFee, waitingFeePerHour,
            vehicleTypeCoefficients, effectiveFrom, effectiveTo, isActive
        } = req.body;

        const result = await pool.query(`
            UPDATE fare_masters SET
                name = COALESCE($1, name),
                fare_type = COALESCE($2, fare_type),
                base_distance_km = COALESCE($3, base_distance_km),
                base_rate = COALESCE($4, base_rate),
                rate_per_km = COALESCE($5, rate_per_km),
                base_time_hours = COALESCE($6, base_time_hours),
                rate_per_hour = COALESCE($7, rate_per_hour),
                fixed_rate = COALESCE($8, fixed_rate),
                night_surcharge_rate = COALESCE($9, night_surcharge_rate),
                early_morning_surcharge_rate = COALESCE($10, early_morning_surcharge_rate),
                holiday_surcharge_rate = COALESCE($11, holiday_surcharge_rate),
                loading_fee = COALESCE($12, loading_fee),
                unloading_fee = COALESCE($13, unloading_fee),
                waiting_fee_per_hour = COALESCE($14, waiting_fee_per_hour),
                vehicle_type_coefficients = COALESCE($15, vehicle_type_coefficients),
                effective_from = COALESCE($16, effective_from),
                effective_to = $17,
                is_active = COALESCE($18, is_active),
                updated_at = NOW()
            WHERE id = $19 AND company_id = $20
            RETURNING *
        `, [
            name, fareType,
            baseDistanceKm, baseRate, ratePerKm,
            baseTimeHours, ratePerHour, fixedRate,
            nightSurchargeRate, earlyMorningSurchargeRate, holidaySurchargeRate,
            loadingFee, unloadingFee, waitingFeePerHour,
            vehicleTypeCoefficients ? JSON.stringify(vehicleTypeCoefficients) : null,
            effectiveFrom, effectiveTo, isActive,
            id, companyId
        ]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: '運賃マスタが見つかりません' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Failed to update fare master:', error);
        res.status(500).json({ error: '運賃マスタの更新に失敗しました' });
    }
};

/**
 * 運賃計算（プレビュー）
 */
export const calculateFarePreview = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.body.companyId;

        const input: FareCalculationInput = {
            companyId,
            ...req.body
        };

        const result = await calculateFare(input);
        res.json(result);
    } catch (error) {
        console.error('Failed to calculate fare:', error);
        res.status(500).json({ error: '運賃計算に失敗しました' });
    }
};
