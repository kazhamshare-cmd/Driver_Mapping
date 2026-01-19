/**
 * Labor Compliance Service - 改善基準告示対応
 * 拘束時間・運転時間・休息期間の監視とアラート生成
 */

import { pool } from '../utils/db';

// アラートタイプ定義
export type AlertType =
    | 'binding_time_daily'      // 1日の拘束時間
    | 'binding_time_monthly'    // 月間拘束時間
    | 'driving_time_daily'      // 1日の運転時間
    | 'driving_time_2day_avg'   // 2日平均運転時間
    | 'driving_time_2week_avg'  // 2週平均運転時間
    | 'rest_period'             // 休息期間不足
    | 'continuous_driving';     // 連続運転時間超過

export type AlertLevel = 'warning' | 'violation' | 'critical';

// デフォルト設定（改善基準告示準拠）
const DEFAULT_SETTINGS = {
    daily_binding_time_limit: 780,           // 13時間 = 780分
    daily_binding_time_extended: 960,        // 16時間 = 960分
    extended_days_per_week: 2,
    monthly_binding_time_limit: 17040,       // 284時間 = 17040分
    monthly_binding_time_agreement: 18600,   // 310時間 = 18600分
    daily_driving_time_limit: 540,           // 9時間 = 540分
    daily_driving_time_extended: 600,        // 10時間 = 600分
    two_day_avg_driving_limit: 540,          // 9時間 = 540分
    two_week_avg_driving_limit: 2640,        // 44時間 = 2640分
    rest_period_minimum: 480,                // 8時間 = 480分
    continuous_driving_limit: 240,           // 4時間 = 240分
    break_time_minimum: 30,                  // 30分
    warning_threshold_percent: 90,
    has_labor_agreement: false
};

interface ComplianceSettings {
    daily_binding_time_limit: number;
    daily_binding_time_extended: number;
    extended_days_per_week: number;
    monthly_binding_time_limit: number;
    monthly_binding_time_agreement: number;
    daily_driving_time_limit: number;
    daily_driving_time_extended: number;
    two_day_avg_driving_limit: number;
    two_week_avg_driving_limit: number;
    rest_period_minimum: number;
    continuous_driving_limit: number;
    break_time_minimum: number;
    warning_threshold_percent: number;
    has_labor_agreement: boolean;
}

interface LaborAlert {
    company_id: number;
    driver_id: number;
    alert_type: AlertType;
    alert_level: AlertLevel;
    alert_date: string;
    threshold_value: number;
    actual_value: number;
    threshold_label: string;
    description: string;
    work_record_ids?: number[];
}

// 会社の設定を取得（なければデフォルト値）
export async function getComplianceSettings(companyId: number): Promise<ComplianceSettings> {
    const result = await pool.query(
        'SELECT * FROM labor_compliance_settings WHERE company_id = $1',
        [companyId]
    );

    if (result.rows.length > 0) {
        return result.rows[0];
    }

    return DEFAULT_SETTINGS;
}

// 設定を保存/更新
export async function saveComplianceSettings(companyId: number, settings: Partial<ComplianceSettings>): Promise<ComplianceSettings> {
    const result = await pool.query(`
        INSERT INTO labor_compliance_settings (company_id, ${Object.keys(settings).join(', ')})
        VALUES ($1, ${Object.keys(settings).map((_, i) => `$${i + 2}`).join(', ')})
        ON CONFLICT (company_id) DO UPDATE SET
            ${Object.keys(settings).map(k => `${k} = EXCLUDED.${k}`).join(', ')},
            updated_at = CURRENT_TIMESTAMP
        RETURNING *
    `, [companyId, ...Object.values(settings)]);

    return result.rows[0];
}

// 拘束時間計算（始業から終業まで - 休息時間）
export function calculateBindingTime(startTime: Date, endTime: Date, restMinutes: number = 0): number {
    const diffMs = endTime.getTime() - startTime.getTime();
    const totalMinutes = Math.floor(diffMs / 60000);
    return Math.max(0, totalMinutes - restMinutes);
}

