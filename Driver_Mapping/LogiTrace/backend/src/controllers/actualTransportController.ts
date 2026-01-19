/**
 * Actual Transport Controller
 * 実運送体制管理簿（2024年法改正対応）
 */

import { Request, Response } from 'express';
import { pool } from '../index';

// ============================================
// 下請契約管理
// ============================================

/**
 * 下請契約一覧取得
 */
export const getSubcontractAgreements = async (req: Request, res: Response) => {
    try {
        const { companyId, status } = req.query;

        let query = `
            SELECT * FROM subcontract_agreements
            WHERE company_id = $1
        `;
        const params: any[] = [companyId];

        if (status) {
            query += ` AND status = $2`;
            params.push(status);
        }

        query += ` ORDER BY agreement_date DESC`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching subcontract agreements:', error);
        res.status(500).json({ error: 'Failed to fetch subcontract agreements' });
    }
};

/**
 * 下請契約作成
 */
export const createSubcontractAgreement = async (req: Request, res: Response) => {
    try {
        const {
            companyId, primeContractorName, primeContractorPermitNumber, primeContractorAddress,
            subcontractorTier, agreementNumber, agreementDate, agreementStartDate, agreementEndDate,
            commissionRate, paymentTerms
        } = req.body;

        const result = await pool.query(`
            INSERT INTO subcontract_agreements (
                company_id, prime_contractor_name, prime_contractor_permit_number, prime_contractor_address,
                subcontractor_tier, agreement_number, agreement_date, agreement_start_date, agreement_end_date,
                commission_rate, payment_terms
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            RETURNING *
        `, [
            companyId, primeContractorName, primeContractorPermitNumber, primeContractorAddress,
            subcontractorTier || 1, agreementNumber, agreementDate, agreementStartDate, agreementEndDate,
            commissionRate, paymentTerms
        ]);

        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error creating subcontract agreement:', error);
        res.status(500).json({ error: 'Failed to create subcontract agreement' });
    }
};

/**
 * 下請契約更新
 */
export const updateSubcontractAgreement = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const updates = req.body;

        const fields = Object.keys(updates).filter(k => k !== 'id');
        const setClause = fields.map((f, i) => `${f} = $${i + 2}`).join(', ');
        const values = fields.map(f => updates[f]);

        const result = await pool.query(`
            UPDATE subcontract_agreements
            SET ${setClause}, updated_at = NOW()
            WHERE id = $1
            RETURNING *
        `, [id, ...values]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Agreement not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating subcontract agreement:', error);
        res.status(500).json({ error: 'Failed to update subcontract agreement' });
    }
};

// ============================================
// 実運送体制管理簿
// ============================================

/**
 * 実運送体制管理簿一覧取得
 */
export const getActualTransportRecords = async (req: Request, res: Response) => {
    try {
        const { companyId, startDate, endDate, status, shipperId } = req.query;

        let query = `
            SELECT
                atr.*,
                o.order_number,
                u.name as confirmed_by_name
            FROM actual_transport_records atr
            LEFT JOIN orders o ON atr.order_id = o.id
            LEFT JOIN users u ON atr.confirmed_by = u.id
            WHERE atr.company_id = $1
        `;
        const params: any[] = [companyId];
        let paramIndex = 2;

        if (startDate) {
            query += ` AND atr.transport_date >= $${paramIndex++}`;
            params.push(startDate);
        }

        if (endDate) {
            query += ` AND atr.transport_date <= $${paramIndex++}`;
            params.push(endDate);
        }

        if (status) {
            query += ` AND atr.status = $${paramIndex++}`;
            params.push(status);
        }

        if (shipperId) {
            query += ` AND atr.shipper_name ILIKE $${paramIndex++}`;
            params.push(`%${shipperId}%`);
        }

        query += ` ORDER BY atr.transport_date DESC, atr.record_number DESC`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching actual transport records:', error);
        res.status(500).json({ error: 'Failed to fetch records' });
    }
};

/**
 * 実運送体制管理簿詳細取得
 */
export const getActualTransportRecordById = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        const result = await pool.query(`
            SELECT
                atr.*,
                o.order_number,
                u.name as confirmed_by_name
            FROM actual_transport_records atr
            LEFT JOIN orders o ON atr.order_id = o.id
            LEFT JOIN users u ON atr.confirmed_by = u.id
            WHERE atr.id = $1
        `, [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Record not found' });
        }

        // 監査証跡も取得
        const auditResult = await pool.query(`
            SELECT tral.*, u.name as performed_by_name
            FROM transport_record_audit_log tral
            LEFT JOIN users u ON tral.performed_by = u.id
            WHERE tral.record_id = $1
            ORDER BY tral.performed_at DESC
        `, [id]);

        res.json({
            ...result.rows[0],
            auditLog: auditResult.rows
        });
    } catch (error) {
        console.error('Error fetching actual transport record:', error);
        res.status(500).json({ error: 'Failed to fetch record' });
    }
};

/**
 * 実運送体制管理簿作成
 */
