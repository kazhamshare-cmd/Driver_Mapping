/**
 * Payment Controller - 入金・支払管理
 */

import { Request, Response } from 'express';
import { pool } from '../index';

interface AuthRequest extends Request {
    user?: { id: number; companyId: number; role: string };
}

/**
 * 入金一覧取得
 */
export const getPayments = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.query.companyId;
        const { invoiceId, shipperId, dateFrom, dateTo, isMatched, page = 1, limit = 20 } = req.query;

        let query = `
            SELECT
                p.*,
                i.invoice_number,
                i.total_amount AS invoice_total,
                s.name AS shipper_name,
                u.name AS created_by_name
            FROM payments p
            LEFT JOIN invoices i ON p.invoice_id = i.id
            LEFT JOIN shippers s ON p.shipper_id = s.id
            LEFT JOIN users u ON p.created_by = u.id
            WHERE p.company_id = $1
        `;
        const params: any[] = [companyId];

        if (invoiceId) {
            params.push(invoiceId);
            query += ` AND p.invoice_id = $${params.length}`;
        }

        if (shipperId) {
            params.push(shipperId);
            query += ` AND p.shipper_id = $${params.length}`;
        }

        if (dateFrom) {
            params.push(dateFrom);
            query += ` AND p.payment_date >= $${params.length}`;
        }

        if (dateTo) {
            params.push(dateTo);
            query += ` AND p.payment_date <= $${params.length}`;
        }

        if (isMatched !== undefined) {
            params.push(isMatched === 'true');
            query += ` AND p.is_matched = $${params.length}`;
        }

        query += ` ORDER BY p.payment_date DESC, p.created_at DESC`;

        // ページネーション
        const offset = (Number(page) - 1) * Number(limit);
        params.push(limit, offset);
        query += ` LIMIT $${params.length - 1} OFFSET $${params.length}`;

        const result = await pool.query(query, params);

        // 総件数取得
        let countQuery = `SELECT COUNT(*) FROM payments WHERE company_id = $1`;
        const countParams: any[] = [companyId];

        if (invoiceId) {
            countParams.push(invoiceId);
            countQuery += ` AND invoice_id = $${countParams.length}`;
        }
        if (shipperId) {
            countParams.push(shipperId);
            countQuery += ` AND shipper_id = $${countParams.length}`;
        }

        const countResult = await pool.query(countQuery, countParams);
        const total = parseInt(countResult.rows[0].count);

        res.json({
            payments: result.rows,
            pagination: {
                page: Number(page),
                limit: Number(limit),
                total,
                totalPages: Math.ceil(total / Number(limit))
            }
        });
    } catch (error) {
        console.error('Failed to get payments:', error);
        res.status(500).json({ error: '入金一覧の取得に失敗しました' });
    }
};

/**
 * 入金登録
 */
export const createPayment = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.body.companyId;
        const userId = req.user?.id;

        const {
            invoiceId,
            shipperId,
            paymentDate,
            amount,
            paymentMethod,
            bankName,
            branchName,
            transferName,
            notes
        } = req.body;

        // 請求書がある場合、荷主IDを取得
        let finalShipperId = shipperId;
        if (invoiceId && !shipperId) {
            const invoiceResult = await pool.query(
                'SELECT shipper_id FROM invoices WHERE id = $1',
                [invoiceId]
            );
            if (invoiceResult.rows.length > 0) {
                finalShipperId = invoiceResult.rows[0].shipper_id;
            }
        }

        const result = await pool.query(`
            INSERT INTO payments (
                company_id, invoice_id, shipper_id,
                payment_date, amount, payment_method,
                bank_name, branch_name, transfer_name,
                notes, is_matched, created_by
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
            RETURNING *
        `, [
            companyId, invoiceId, finalShipperId,
            paymentDate, amount, paymentMethod,
            bankName, branchName, transferName,
            notes, invoiceId ? true : false, userId
        ]);

        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Failed to create payment:', error);
        res.status(500).json({ error: '入金登録に失敗しました' });
    }
};

/**
 * 入金と請求書の消込
 */
export const matchPaymentToInvoice = async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const { invoiceId } = req.body;
        const companyId = req.user?.companyId || req.body.companyId;
        const userId = req.user?.id;

        // 入金と請求書を関連付け
        const result = await pool.query(`
            UPDATE payments SET
                invoice_id = $1,
                is_matched = TRUE,
                matched_at = NOW(),
                matched_by = $2
            WHERE id = $3 AND company_id = $4
            RETURNING *
        `, [invoiceId, userId, id, companyId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: '入金が見つかりません' });
        }

        // 請求書のステータスも自動更新（トリガーで実行）

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Failed to match payment:', error);
        res.status(500).json({ error: '消込に失敗しました' });
    }
};