// 1日の拘束時間をチェック
export async function checkDailyBindingTime(
    driverId: number,
    companyId: number,
    date: string,
    bindingMinutes: number,
    settings: ComplianceSettings
): Promise<LaborAlert | null> {
    const limit = settings.daily_binding_time_limit;
    const extendedLimit = settings.daily_binding_time_extended;
    const warningThreshold = Math.floor(limit * settings.warning_threshold_percent / 100);

    if (bindingMinutes >= extendedLimit) {
        return {
            company_id: companyId,
            driver_id: driverId,
            alert_type: 'binding_time_daily',
            alert_level: 'critical',
            alert_date: date,
            threshold_value: extendedLimit,
            actual_value: bindingMinutes,
            threshold_label: '1日の拘束時間上限（延長）16時間',
            description: `拘束時間が${Math.floor(bindingMinutes / 60)}時間${bindingMinutes % 60}分で、延長上限16時間を超過しています。`
        };
    }

    if (bindingMinutes >= limit) {
        // 延長日として週2回まで許容されるかチェック
        const weekStart = getWeekStart(new Date(date));
        const weekEnd = getWeekEnd(new Date(date));

        const extendedDaysResult = await pool.query(`
            SELECT COUNT(*) as count FROM labor_daily_summary
            WHERE driver_id = $1 AND summary_date >= $2 AND summary_date <= $3 AND is_extended_day = TRUE
        `, [driverId, weekStart, weekEnd]);

        const extendedDaysCount = parseInt(extendedDaysResult.rows[0].count);

        if (extendedDaysCount >= settings.extended_days_per_week) {
            return {
                company_id: companyId,
                driver_id: driverId,
                alert_type: 'binding_time_daily',
                alert_level: 'violation',
                alert_date: date,
                threshold_value: limit,
                actual_value: bindingMinutes,
                threshold_label: '1日の拘束時間上限13時間（週2回まで延長可）',
                description: `拘束時間が${Math.floor(bindingMinutes / 60)}時間${bindingMinutes % 60}分で、今週は既に${extendedDaysCount}回延長しているため違反です。`
            };
        }

        return {
            company_id: companyId,
            driver_id: driverId,
            alert_type: 'binding_time_daily',
            alert_level: 'warning',
            alert_date: date,
            threshold_value: limit,
            actual_value: bindingMinutes,
            threshold_label: '1日の拘束時間上限13時間',
            description: `拘束時間が${Math.floor(bindingMinutes / 60)}時間${bindingMinutes % 60}分で上限13時間を超えました。延長日として計上します。`
        };
    }

    if (bindingMinutes >= warningThreshold) {
        return {
            company_id: companyId,
            driver_id: driverId,
            alert_type: 'binding_time_daily',
            alert_level: 'warning',
            alert_date: date,
            threshold_value: limit,
            actual_value: bindingMinutes,
            threshold_label: '1日の拘束時間上限13時間の90%',
            description: `拘束時間が${Math.floor(bindingMinutes / 60)}時間${bindingMinutes % 60}分で、上限の90%を超えています。`
        };
    }

    return null;
}

