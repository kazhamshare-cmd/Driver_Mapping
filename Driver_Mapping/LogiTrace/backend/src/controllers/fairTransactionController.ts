/**
 * Fair Transaction Controller
 * 取適法対応（トラック運送業における下請取引適正化）
 */

import { Request, Response } from 'express';
import { pool } from '../index';

// ============================================
// 取引条件書管理
// ============================================

/**
 * 取引条件書一覧取得
 */
export const getTransactionTerms = async (req: Request, res: Response) => {
    try {
        const { companyId, shipperId, status } = req.query;

        let query = `
            SELECT
                tt.*,
                s.name as shipper_name,
                s.invoice_registration_number
            FROM transaction_terms tt
            LEFT JOIN shippers s ON tt.shipper_id = s.id
            WHERE tt.company_id = $1
        `;
        const params: any[] = [companyId];
        let paramIndex = 2;

        if (shipperId) {
            query += ` AND tt.shipper_id = $${paramIndex++}`;
            params.push(shipperId);
        }

        if (status) {
            query += ` AND tt.status = $${paramIndex++}`;
            params.push(status);
        }

        query += ` ORDER BY tt.effective_date DESC`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching transaction terms:', error);
        res.status(500).json({ error: 'Failed to fetch transaction terms' });
    }
};

/**
 * 取引条件書詳細取得
 */
export const getTransactionTermsById = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        const result = await pool.query(`
            SELECT
                tt.*,
                s.name as shipper_name,
                s.address as shipper_address,
                s.invoice_registration_number
            FROM transaction_terms tt
            LEFT JOIN shippers s ON tt.shipper_id = s.id
            WHERE tt.id = $1
        `, [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Transaction terms not found' });
        }

        // 変更履歴も取得
        const historyResult = await pool.query(`
            SELECT tth.*, u.name as changed_by_name
            FROM transaction_terms_history tth
            LEFT JOIN users u ON tth.changed_by = u.id
            WHERE tth.terms_id = $1
            ORDER BY tth.changed_at DESC
        `, [id]);

        res.json({
            ...result.rows[0],
            history: historyResult.rows
        });
    } catch (error) {
        console.error('Error fetching transaction terms:', error);
        res.status(500).json({ error: 'Failed to fetch transaction terms' });
    }
};

/**
 * 取引条件書作成
 */
export const createTransactionTerms = async (req: Request, res: Response) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        const {
            companyId, shipperId, termsNumber, effectiveDate, expiryDate,
            cargoType, transportMode, routeDescription,
            baseFareType, baseFareAmount, fuelSurchargeType, fuelSurchargeRate,
            loadingFee, unloadingFee, waitingFeePerHour, detentionFeePerHour,
            paymentTerms, paymentMethod, documentIssuedDate, notes, userId
        } = req.body;

        const result = await client.query(`
            INSERT INTO transaction_terms (
                company_id, shipper_id, terms_number, effective_date, expiry_date,
                cargo_type, transport_mode, route_description,
                base_fare_type, base_fare_amount, fuel_surcharge_type, fuel_surcharge_rate,
                loading_fee, unloading_fee, waiting_fee_per_hour, detention_fee_per_hour,
                payment_terms, payment_method, document_issued_date, notes
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20)
            RETURNING *
        `, [
            companyId, shipperId, termsNumber, effectiveDate, expiryDate,
            cargoType, transportMode, routeDescription,
            baseFareType, baseFareAmount, fuelSurchargeType, fuelSurchargeRate,
            loadingFee || 0, unloadingFee || 0, waitingFeePerHour || 0, detentionFeePerHour || 0,
            paymentTerms, paymentMethod, documentIssuedDate, notes
        ]);

        // 履歴に記録
        await client.query(`
            INSERT INTO transaction_terms_history (terms_id, changed_by, change_type, new_values)
            VALUES ($1, $2, 'created', $3)
        `, [result.rows[0].id, userId, JSON.stringify(result.rows[0])]);

        await client.query('COMMIT');
        res.status(201).json(result.rows[0]);
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Error creating transaction terms:', error);
        res.status(500).json({ error: 'Failed to create transaction terms' });
    } finally {
        client.release();
    }
};

/**
 * 取引条件書更新
 */
export const updateTransactionTerms = async (req: Request, res: Response) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        const { id } = req.params;
        const { userId, changeReason, ...updateData } = req.body;

        // 現在の値を取得
        const currentResult = await client.query(
            'SELECT * FROM transaction_terms WHERE id = $1',
            [id]
        );

        if (currentResult.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ error: 'Transaction terms not found' });
        }

        const previousValues = currentResult.rows[0];

        // 更新
        const fields = Object.keys(updateData);
        const setClause = fields.map((f, i) => `${f} = $${i + 2}`).join(', ');
        const values = fields.map(f => updateData[f]);

        const result = await client.query(`
            UPDATE transaction_terms
            SET ${setClause}, updated_at = NOW()
            WHERE id = $1
            RETURNING *
        `, [id, ...values]);

        // 履歴に記録
        await client.query(`
            INSERT INTO transaction_terms_history (terms_id, changed_by, change_type, change_reason, previous_values, new_values)
            VALUES ($1, $2, 'modified', $3, $4, $5)
        `, [id, userId, changeReason, JSON.stringify(previousValues), JSON.stringify(result.rows[0])]);

        await client.query('COMMIT');
        res.json(result.rows[0]);
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Error updating transaction terms:', error);
        res.status(500).json({ error: 'Failed to update transaction terms' });
    } finally {
        client.release();
    }
};

/**
 * 書面交付確認
 */