export const createActualTransportRecord = async (req: Request, res: Response) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        const {
            companyId, orderId, recordNumber, transportDate,
            shipperName, shipperAddress, transportChain,
            actualCarrierName, actualCarrierPermitNumber, actualCarrierAddress, actualCarrierTier,
            cargoDescription, pickupLocation, deliveryLocation, pickupDatetime, deliveryDatetime,
            vehicleNumber, vehicleType, driverName,
            shipperFare, actualCarrierFare, intermediateMargins, notes, userId
        } = req.body;

        const result = await client.query(`
            INSERT INTO actual_transport_records (
                company_id, order_id, record_number, transport_date,
                shipper_name, shipper_address, transport_chain,
                actual_carrier_name, actual_carrier_permit_number, actual_carrier_address, actual_carrier_tier,
                cargo_description, pickup_location, delivery_location, pickup_datetime, delivery_datetime,
                vehicle_number, vehicle_type, driver_name,
                shipper_fare, actual_carrier_fare, intermediate_margins, notes
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23)
            RETURNING *
        `, [
            companyId, orderId, recordNumber, transportDate,
            shipperName, shipperAddress, JSON.stringify(transportChain),
            actualCarrierName, actualCarrierPermitNumber, actualCarrierAddress, actualCarrierTier,
            cargoDescription, pickupLocation, deliveryLocation, pickupDatetime, deliveryDatetime,
            vehicleNumber, vehicleType, driverName,
            shipperFare, actualCarrierFare, JSON.stringify(intermediateMargins || []), notes
        ]);

        // 監査証跡
        await client.query(`
            INSERT INTO transport_record_audit_log (record_id, action, performed_by, details)
            VALUES ($1, 'created', $2, $3)
        `, [result.rows[0].id, userId, JSON.stringify({ record_number: recordNumber })]);

        await client.query('COMMIT');
        res.status(201).json(result.rows[0]);
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Error creating actual transport record:', error);
        res.status(500).json({ error: 'Failed to create record' });
    } finally {
        client.release();
    }
};

/**
 * 実運送体制管理簿更新
 */
export const updateActualTransportRecord = async (req: Request, res: Response) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        const { id } = req.params;
        const { userId, ...updates } = req.body;

        // transport_chainとintermediate_marginsはJSONB
        if (updates.transportChain) {
            updates.transport_chain = JSON.stringify(updates.transportChain);
            delete updates.transportChain;
        }
        if (updates.intermediateMargins) {
            updates.intermediate_margins = JSON.stringify(updates.intermediateMargins);
            delete updates.intermediateMargins;
        }

        const fields = Object.keys(updates);
        const setClause = fields.map((f, i) => `${f} = $${i + 2}`).join(', ');
        const values = fields.map(f => updates[f]);

        const result = await client.query(`
            UPDATE actual_transport_records
            SET ${setClause}, updated_at = NOW()
            WHERE id = $1
            RETURNING *
        `, [id, ...values]);

        if (result.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ error: 'Record not found' });
        }

        // 監査証跡
        await client.query(`
            INSERT INTO transport_record_audit_log (record_id, action, performed_by, details)
            VALUES ($1, 'updated', $2, $3)
        `, [id, userId, JSON.stringify(updates)]);

        await client.query('COMMIT');
        res.json(result.rows[0]);
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Error updating actual transport record:', error);
        res.status(500).json({ error: 'Failed to update record' });
    } finally {
        client.release();
    }
};

/**
 * 実運送体制管理簿確認（承認）
 */
export const confirmActualTransportRecord = async (req: Request, res: Response) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        const { id } = req.params;
        const { userId } = req.body;

        const result = await client.query(`
            UPDATE actual_transport_records
            SET status = 'confirmed', confirmed_by = $2, confirmed_at = NOW(), updated_at = NOW()
            WHERE id = $1
            RETURNING *
        `, [id, userId]);

        if (result.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ error: 'Record not found' });
        }

        // 監査証跡
        await client.query(`
            INSERT INTO transport_record_audit_log (record_id, action, performed_by, details)
            VALUES ($1, 'confirmed', $2, $3)
        `, [id, userId, JSON.stringify({ confirmed_at: new Date() })]);

        await client.query('COMMIT');
        res.json(result.rows[0]);
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Error confirming record:', error);
        res.status(500).json({ error: 'Failed to confirm record' });
    } finally {
        client.release();
    }
};

/**
 * 実運送体制管理簿を行政に提出済みとしてマーク
 */
export const submitActualTransportRecord = async (req: Request, res: Response) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        const { id } = req.params;
        const { userId, submissionDate } = req.body;

        const result = await client.query(`
            UPDATE actual_transport_records
            SET status = 'submitted', submitted_to_authority = TRUE, submission_date = $2, updated_at = NOW()
            WHERE id = $1
            RETURNING *
        `, [id, submissionDate || new Date()]);

        if (result.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ error: 'Record not found' });
        }

        // 監査証跡
        await client.query(`
            INSERT INTO transport_record_audit_log (record_id, action, performed_by, details)
            VALUES ($1, 'submitted', $2, $3)
        `, [id, userId, JSON.stringify({ submission_date: submissionDate })]);

        await client.query('COMMIT');
        res.json(result.rows[0]);
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Error submitting record:', error);
        res.status(500).json({ error: 'Failed to submit record' });
    } finally {
        client.release();
    }
};

