import { pool } from '../utils/db';

export interface ExpirationAlert {
    type: 'license' | 'health_checkup' | 'aptitude_test';
    driver_id: number;
    driver_name: string;
    expiry_date: Date;
    days_remaining: number;
    urgency: 'warning' | 'critical' | 'expired';
}

export interface ComplianceSummary {
    totalDrivers: number;
    activeDrivers: number;
    expiringLicenses: number;
    expiredLicenses: number;
    healthCheckupsDue: number;
    healthCheckupsOverdue: number;
    aptitudeTestsRequired: number;
    aptitudeTestsOverdue: number;
    driversWithIssues: number;
}

// すべての期限切れアラートを取得
export const getAllExpirationAlerts = async (companyId: number): Promise<ExpirationAlert[]> => {
    const alerts: ExpirationAlert[] = [];

    // 免許有効期限アラート
    const licenseAlerts = await pool.query(
        `SELECT dr.driver_id, dr.full_name as driver_name,
                dr.license_expiry_date as expiry_date,
                (dr.license_expiry_date - CURRENT_DATE) as days_remaining
         FROM driver_registries dr
         WHERE dr.company_id = $1
           AND dr.status = 'active'
           AND dr.license_expiry_date <= CURRENT_DATE + INTERVAL '30 days'
         ORDER BY dr.license_expiry_date ASC`,
        [companyId]
    );

    for (const row of licenseAlerts.rows) {
        alerts.push({
            type: 'license',
            driver_id: row.driver_id,
            driver_name: row.driver_name,
            expiry_date: row.expiry_date,
            days_remaining: row.days_remaining,
            urgency: getUrgency(row.days_remaining)
        });
    }

    // 健康診断期限アラート
    const healthAlerts = await pool.query(
        `SELECT dr.driver_id, dr.full_name as driver_name,
                hc.next_checkup_date as expiry_date,
                (hc.next_checkup_date - CURRENT_DATE) as days_remaining
         FROM driver_registries dr
         LEFT JOIN LATERAL (
             SELECT next_checkup_date FROM health_checkup_records
             WHERE driver_id = dr.driver_id
             ORDER BY checkup_date DESC
             LIMIT 1
         ) hc ON true
         WHERE dr.company_id = $1
           AND dr.status = 'active'
           AND hc.next_checkup_date IS NOT NULL
           AND hc.next_checkup_date <= CURRENT_DATE + INTERVAL '30 days'
         ORDER BY hc.next_checkup_date ASC`,
        [companyId]
    );

    for (const row of healthAlerts.rows) {
        alerts.push({
            type: 'health_checkup',
            driver_id: row.driver_id,
            driver_name: row.driver_name,
            expiry_date: row.expiry_date,
            days_remaining: row.days_remaining,
            urgency: getUrgency(row.days_remaining)
        });
    }

    // 適性診断期限アラート
    const aptitudeAlerts = await pool.query(
        `SELECT dr.driver_id, dr.full_name as driver_name,
                at.next_test_date as expiry_date,
                (at.next_test_date - CURRENT_DATE) as days_remaining
         FROM driver_registries dr
         LEFT JOIN LATERAL (
             SELECT next_test_date FROM aptitude_test_records
             WHERE driver_id = dr.driver_id
             ORDER BY test_date DESC
             LIMIT 1
         ) at ON true
         WHERE dr.company_id = $1
           AND dr.status = 'active'
           AND at.next_test_date IS NOT NULL
           AND at.next_test_date <= CURRENT_DATE + INTERVAL '30 days'
         ORDER BY at.next_test_date ASC`,
        [companyId]
    );

    for (const row of aptitudeAlerts.rows) {
        alerts.push({
            type: 'aptitude_test',
            driver_id: row.driver_id,
            driver_name: row.driver_name,
            expiry_date: row.expiry_date,
            days_remaining: row.days_remaining,
            urgency: getUrgency(row.days_remaining)
        });
    }

    // 緊急度でソート（期限切れ → critical → warning）
    return alerts.sort((a, b) => a.days_remaining - b.days_remaining);
};

