import { Request, Response } from 'express';
import { pool } from '../utils/db';

// 確認履歴を取得
export const getConfirmationHistory = async (req: Request, res: Response) => {
    try {
        const { work_record_id } = req.params;

        const result = await pool.query(
            `SELECT
                mc.id,
                mc.action,
                mc.comment,
                mc.signature_data,
                mc.confirmed_at,
                u.name as manager_name,
                u.employee_number as manager_employee_number
            FROM manager_confirmations mc
            JOIN users u ON mc.manager_id = u.id
            WHERE mc.work_record_id = $1
            ORDER BY mc.confirmed_at DESC`,
            [work_record_id]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching confirmation history:', error);
        res.status(500).json({ error: '確認履歴の取得に失敗しました' });
    }
};

// 電子署名付きで承認
export const approveWithSignature = async (req: Request, res: Response) => {
    const client = await pool.connect();
    try {
        const { work_record_id } = req.params;
        const { comment, signature_data } = req.body;
        const managerId = (req as any).user?.id;

        if (!managerId) {
            return res.status(401).json({ error: '認証が必要です' });
        }

        if (!signature_data) {
            return res.status(400).json({ error: '電子署名が必要です' });
        }

        await client.query('BEGIN');

        // 運行記録を承認状態に更新
        await client.query(
            `UPDATE work_records
            SET status = 'confirmed',
                approved_by = $1,
                approved_at = CURRENT_TIMESTAMP
            WHERE id = $2`,
            [managerId, work_record_id]
        );

        // 確認履歴を記録
        await client.query(
            `INSERT INTO manager_confirmations
            (work_record_id, manager_id, action, comment, signature_data)
            VALUES ($1, $2, 'approve', $3, $4)`,
            [work_record_id, managerId, comment || '承認済み', signature_data]
        );

        await client.query('COMMIT');

        res.json({ success: true, message: '電子署名付きで承認しました' });
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Error approving with signature:', error);
        res.status(500).json({ error: '署名付き承認に失敗しました' });
    } finally {
        client.release();
    }
};

// 一括電子署名承認
export const bulkApproveWithSignature = async (req: Request, res: Response) => {
    const client = await pool.connect();
    try {
        const { record_ids, comment, signature_data } = req.body;
        const managerId = (req as any).user?.id;

        if (!managerId) {
            return res.status(401).json({ error: '認証が必要です' });
        }

        if (!signature_data) {
            return res.status(400).json({ error: '電子署名が必要です' });
        }

        if (!Array.isArray(record_ids) || record_ids.length === 0) {
            return res.status(400).json({ error: '承認する記録を選択してください' });
        }

        await client.query('BEGIN');

        let approvedCount = 0;

        for (const recordId of record_ids) {
            // 運行記録を承認状態に更新
            const updateResult = await client.query(
                `UPDATE work_records
                SET status = 'confirmed',
                    approved_by = $1,
                    approved_at = CURRENT_TIMESTAMP
                WHERE id = $2 AND status = 'pending'
                RETURNING id`,
                [managerId, recordId]
            );

            if (updateResult.rows.length > 0) {
                // 確認履歴を記録
                await client.query(
                    `INSERT INTO manager_confirmations
                    (work_record_id, manager_id, action, comment, signature_data)
                    VALUES ($1, $2, 'approve', $3, $4)`,
                    [recordId, managerId, comment || '一括承認', signature_data]
                );
                approvedCount++;
            }
        }

        await client.query('COMMIT');

        res.json({
            success: true,
            approved_count: approvedCount,
            message: `${approvedCount}件を電子署名付きで承認しました`
        });
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Error bulk approving with signature:', error);
        res.status(500).json({ error: '一括署名承認に失敗しました' });
    } finally {
        client.release();
    }
};

// 運行管理者の署名データを取得（最新の署名を再利用する場合）
export const getManagerSignature = async (req: Request, res: Response) => {
    try {
        const managerId = (req as any).user?.id;

        if (!managerId) {
            return res.status(401).json({ error: '認証が必要です' });
        }

        const result = await pool.query(
            `SELECT signature_data, confirmed_at
            FROM manager_confirmations
            WHERE manager_id = $1 AND signature_data IS NOT NULL
            ORDER BY confirmed_at DESC
            LIMIT 1`,
            [managerId]
        );

        if (result.rows.length === 0) {
            return res.json({ signature_data: null });
        }

        res.json({
            signature_data: result.rows[0].signature_data,
            last_used: result.rows[0].confirmed_at
        });
    } catch (error) {
        console.error('Error fetching manager signature:', error);
        res.status(500).json({ error: '署名データの取得に失敗しました' });
    }
};

// 差戻し（コメント必須）
export const rejectWithReason = async (req: Request, res: Response) => {
    const client = await pool.connect();
    try {
        const { work_record_id } = req.params;
        const { reason } = req.body;
        const managerId = (req as any).user?.id;

        if (!managerId) {
            return res.status(401).json({ error: '認証が必要です' });
        }

        if (!reason || reason.trim() === '') {
            return res.status(400).json({ error: '差戻し理由を入力してください' });
        }

        await client.query('BEGIN');

        // 運行記録を差戻し状態に更新
        await client.query(
            `UPDATE work_records
            SET status = 'rejected',
                rejection_reason = $1
            WHERE id = $2`,
            [reason, work_record_id]
        );

        // 確認履歴を記録
        await client.query(
            `INSERT INTO manager_confirmations
            (work_record_id, manager_id, action, comment)
            VALUES ($1, $2, 'reject', $3)`,
            [work_record_id, managerId, reason]
        );

        await client.query('COMMIT');

        res.json({ success: true, message: '差戻ししました' });
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Error rejecting:', error);
        res.status(500).json({ error: '差戻しに失敗しました' });
    } finally {
        client.release();
    }
};

// 修正依頼（差戻しとは別の軽微な修正依頼）
export const requestCorrection = async (req: Request, res: Response) => {
    const client = await pool.connect();
    try {
        const { work_record_id } = req.params;
        const { comment } = req.body;
        const managerId = (req as any).user?.id;

        if (!managerId) {
            return res.status(401).json({ error: '認証が必要です' });
        }

        if (!comment || comment.trim() === '') {
            return res.status(400).json({ error: '修正依頼内容を入力してください' });
        }

        await client.query('BEGIN');

        // 確認履歴を記録（ステータスは変えずにコメントのみ記録）
        await client.query(
            `INSERT INTO manager_confirmations
            (work_record_id, manager_id, action, comment)
            VALUES ($1, $2, 'request_correction', $3)`,
            [work_record_id, managerId, comment]
        );

        await client.query('COMMIT');

        res.json({ success: true, message: '修正依頼を送信しました' });
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Error requesting correction:', error);
        res.status(500).json({ error: '修正依頼の送信に失敗しました' });
    } finally {
        client.release();
    }
};

// 日次承認サマリー（ダッシュボード用）
export const getDailyApprovalSummary = async (req: Request, res: Response) => {
    try {
        const companyId = (req as any).user?.companyId;
        const { date } = req.query;

        const targetDate = date || new Date().toISOString().split('T')[0];

        const result = await pool.query(
            `SELECT
                COUNT(*) FILTER (WHERE status = 'pending') as pending_count,
                COUNT(*) FILTER (WHERE status = 'confirmed') as confirmed_count,
                COUNT(*) FILTER (WHERE status = 'rejected') as rejected_count,
                COUNT(*) FILTER (WHERE status = 'draft') as draft_count,
                COUNT(*) as total_count
            FROM work_records wr
            JOIN users u ON wr.driver_id = u.id
            WHERE u.company_id = $1 AND wr.work_date = $2`,
            [companyId, targetDate]
        );

        res.json({
            date: targetDate,
            ...result.rows[0]
        });
    } catch (error) {
        console.error('Error fetching daily approval summary:', error);
        res.status(500).json({ error: '承認サマリーの取得に失敗しました' });
    }
};