export const confirmDocumentReceipt = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const { userId } = req.body;

        const result = await pool.query(`
            UPDATE transaction_terms
            SET document_received_confirmed = TRUE, updated_at = NOW()
            WHERE id = $1
            RETURNING *
        `, [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Transaction terms not found' });
        }

        // 履歴に記録
        await pool.query(`
            INSERT INTO transaction_terms_history (terms_id, changed_by, change_type, new_values)
            VALUES ($1, $2, 'document_confirmed', $3)
        `, [id, userId, JSON.stringify({ document_received_confirmed: true })]);

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error confirming document receipt:', error);
        res.status(500).json({ error: 'Failed to confirm document receipt' });
    }
};

// ============================================
// 不当取引行為記録
// ============================================

/**
 * 不当取引行為一覧取得
 */
export const getUnfairPractices = async (req: Request, res: Response) => {
    try {
        const { companyId, status } = req.query;

        let query = `
            SELECT
                upr.*,
                s.name as shipper_name
            FROM unfair_practice_records upr
            LEFT JOIN shippers s ON upr.shipper_id = s.id
            WHERE upr.company_id = $1
        `;
        const params: any[] = [companyId];

        if (status) {
            query += ` AND upr.resolution_status = $2`;
            params.push(status);
        }

        query += ` ORDER BY upr.incident_date DESC`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching unfair practices:', error);
        res.status(500).json({ error: 'Failed to fetch unfair practices' });
    }
};

/**
 * 不当取引行為記録作成
 */
export const createUnfairPractice = async (req: Request, res: Response) => {
    try {
        const {
            companyId, shipperId, incidentDate, practiceType, description,
            originalAmount, actualAmount, evidenceFiles
        } = req.body;

        const differenceAmount = originalAmount && actualAmount
            ? originalAmount - actualAmount
            : null;

        const result = await pool.query(`
            INSERT INTO unfair_practice_records (
                company_id, shipper_id, incident_date, practice_type, description,
                original_amount, actual_amount, difference_amount, evidence_files
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING *
        `, [
            companyId, shipperId, incidentDate, practiceType, description,
            originalAmount, actualAmount, differenceAmount, JSON.stringify(evidenceFiles || [])
        ]);

        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error creating unfair practice record:', error);
        res.status(500).json({ error: 'Failed to create unfair practice record' });
    }
};

/**
 * 不当取引行為のステータス更新
 */
export const updateUnfairPracticeStatus = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const { resolutionStatus, resolutionNotes, reportedToAuthority, reportedDate } = req.body;

        const result = await pool.query(`
            UPDATE unfair_practice_records
            SET resolution_status = COALESCE($2, resolution_status),
                resolution_notes = COALESCE($3, resolution_notes),
                reported_to_authority = COALESCE($4, reported_to_authority),
                reported_date = COALESCE($5, reported_date),
                updated_at = NOW()
            WHERE id = $1
            RETURNING *
        `, [id, resolutionStatus, resolutionNotes, reportedToAuthority, reportedDate]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Record not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating unfair practice status:', error);
        res.status(500).json({ error: 'Failed to update unfair practice status' });
    }
};

// ============================================
// 取適法コンプライアンスダッシュボード
// ============================================

/**
 * 取適法コンプライアンスサマリー
 */
export const getFairTransactionSummary = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.query;

        // 取引条件書の状況
        const termsResult = await pool.query(`
            SELECT
                COUNT(*) FILTER (WHERE status = 'active') as active_terms,
                COUNT(*) FILTER (WHERE status = 'active' AND NOT document_received_confirmed) as pending_confirmation,
                COUNT(*) FILTER (WHERE status = 'active' AND expiry_date < NOW() + INTERVAL '30 days') as expiring_soon
            FROM transaction_terms
            WHERE company_id = $1
        `, [companyId]);

        // 不当取引の状況
        const practicesResult = await pool.query(`
            SELECT
                COUNT(*) as total_incidents,
                COUNT(*) FILTER (WHERE resolution_status = 'pending') as pending_resolution,
                COALESCE(SUM(difference_amount) FILTER (WHERE resolution_status = 'pending'), 0) as pending_amount
            FROM unfair_practice_records
            WHERE company_id = $1
        `, [companyId]);

        // 書面交付未確認の荷主
        const unconfirmedShippers = await pool.query(`
            SELECT DISTINCT s.id, s.name
            FROM shippers s
            JOIN transaction_terms tt ON s.id = tt.shipper_id
            WHERE tt.company_id = $1
              AND tt.status = 'active'
              AND NOT tt.document_received_confirmed
            LIMIT 10
        `, [companyId]);

        res.json({
            transactionTerms: termsResult.rows[0],
            unfairPractices: practicesResult.rows[0],
            unconfirmedShippers: unconfirmedShippers.rows
        });
    } catch (error) {
        console.error('Error fetching fair transaction summary:', error);
        res.status(500).json({ error: 'Failed to fetch summary' });
    }
};

/**
 * 取引条件書PDF生成用データ取得
 */
export const getTermsForPdf = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        const result = await pool.query(`
            SELECT
                tt.*,
                s.name as shipper_name,
                s.address as shipper_address,
                s.contact_person as shipper_contact,
                s.phone as shipper_phone,
                s.invoice_registration_number,
                c.name as company_name,
                c.address as company_address
            FROM transaction_terms tt
            LEFT JOIN shippers s ON tt.shipper_id = s.id
            LEFT JOIN companies c ON tt.company_id = c.id
            WHERE tt.id = $1
        `, [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Transaction terms not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching terms for PDF:', error);
        res.status(500).json({ error: 'Failed to fetch terms for PDF' });
    }
};