// 月間拘束時間をチェック
export async function checkMonthlyBindingTime(
    driverId: number,
    companyId: number,
    yearMonth: string,  // 'YYYY-MM'
    settings: ComplianceSettings
): Promise<LaborAlert | null> {
    const limit = settings.has_labor_agreement
        ? settings.monthly_binding_time_agreement
        : settings.monthly_binding_time_limit;

    const result = await pool.query(`
        SELECT COALESCE(SUM(total_binding_minutes), 0) as total
        FROM labor_daily_summary
        WHERE driver_id = $1 AND TO_CHAR(summary_date, 'YYYY-MM') = $2
    `, [driverId, yearMonth]);

    const totalBindingMinutes = parseInt(result.rows[0].total);
    const limitHours = Math.floor(limit / 60);
    const warningThreshold = Math.floor(limit * settings.warning_threshold_percent / 100);

    if (totalBindingMinutes >= limit) {
        return {
            company_id: companyId,
            driver_id: driverId,
            alert_type: 'binding_time_monthly',
            alert_level: 'violation',
            alert_date: `${yearMonth}-01`,
            threshold_value: limit,
            actual_value: totalBindingMinutes,
            threshold_label: `月間拘束時間上限${limitHours}時間${settings.has_labor_agreement ? '（労使協定）' : ''}`,
            description: `月間拘束時間が${Math.floor(totalBindingMinutes / 60)}時間で、上限${limitHours}時間を超過しています。`
        };
    }

    if (totalBindingMinutes >= warningThreshold) {
        return {
            company_id: companyId,
            driver_id: driverId,
            alert_type: 'binding_time_monthly',
            alert_level: 'warning',
            alert_date: `${yearMonth}-01`,
            threshold_value: limit,
            actual_value: totalBindingMinutes,
            threshold_label: `月間拘束時間上限${limitHours}時間の90%`,
            description: `月間拘束時間が${Math.floor(totalBindingMinutes / 60)}時間で、上限の90%を超えています。`
        };
    }

    return null;
}

// 1日の運転時間をチェック
export async function checkDailyDrivingTime(
    driverId: number,
    companyId: number,
    date: string,
    drivingMinutes: number,
    settings: ComplianceSettings
): Promise<LaborAlert | null> {
    const limit = settings.daily_driving_time_limit;
    const extendedLimit = settings.daily_driving_time_extended;
    const warningThreshold = Math.floor(limit * settings.warning_threshold_percent / 100);

    if (drivingMinutes >= extendedLimit) {
        return {
            company_id: companyId,
            driver_id: driverId,
            alert_type: 'driving_time_daily',
            alert_level: 'critical',
            alert_date: date,
            threshold_value: extendedLimit,
            actual_value: drivingMinutes,
            threshold_label: '1日の運転時間上限（延長）10時間',
            description: `運転時間が${Math.floor(drivingMinutes / 60)}時間${drivingMinutes % 60}分で、延長上限10時間を超過しています。`
        };
    }

    if (drivingMinutes >= limit) {
        return {
            company_id: companyId,
            driver_id: driverId,
            alert_type: 'driving_time_daily',
            alert_level: 'warning',
            alert_date: date,
            threshold_value: limit,
            actual_value: drivingMinutes,
            threshold_label: '1日の運転時間上限9時間',
            description: `運転時間が${Math.floor(drivingMinutes / 60)}時間${drivingMinutes % 60}分で上限9時間を超えました。`
        };
    }

    if (drivingMinutes >= warningThreshold) {
        return {
            company_id: companyId,
            driver_id: driverId,
            alert_type: 'driving_time_daily',
            alert_level: 'warning',
            alert_date: date,
            threshold_value: limit,
            actual_value: drivingMinutes,
            threshold_label: '1日の運転時間上限9時間の90%',
            description: `運転時間が${Math.floor(drivingMinutes / 60)}時間${drivingMinutes % 60}分で、上限の90%を超えています。`
        };
    }

    return null;
}

// 2日平均運転時間をチェック
export async function check2DayAvgDrivingTime(
    driverId: number,
    companyId: number,
    date: string,
    settings: ComplianceSettings
): Promise<LaborAlert | null> {
    const targetDate = new Date(date);
    const prevDate = new Date(targetDate);
    prevDate.setDate(prevDate.getDate() - 1);

    const result = await pool.query(`
        SELECT COALESCE(AVG(total_driving_minutes), 0) as avg
        FROM labor_daily_summary
        WHERE driver_id = $1 AND summary_date IN ($2, $3)
    `, [driverId, date, prevDate.toISOString().split('T')[0]]);

    const avgDrivingMinutes = Math.floor(parseFloat(result.rows[0].avg));
    const limit = settings.two_day_avg_driving_limit;

    if (avgDrivingMinutes > limit) {
        return {
            company_id: companyId,
            driver_id: driverId,
            alert_type: 'driving_time_2day_avg',
            alert_level: 'violation',
            alert_date: date,
            threshold_value: limit,
            actual_value: avgDrivingMinutes,
            threshold_label: '2日平均運転時間上限9時間',
            description: `2日平均運転時間が${Math.floor(avgDrivingMinutes / 60)}時間${avgDrivingMinutes % 60}分で上限9時間を超過しています。`
        };
    }

    return null;
}

