import { Request, Response } from 'express';
import {
    getDataRetentionStatus,
    runDataRetentionCleanup,
    cleanupCompanyData,
    getRetentionPeriod
} from '../services/dataRetentionService';
import { pool } from '../utils/db';

// 会社のデータ保存状況を取得
export const getStatus = async (req: Request, res: Response) => {
    try {
        const companyId = (req as any).user?.companyId;

        if (!companyId) {
            return res.status(400).json({ error: 'Company ID is required' });
        }

        const status = await getDataRetentionStatus(companyId);

        if (!status) {
            return res.status(404).json({ error: 'No active subscription found' });
        }

        res.json(status);
    } catch (error) {
        console.error('Error getting data retention status:', error);
        res.status(500).json({ error: 'Failed to get data retention status' });
    }
};

// 手動でデータクリーンアップを実行（管理者用）
export const runCleanup = async (req: Request, res: Response) => {
    try {
        const userType = (req as any).user?.userType;

        // 管理者のみ実行可能
        if (userType !== 'admin') {
            return res.status(403).json({ error: 'Admin access required' });
        }

        const results = await runDataRetentionCleanup();

        res.json({
            success: true,
            message: 'Data retention cleanup completed',
            results
        });
    } catch (error) {
        console.error('Error running data retention cleanup:', error);
        res.status(500).json({ error: 'Failed to run data retention cleanup' });
    }
};

// 特定会社のデータクリーンアップ（管理者用）
export const cleanupCompany = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.params;
        const userType = (req as any).user?.userType;

        // 管理者のみ実行可能
        if (userType !== 'admin') {
            return res.status(403).json({ error: 'Admin access required' });
        }

        // 会社のプランを取得
        const subResult = await pool.query(
            `SELECT plan_id FROM subscriptions
             WHERE company_id = $1 AND status IN ('active', 'trialing')
             LIMIT 1`,
            [companyId]
        );

        if (subResult.rows.length === 0) {
            return res.status(404).json({ error: 'No active subscription found' });
        }

        const planId = subResult.rows[0].plan_id;
        const deleted = await cleanupCompanyData(parseInt(companyId), planId);

        res.json({
            success: true,
            company_id: parseInt(companyId),
            plan_id: planId,
            retention_months: getRetentionPeriod(planId),
            deleted_records: deleted
        });
    } catch (error) {
        console.error('Error cleaning up company data:', error);
        res.status(500).json({ error: 'Failed to cleanup company data' });
    }
};

// プランごとの保存期間情報を取得
export const getRetentionInfo = async (req: Request, res: Response) => {
    try {
        res.json({
            plans: {
                starter: { retention_months: 3, retention_display: '3ヶ月' },
                standard: { retention_months: 12, retention_display: '1年' },
                pro: { retention_months: 0, retention_display: '無制限' },
                enterprise: { retention_months: 0, retention_display: '無制限' }
            }
        });
    } catch (error) {
        console.error('Error getting retention info:', error);
        res.status(500).json({ error: 'Failed to get retention info' });
    }
};