/**
 * 消込解除
 */
export const unmatchPayment = async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const companyId = req.user?.companyId || req.query.companyId;

        const result = await pool.query(`
            UPDATE payments SET
                invoice_id = NULL,
                is_matched = FALSE,
                matched_at = NULL,
                matched_by = NULL
            WHERE id = $1 AND company_id = $2
            RETURNING *
        `, [id, companyId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: '入金が見つかりません' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Failed to unmatch payment:', error);
        res.status(500).json({ error: '消込解除に失敗しました' });
    }
};

/**
 * 入金削除
 */
export const deletePayment = async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const companyId = req.user?.companyId || req.query.companyId;

        const result = await pool.query(`
            DELETE FROM payments
            WHERE id = $1 AND company_id = $2
            RETURNING id
        `, [id, companyId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: '入金が見つかりません' });
        }

        res.json({ message: '入金を削除しました' });
    } catch (error) {
        console.error('Failed to delete payment:', error);
        res.status(500).json({ error: '入金の削除に失敗しました' });
    }
};

/**
 * 未消込入金一覧取得
 */
export const getUnmatchedPayments = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.query.companyId;

        const result = await pool.query(`
            SELECT
                p.*,
                s.name AS shipper_name
            FROM payments p
            LEFT JOIN shippers s ON p.shipper_id = s.id
            WHERE p.company_id = $1 AND p.is_matched = FALSE
            ORDER BY p.payment_date DESC
        `, [companyId]);

        res.json(result.rows);
    } catch (error) {
        console.error('Failed to get unmatched payments:', error);
        res.status(500).json({ error: '未消込入金の取得に失敗しました' });
    }
};

/**
 * 入金サマリー（月別）
 */
export const getPaymentSummary = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.query.companyId;
        const { year } = req.query;

        let query = `
            SELECT
                DATE_TRUNC('month', payment_date) AS month,
                COUNT(*) AS payment_count,
                SUM(amount) AS total_amount,
                SUM(CASE WHEN is_matched THEN amount ELSE 0 END) AS matched_amount,
                SUM(CASE WHEN NOT is_matched THEN amount ELSE 0 END) AS unmatched_amount
            FROM payments
            WHERE company_id = $1
        `;
        const params: any[] = [companyId];

        if (year) {
            params.push(year);
            query += ` AND EXTRACT(YEAR FROM payment_date) = $${params.length}`;
        }

        query += ` GROUP BY DATE_TRUNC('month', payment_date) ORDER BY month DESC`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Failed to get payment summary:', error);
        res.status(500).json({ error: '入金サマリーの取得に失敗しました' });
    }
};

/**
 * 入金消込候補（AIマッチング）
 */
export const getMatchingSuggestions = async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const companyId = req.user?.companyId || req.query.companyId;

        // 入金情報取得
        const paymentResult = await pool.query(`
            SELECT * FROM payments WHERE id = $1 AND company_id = $2
        `, [id, companyId]);

        if (paymentResult.rows.length === 0) {
            return res.status(404).json({ error: '入金が見つかりません' });
        }

        const payment = paymentResult.rows[0];

        // 消込候補の請求書を検索
        // 条件: 未払い、金額一致または近い、荷主一致、振込人名義で検索
        const suggestions = await pool.query(`
            SELECT
                i.*,
                s.name AS shipper_name,
                ABS(i.total_amount - i.paid_amount - $1) AS amount_diff,
                CASE
                    WHEN i.total_amount - i.paid_amount = $1 THEN 100
                    WHEN i.shipper_id = $2 THEN 80
                    WHEN ABS(i.total_amount - i.paid_amount - $1) <= 1000 THEN 60
                    ELSE 40
                END AS match_score
            FROM invoices i
            LEFT JOIN shippers s ON i.shipper_id = s.id
            WHERE i.company_id = $3
              AND i.status IN ('issued', 'sent', 'partial', 'overdue')
              AND i.total_amount - i.paid_amount > 0
            ORDER BY match_score DESC, amount_diff ASC
            LIMIT 10
        `, [payment.amount, payment.shipper_id, companyId]);

        res.json(suggestions.rows);
    } catch (error) {
        console.error('Failed to get matching suggestions:', error);
        res.status(500).json({ error: '消込候補の取得に失敗しました' });
    }
};