// 2週平均運転時間をチェック
export async function check2WeekAvgDrivingTime(
    driverId: number,
    companyId: number,
    date: string,
    settings: ComplianceSettings
): Promise<LaborAlert | null> {
    const endDate = new Date(date);
    const startDate = new Date(date);
    startDate.setDate(startDate.getDate() - 13);  // 2週間 = 14日

    const result = await pool.query(`
        SELECT COALESCE(SUM(total_driving_minutes), 0) as total
        FROM labor_daily_summary
        WHERE driver_id = $1 AND summary_date >= $2 AND summary_date <= $3
    `, [driverId, startDate.toISOString().split('T')[0], date]);

    const totalDrivingMinutes = parseInt(result.rows[0].total);
    const limit = settings.two_week_avg_driving_limit;

    if (totalDrivingMinutes > limit) {
        return {
            company_id: companyId,
            driver_id: driverId,
            alert_type: 'driving_time_2week_avg',
            alert_level: 'violation',
            alert_date: date,
            threshold_value: limit,
            actual_value: totalDrivingMinutes,
            threshold_label: '2週間合計運転時間上限44時間',
            description: `2週間の運転時間合計が${Math.floor(totalDrivingMinutes / 60)}時間で上限44時間を超過しています。`
        };
    }

    return null;
}

// 休息期間をチェック
export async function checkRestPeriod(
    driverId: number,
    companyId: number,
    date: string,
    restMinutes: number,
    settings: ComplianceSettings
): Promise<LaborAlert | null> {
    const limit = settings.rest_period_minimum;

    if (restMinutes < limit) {
        return {
            company_id: companyId,
            driver_id: driverId,
            alert_type: 'rest_period',
            alert_level: 'violation',
            alert_date: date,
            threshold_value: limit,
            actual_value: restMinutes,
            threshold_label: '継続休息期間8時間以上',
            description: `休息期間が${Math.floor(restMinutes / 60)}時間${restMinutes % 60}分で、最低8時間を確保できていません。`
        };
    }

    return null;
}

// 連続運転時間をチェック
export async function checkContinuousDriving(
    driverId: number,
    companyId: number,
    date: string,
    maxContinuousDrivingMinutes: number,
    settings: ComplianceSettings
): Promise<LaborAlert | null> {
    const limit = settings.continuous_driving_limit;

    if (maxContinuousDrivingMinutes > limit) {
        return {
            company_id: companyId,
            driver_id: driverId,
            alert_type: 'continuous_driving',
            alert_level: 'violation',
            alert_date: date,
            threshold_value: limit,
            actual_value: maxContinuousDrivingMinutes,
            threshold_label: '連続運転時間4時間以内',
            description: `連続運転時間が${Math.floor(maxContinuousDrivingMinutes / 60)}時間${maxContinuousDrivingMinutes % 60}分で、上限4時間を超過しています。30分以上の休憩が必要です。`
        };
    }

    return null;
}

// アラートを保存
export async function saveAlert(alert: LaborAlert): Promise<number> {
    const result = await pool.query(`
        INSERT INTO labor_alerts (
            company_id, driver_id, alert_type, alert_level, alert_date,
            threshold_value, actual_value, threshold_label, description, work_record_ids
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        RETURNING id
    `, [
        alert.company_id,
        alert.driver_id,
        alert.alert_type,
        alert.alert_level,
        alert.alert_date,
        alert.threshold_value,
        alert.actual_value,
        alert.threshold_label,
        alert.description,
        alert.work_record_ids || null
    ]);

    return result.rows[0].id;
}