// コンプライアンスサマリーを取得
export const getComplianceSummary = async (companyId: number): Promise<ComplianceSummary> => {
    // 総ドライバー数とアクティブドライバー数
    const driverCountResult = await pool.query(
        `SELECT
            COUNT(*) as total,
            SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as active
         FROM driver_registries
         WHERE company_id = $1`,
        [companyId]
    );

    const totalDrivers = parseInt(driverCountResult.rows[0].total) || 0;
    const activeDrivers = parseInt(driverCountResult.rows[0].active) || 0;

    // 免許有効期限
    const licenseResult = await pool.query(
        `SELECT
            SUM(CASE WHEN license_expiry_date > CURRENT_DATE AND license_expiry_date <= CURRENT_DATE + INTERVAL '30 days' THEN 1 ELSE 0 END) as expiring,
            SUM(CASE WHEN license_expiry_date <= CURRENT_DATE THEN 1 ELSE 0 END) as expired
         FROM driver_registries
         WHERE company_id = $1 AND status = 'active'`,
        [companyId]
    );

    // 健康診断
    const healthResult = await pool.query(
        `SELECT
            SUM(CASE WHEN hc.next_checkup_date > CURRENT_DATE AND hc.next_checkup_date <= CURRENT_DATE + INTERVAL '30 days' THEN 1 ELSE 0 END) as due,
            SUM(CASE WHEN hc.next_checkup_date <= CURRENT_DATE THEN 1 ELSE 0 END) as overdue
         FROM driver_registries dr
         LEFT JOIN LATERAL (
             SELECT next_checkup_date FROM health_checkup_records
             WHERE driver_id = dr.driver_id
             ORDER BY checkup_date DESC
             LIMIT 1
         ) hc ON true
         WHERE dr.company_id = $1 AND dr.status = 'active'`,
        [companyId]
    );

    // 適性診断
    const aptitudeResult = await pool.query(
        `SELECT
            SUM(CASE WHEN at.next_test_date > CURRENT_DATE AND at.next_test_date <= CURRENT_DATE + INTERVAL '30 days' THEN 1 ELSE 0 END) as required,
            SUM(CASE WHEN at.next_test_date <= CURRENT_DATE THEN 1 ELSE 0 END) as overdue
         FROM driver_registries dr
         LEFT JOIN LATERAL (
             SELECT next_test_date FROM aptitude_test_records
             WHERE driver_id = dr.driver_id
             ORDER BY test_date DESC
             LIMIT 1
         ) at ON true
         WHERE dr.company_id = $1 AND dr.status = 'active'`,
        [companyId]
    );

    // 問題のあるドライバー数
    const issueResult = await pool.query(
        `SELECT COUNT(DISTINCT dr.driver_id) as count
         FROM driver_registries dr
         LEFT JOIN LATERAL (
             SELECT next_checkup_date FROM health_checkup_records
             WHERE driver_id = dr.driver_id
             ORDER BY checkup_date DESC
             LIMIT 1
         ) hc ON true
         LEFT JOIN LATERAL (
             SELECT next_test_date FROM aptitude_test_records
             WHERE driver_id = dr.driver_id
             ORDER BY test_date DESC
             LIMIT 1
         ) at ON true
         WHERE dr.company_id = $1
           AND dr.status = 'active'
           AND (
               dr.license_expiry_date <= CURRENT_DATE + INTERVAL '30 days'
               OR hc.next_checkup_date <= CURRENT_DATE + INTERVAL '30 days'
               OR at.next_test_date <= CURRENT_DATE + INTERVAL '30 days'
           )`,
        [companyId]
    );

    return {
        totalDrivers,
        activeDrivers,
        expiringLicenses: parseInt(licenseResult.rows[0].expiring) || 0,
        expiredLicenses: parseInt(licenseResult.rows[0].expired) || 0,
        healthCheckupsDue: parseInt(healthResult.rows[0].due) || 0,
        healthCheckupsOverdue: parseInt(healthResult.rows[0].overdue) || 0,
        aptitudeTestsRequired: parseInt(aptitudeResult.rows[0].required) || 0,
        aptitudeTestsOverdue: parseInt(aptitudeResult.rows[0].overdue) || 0,
        driversWithIssues: parseInt(issueResult.rows[0].count) || 0
    };
};

// ドライバーの乗務可否チェック（点呼時使用）
export const canDriverOperate = async (driverId: number): Promise<{
    canOperate: boolean;
    issues: string[];
}> => {
    const issues: string[] = [];

    // 運転者台帳チェック
    const registryResult = await pool.query(
        `SELECT status, license_expiry_date,
                (license_expiry_date - CURRENT_DATE) as license_days
         FROM driver_registries
         WHERE driver_id = $1`,
        [driverId]
    );

    if (registryResult.rows.length === 0) {
        return { canOperate: false, issues: ['運転者台帳が登録されていません'] };
    }

    const registry = registryResult.rows[0];

    if (registry.status !== 'active') {
        issues.push('ドライバーステータスがアクティブではありません');
    }

    if (registry.license_days < 0) {
        issues.push('免許が期限切れです');
    } else if (registry.license_days <= 7) {
        issues.push(`免許有効期限が${registry.license_days}日以内です（警告）`);
    }

    // 健康診断チェック
    const healthResult = await pool.query(
        `SELECT overall_result, next_checkup_date,
                (next_checkup_date - CURRENT_DATE) as days_until_next
         FROM health_checkup_records
         WHERE driver_id = $1
         ORDER BY checkup_date DESC
         LIMIT 1`,
        [driverId]
    );

    if (healthResult.rows.length > 0) {
        const health = healthResult.rows[0];
        if (health.overall_result === 'work_restriction') {
            issues.push('健康診断結果により就業制限があります');
        }
        if (health.days_until_next < 0) {
            issues.push('健康診断の受診期限を過ぎています');
        }
    }

    return {
        canOperate: issues.filter(i => !i.includes('警告')).length === 0,
        issues
    };
};

// 緊急度を判定
function getUrgency(daysRemaining: number): 'warning' | 'critical' | 'expired' {
    if (daysRemaining < 0) return 'expired';
    if (daysRemaining <= 7) return 'critical';
    return 'warning';
}

// APIエンドポイント用のコントローラー関数
export const getAlertsController = async (req: any, res: any) => {
    try {
        const { companyId } = req.query;
        const alerts = await getAllExpirationAlerts(parseInt(companyId as string));
        res.json(alerts);
    } catch (error) {
        console.error('Error fetching alerts:', error);
        res.status(500).json({ error: 'Failed to fetch alerts' });
    }
};

export const getSummaryController = async (req: any, res: any) => {
    try {
        const { companyId } = req.query;
        const summary = await getComplianceSummary(parseInt(companyId as string));
        res.json(summary);
    } catch (error) {
        console.error('Error fetching compliance summary:', error);
        res.status(500).json({ error: 'Failed to fetch compliance summary' });
    }
};

export const checkOperateController = async (req: any, res: any) => {
    try {
        const { driverId } = req.params;
        const result = await canDriverOperate(parseInt(driverId));
        res.json(result);
    } catch (error) {
        console.error('Error checking driver operate status:', error);
        res.status(500).json({ error: 'Failed to check driver operate status' });
    }
};
