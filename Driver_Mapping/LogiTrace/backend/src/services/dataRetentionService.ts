import { pool } from '../utils/db';

// プランごとの保存期間（月単位、0=無制限）
const RETENTION_PERIODS: Record<string, number> = {
    'starter': 3,      // 3ヶ月
    'standard': 12,    // 1年
    'pro': 0,          // 無制限
    'enterprise': 0    // 無制限
};

interface RetentionResult {
    company_id: number;
    company_name: string;
    plan_id: string;
    retention_months: number;
    deleted_records: {
        work_records: number;
        tenko_records: number;
        inspection_records: number;
        gps_tracks: number;
    };
}

// 会社ごとのデータ保存期間を取得
export const getRetentionPeriod = (planId: string): number => {
    return RETENTION_PERIODS[planId] || 0;
};

// 単一会社のデータクリーンアップ
export const cleanupCompanyData = async (companyId: number, planId: string): Promise<RetentionResult['deleted_records']> => {
    const retentionMonths = getRetentionPeriod(planId);

    // 無制限プランの場合は削除しない
    if (retentionMonths === 0) {
        return {
            work_records: 0,
            tenko_records: 0,
            inspection_records: 0,
            gps_tracks: 0
        };
    }

    const cutoffDate = new Date();
    cutoffDate.setMonth(cutoffDate.getMonth() - retentionMonths);
    const cutoffDateStr = cutoffDate.toISOString().split('T')[0];

    const result = {
        work_records: 0,
        tenko_records: 0,
        inspection_records: 0,
        gps_tracks: 0
    };

    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        // 1. GPSトラックを削除（work_recordsに依存）
        const gpsResult = await client.query(
            `DELETE FROM gps_tracks
             WHERE work_record_id IN (
                 SELECT id FROM work_records
                 WHERE driver_id IN (SELECT id FROM users WHERE company_id = $1)
                 AND work_date < $2
             )`,
            [companyId, cutoffDateStr]
        );
        result.gps_tracks = gpsResult.rowCount || 0;

        // 2. 点呼記録を削除
        const tenkoResult = await client.query(
            `DELETE FROM tenko_records
             WHERE company_id = $1 AND tenko_date < $2`,
            [companyId, cutoffDateStr]
        );
        result.tenko_records = tenkoResult.rowCount || 0;

        // 3. 点検記録を削除
        const inspectionResult = await client.query(
            `DELETE FROM vehicle_inspection_records
             WHERE company_id = $1 AND inspection_date < $2`,
            [companyId, cutoffDateStr]
        );
        result.inspection_records = inspectionResult.rowCount || 0;

        // 4. 業務記録を削除
        const workResult = await client.query(
            `DELETE FROM work_records
             WHERE driver_id IN (SELECT id FROM users WHERE company_id = $1)
             AND work_date < $2`,
            [companyId, cutoffDateStr]
        );
        result.work_records = workResult.rowCount || 0;

        await client.query('COMMIT');
    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }

    return result;
};

// 全会社のデータクリーンアップを実行
export const runDataRetentionCleanup = async (): Promise<RetentionResult[]> => {
    const results: RetentionResult[] = [];

    // アクティブなサブスクリプションを持つ会社を取得
    const companiesResult = await pool.query(
        `SELECT c.id, c.name, s.plan_id
         FROM companies c
         JOIN subscriptions s ON c.id = s.company_id
         WHERE s.status IN ('active', 'trialing')`
    );

    for (const company of companiesResult.rows) {
        const planId = company.plan_id;
        const retentionMonths = getRetentionPeriod(planId);

        // 無制限プランはスキップ
        if (retentionMonths === 0) {
            continue;
        }

        try {
            const deleted = await cleanupCompanyData(company.id, planId);

            results.push({
                company_id: company.id,
                company_name: company.name,
                plan_id: planId,
                retention_months: retentionMonths,
                deleted_records: deleted
            });
        } catch (error) {
            console.error(`Error cleaning up data for company ${company.id}:`, error);
        }
    }

    return results;
};

// 会社のデータ保存状況を取得
export const getDataRetentionStatus = async (companyId: number) => {
    // サブスクリプション情報を取得
    const subResult = await pool.query(
        `SELECT s.plan_id, c.name as company_name
         FROM subscriptions s
         JOIN companies c ON s.company_id = c.id
         WHERE s.company_id = $1 AND s.status IN ('active', 'trialing')
         LIMIT 1`,
        [companyId]
    );

    if (subResult.rows.length === 0) {
        return null;
    }

    const { plan_id, company_name } = subResult.rows[0];
    const retentionMonths = getRetentionPeriod(plan_id);

    // 各種レコードの最古・最新日付を取得
    const statsResult = await pool.query(
        `SELECT
            (SELECT MIN(work_date) FROM work_records WHERE driver_id IN (SELECT id FROM users WHERE company_id = $1)) as oldest_work_date,
            (SELECT MAX(work_date) FROM work_records WHERE driver_id IN (SELECT id FROM users WHERE company_id = $1)) as newest_work_date,
            (SELECT COUNT(*) FROM work_records WHERE driver_id IN (SELECT id FROM users WHERE company_id = $1)) as work_count,
            (SELECT COUNT(*) FROM tenko_records WHERE company_id = $1) as tenko_count,
            (SELECT COUNT(*) FROM vehicle_inspection_records WHERE company_id = $1) as inspection_count`,
        [companyId]
    );

    const stats = statsResult.rows[0];

    return {
        company_id: companyId,
        company_name,
        plan_id,
        retention_period: retentionMonths === 0 ? '無制限' : `${retentionMonths}ヶ月`,
        data_stats: {
            oldest_record_date: stats.oldest_work_date,
            newest_record_date: stats.newest_work_date,
            work_records_count: parseInt(stats.work_count) || 0,
            tenko_records_count: parseInt(stats.tenko_count) || 0,
            inspection_records_count: parseInt(stats.inspection_count) || 0
        }
    };
};