// 日次サマリーを更新/作成
export async function updateDailySummary(
    driverId: number,
    date: string,
    bindingMinutes: number,
    drivingMinutes: number,
    restMinutes: number,
    breakMinutes: number,
    maxContinuousDriving: number,
    isExtendedDay: boolean,
    hasViolation: boolean,
    workRecordIds: number[]
): Promise<void> {
    await pool.query(`
        INSERT INTO labor_daily_summary (
            driver_id, summary_date, total_binding_minutes, total_driving_minutes,
            total_rest_minutes, total_break_minutes, max_continuous_driving,
            is_extended_day, has_violation, work_record_ids, calculated_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, CURRENT_TIMESTAMP)
        ON CONFLICT (driver_id, summary_date) DO UPDATE SET
            total_binding_minutes = $3,
            total_driving_minutes = $4,
            total_rest_minutes = $5,
            total_break_minutes = $6,
            max_continuous_driving = $7,
            is_extended_day = $8,
            has_violation = $9,
            work_record_ids = $10,
            calculated_at = CURRENT_TIMESTAMP
    `, [
        driverId, date, bindingMinutes, drivingMinutes,
        restMinutes, breakMinutes, maxContinuousDriving,
        isExtendedDay, hasViolation, workRecordIds
    ]);
}

// 運行記録から労務データを計算してチェックを実行
export async function processWorkRecord(workRecordId: number): Promise<LaborAlert[]> {
    const alerts: LaborAlert[] = [];

    // 運行記録を取得
    const recordResult = await pool.query(`
        SELECT wr.*, u.company_id
        FROM work_records wr
        JOIN users u ON wr.driver_id = u.id
        WHERE wr.id = $1
    `, [workRecordId]);

    if (recordResult.rows.length === 0) {
        return alerts;
    }

    const record = recordResult.rows[0];
    const driverId = record.driver_id;
    const companyId = record.company_id;
    const date = record.work_date.toISOString().split('T')[0];

    // 設定を取得
    const settings = await getComplianceSettings(companyId);

    // 拘束時間計算
    const startTime = new Date(record.start_time);
    const endTime = record.end_time ? new Date(record.end_time) : new Date();
    const restMinutes = record.rest_time_minutes || 0;
    const bindingMinutes = calculateBindingTime(startTime, endTime, restMinutes);

    // 運転時間（デジタコデータまたは走行時間から算出）
    const drivingMinutes = record.driving_time_minutes ||
        Math.floor((endTime.getTime() - startTime.getTime()) / 60000) -
        (record.manual_break_minutes || record.auto_break_minutes || 0);

    // 休憩時間
    const breakMinutes = record.manual_break_minutes || record.auto_break_minutes || 0;

    // 連続運転時間（デジタコデータがあれば使用、なければ推定）
    const maxContinuousDriving = record.max_continuous_driving || 0;

    // work_recordsを更新
    await pool.query(`
        UPDATE work_records SET
            binding_time_minutes = $1,
            driving_time_minutes = $2
        WHERE id = $3
    `, [bindingMinutes, drivingMinutes, workRecordId]);

    // 各チェックを実行
    const dailyBindingAlert = await checkDailyBindingTime(driverId, companyId, date, bindingMinutes, settings);
    if (dailyBindingAlert) alerts.push(dailyBindingAlert);

    const dailyDrivingAlert = await checkDailyDrivingTime(driverId, companyId, date, drivingMinutes, settings);
    if (dailyDrivingAlert) alerts.push(dailyDrivingAlert);

    const twoDayAvgAlert = await check2DayAvgDrivingTime(driverId, companyId, date, settings);
    if (twoDayAvgAlert) alerts.push(twoDayAvgAlert);

    const twoWeekAvgAlert = await check2WeekAvgDrivingTime(driverId, companyId, date, settings);
    if (twoWeekAvgAlert) alerts.push(twoWeekAvgAlert);

    if (maxContinuousDriving > 0) {
        const continuousDrivingAlert = await checkContinuousDriving(driverId, companyId, date, maxContinuousDriving, settings);
        if (continuousDrivingAlert) alerts.push(continuousDrivingAlert);
    }

    // 月間チェック
    const yearMonth = date.substring(0, 7);
    const monthlyBindingAlert = await checkMonthlyBindingTime(driverId, companyId, yearMonth, settings);
    if (monthlyBindingAlert) alerts.push(monthlyBindingAlert);

    // アラートを保存
    for (const alert of alerts) {
        alert.work_record_ids = [workRecordId];
        await saveAlert(alert);
    }

    // 日次サマリーを更新
    const isExtendedDay = bindingMinutes > settings.daily_binding_time_limit;
    const hasViolation = alerts.some(a => a.alert_level === 'violation' || a.alert_level === 'critical');

    await updateDailySummary(
        driverId, date, bindingMinutes, drivingMinutes,
        restMinutes, breakMinutes, maxContinuousDriving,
        isExtendedDay, hasViolation, [workRecordId]
    );

    return alerts;
}