// ============================================
// 統計・レポート
// ============================================

/**
 * 実運送体制サマリー
 */
export const getActualTransportSummary = async (req: Request, res: Response) => {
    try {
        const { companyId, startDate, endDate } = req.query;

        const params: any[] = [companyId];
        let dateFilter = '';

        if (startDate && endDate) {
            dateFilter = ' AND transport_date BETWEEN $2 AND $3';
            params.push(startDate, endDate);
        }

        // ステータス別集計
        const statusResult = await pool.query(`
            SELECT
                COUNT(*) as total_records,
                COUNT(*) FILTER (WHERE status = 'draft') as draft_count,
                COUNT(*) FILTER (WHERE status = 'confirmed') as confirmed_count,
                COUNT(*) FILTER (WHERE status = 'submitted') as submitted_count
            FROM actual_transport_records
            WHERE company_id = $1 ${dateFilter}
        `, params);

        // 下請階層別集計
        const tierResult = await pool.query(`
            SELECT
                actual_carrier_tier,
                COUNT(*) as count,
                COALESCE(SUM(shipper_fare), 0) as total_shipper_fare,
                COALESCE(SUM(actual_carrier_fare), 0) as total_carrier_fare
            FROM actual_transport_records
            WHERE company_id = $1 ${dateFilter}
            GROUP BY actual_carrier_tier
            ORDER BY actual_carrier_tier
        `, params);

        // 実運送事業者別集計
        const carrierResult = await pool.query(`
            SELECT
                actual_carrier_name,
                COUNT(*) as transport_count,
                COALESCE(SUM(actual_carrier_fare), 0) as total_payment
            FROM actual_transport_records
            WHERE company_id = $1 ${dateFilter}
            GROUP BY actual_carrier_name
            ORDER BY transport_count DESC
            LIMIT 10
        `, params);

        res.json({
            summary: statusResult.rows[0],
            byTier: tierResult.rows,
            topCarriers: carrierResult.rows
        });
    } catch (error) {
        console.error('Error fetching actual transport summary:', error);
        res.status(500).json({ error: 'Failed to fetch summary' });
    }
};

/**
 * 受注から実運送体制管理簿を自動生成
 */
export const generateFromOrder = async (req: Request, res: Response) => {
    try {
        const { orderId, companyId, userId } = req.body;

        // 受注情報を取得
        const orderResult = await pool.query(`
            SELECT
                o.*,
                s.name as shipper_name,
                s.address as shipper_address,
                da.vehicle_id,
                da.driver_id,
                v.vehicle_number,
                v.vehicle_type,
                u.name as driver_name
            FROM orders o
            LEFT JOIN shippers s ON o.shipper_id = s.id
            LEFT JOIN dispatch_assignments da ON o.id = da.order_id
            LEFT JOIN vehicles v ON da.vehicle_id = v.id
            LEFT JOIN users u ON da.driver_id = u.id
            WHERE o.id = $1
        `, [orderId]);

        if (orderResult.rows.length === 0) {
            return res.status(404).json({ error: 'Order not found' });
        }

        const order = orderResult.rows[0];

        // 管理簿番号を生成
        const countResult = await pool.query(`
            SELECT COUNT(*) FROM actual_transport_records
            WHERE company_id = $1 AND transport_date = $2
        `, [companyId, order.pickup_datetime?.toISOString().split('T')[0] || new Date().toISOString().split('T')[0]]);

        const recordNumber = `ATR-${order.pickup_datetime?.toISOString().split('T')[0].replace(/-/g, '') || new Date().toISOString().split('T')[0].replace(/-/g, '')}-${String(parseInt(countResult.rows[0].count) + 1).padStart(4, '0')}`;

        // 自社が実運送の場合のデフォルトデータ
        const companyResult = await pool.query(
            'SELECT name, address FROM companies WHERE id = $1',
            [companyId]
        );
        const company = companyResult.rows[0];

        res.json({
            companyId,
            orderId: order.id,
            recordNumber,
            transportDate: order.pickup_datetime?.toISOString().split('T')[0] || new Date().toISOString().split('T')[0],
            shipperName: order.shipper_name,
            shipperAddress: order.shipper_address,
            transportChain: [
                { tier: 1, company: company?.name || '', permit: '', role: '元請' }
            ],
            actualCarrierName: company?.name || '',
            actualCarrierAddress: company?.address || '',
            actualCarrierTier: 1,
            cargoDescription: order.cargo_type,
            pickupLocation: order.pickup_location,
            deliveryLocation: order.delivery_location,
            pickupDatetime: order.pickup_datetime,
            deliveryDatetime: order.delivery_datetime,
            vehicleNumber: order.vehicle_number,
            vehicleType: order.vehicle_type,
            driverName: order.driver_name
        });
    } catch (error) {
        console.error('Error generating from order:', error);
        res.status(500).json({ error: 'Failed to generate record from order' });
    }
};