// 会社全体のアラート一覧を取得
export async function getCompanyAlerts(
    companyId: number,
    options: {
        acknowledged?: boolean;
        alertLevel?: AlertLevel;
        alertType?: AlertType;
        dateFrom?: string;
        dateTo?: string;
        driverId?: number;
        limit?: number;
        offset?: number;
    } = {}
): Promise<{ alerts: any[]; total: number }> {
    const conditions: string[] = ['la.company_id = $1'];
    const params: any[] = [companyId];
    let paramIndex = 2;

    if (options.acknowledged !== undefined) {
        conditions.push(`la.acknowledged = $${paramIndex}`);
        params.push(options.acknowledged);
        paramIndex++;
    }

    if (options.alertLevel) {
        conditions.push(`la.alert_level = $${paramIndex}`);
        params.push(options.alertLevel);
        paramIndex++;
    }

    if (options.alertType) {
        conditions.push(`la.alert_type = $${paramIndex}`);
        params.push(options.alertType);
        paramIndex++;
    }

    if (options.dateFrom) {
        conditions.push(`la.alert_date >= $${paramIndex}`);
        params.push(options.dateFrom);
        paramIndex++;
    }

    if (options.dateTo) {
        conditions.push(`la.alert_date <= $${paramIndex}`);
        params.push(options.dateTo);
        paramIndex++;
    }

    if (options.driverId) {
        conditions.push(`la.driver_id = $${paramIndex}`);
        params.push(options.driverId);
        paramIndex++;
    }

    const whereClause = conditions.join(' AND ');

    // 総件数を取得
    const countResult = await pool.query(
        `SELECT COUNT(*) FROM labor_alerts la WHERE ${whereClause}`,
        params
    );
    const total = parseInt(countResult.rows[0].count);

    // データ取得
    const limit = options.limit || 50;
    const offset = options.offset || 0;

    const result = await pool.query(`
        SELECT
            la.*,
            u.name as driver_name,
            u.employee_number,
            ack.name as acknowledged_by_name
        FROM labor_alerts la
        JOIN users u ON la.driver_id = u.id
        LEFT JOIN users ack ON la.acknowledged_by = ack.id
        WHERE ${whereClause}
        ORDER BY
            CASE la.alert_level
                WHEN 'critical' THEN 1
                WHEN 'violation' THEN 2
                WHEN 'warning' THEN 3
            END,
            la.created_at DESC
        LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
    `, [...params, limit, offset]);

    return {
        alerts: result.rows,
        total
    };
}

// アラートを確認済みにする
export async function acknowledgeAlert(alertId: number, userId: number): Promise<void> {
    await pool.query(`
        UPDATE labor_alerts SET
            acknowledged = TRUE,
            acknowledged_by = $1,
            acknowledged_at = CURRENT_TIMESTAMP
        WHERE id = $2
    `, [userId, alertId]);
}

// 複数アラートを一括確認済みにする
export async function acknowledgeAlerts(alertIds: number[], userId: number): Promise<number> {
    const result = await pool.query(`
        UPDATE labor_alerts SET
            acknowledged = TRUE,
            acknowledged_by = $1,
            acknowledged_at = CURRENT_TIMESTAMP
        WHERE id = ANY($2) AND acknowledged = FALSE
    `, [userId, alertIds]);

    return result.rowCount || 0;
}

// ドライバーの月間サマリーを取得
export async function getDriverMonthlySummary(driverId: number, yearMonth: string): Promise<any> {
    const result = await pool.query(`
        SELECT
            driver_id,
            SUM(total_binding_minutes) as total_binding_minutes,
            SUM(total_driving_minutes) as total_driving_minutes,
            SUM(total_break_minutes) as total_break_minutes,
            COUNT(*) as work_days,
            COUNT(CASE WHEN is_extended_day THEN 1 END) as extended_days,
            COUNT(CASE WHEN has_violation THEN 1 END) as violation_days,
            MAX(total_binding_minutes) as max_daily_binding,
            MAX(total_driving_minutes) as max_daily_driving
        FROM labor_daily_summary
        WHERE driver_id = $1 AND TO_CHAR(summary_date, 'YYYY-MM') = $2
        GROUP BY driver_id
    `, [driverId, yearMonth]);

    if (result.rows.length === 0) {
        return {
            driver_id: driverId,
            total_binding_minutes: 0,
            total_driving_minutes: 0,
            total_break_minutes: 0,
            work_days: 0,
            extended_days: 0,
            violation_days: 0
        };
    }

    return result.rows[0];
}

// 会社全体の月間統計を取得
export async function getCompanyMonthlyStats(companyId: number, yearMonth: string): Promise<any> {
    const result = await pool.query(`
        SELECT
            COUNT(DISTINCT lds.driver_id) as active_drivers,
            SUM(lds.total_binding_minutes) as total_binding_minutes,
            SUM(lds.total_driving_minutes) as total_driving_minutes,
            COUNT(CASE WHEN lds.is_extended_day THEN 1 END) as total_extended_days,
            COUNT(CASE WHEN lds.has_violation THEN 1 END) as total_violation_days,
            AVG(lds.total_binding_minutes) as avg_daily_binding,
            AVG(lds.total_driving_minutes) as avg_daily_driving
        FROM labor_daily_summary lds
        JOIN users u ON lds.driver_id = u.id
        WHERE u.company_id = $1 AND TO_CHAR(lds.summary_date, 'YYYY-MM') = $2
    `, [companyId, yearMonth]);

    // アラート統計
    const alertStats = await pool.query(`
        SELECT
            alert_level,
            COUNT(*) as count
        FROM labor_alerts
        WHERE company_id = $1 AND TO_CHAR(alert_date, 'YYYY-MM') = $2
        GROUP BY alert_level
    `, [companyId, yearMonth]);

    const alertsByLevel: Record<string, number> = {};
    for (const row of alertStats.rows) {
        alertsByLevel[row.alert_level] = parseInt(row.count);
    }

    return {
        ...result.rows[0],
        alerts: alertsByLevel
    };
}

// ユーティリティ関数
function getWeekStart(date: Date): string {
    const d = new Date(date);
    const day = d.getDay();
    const diff = d.getDate() - day + (day === 0 ? -6 : 1);  // 月曜日始まり
    d.setDate(diff);
    return d.toISOString().split('T')[0];
}

function getWeekEnd(date: Date): string {
    const d = new Date(date);
    const day = d.getDay();
    const diff = d.getDate() + (7 - day) % 7;  // 日曜日終わり
    if (day !== 0) d.setDate(diff);
    return d.toISOString().split('T')[0];
}
