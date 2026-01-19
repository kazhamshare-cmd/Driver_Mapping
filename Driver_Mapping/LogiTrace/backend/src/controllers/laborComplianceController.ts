/**
 * Labor Compliance Controller - 労務コンプライアンスAPI
 * 改善基準告示対応の拘束時間・運転時間監視
 */

import { Request, Response } from 'express';
import * as laborComplianceService from '../services/laborComplianceService';

// アラート一覧取得
export const getAlerts = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;
    const {
        acknowledged,
        alert_level,
        alert_type,
        date_from,
        date_to,
        driver_id,
        limit,
        offset
    } = req.query;

    try {
        const result = await laborComplianceService.getCompanyAlerts(companyId, {
            acknowledged: acknowledged !== undefined ? acknowledged === 'true' : undefined,
            alertLevel: alert_level as any,
            alertType: alert_type as any,
            dateFrom: date_from as string,
            dateTo: date_to as string,
            driverId: driver_id ? parseInt(driver_id as string) : undefined,
            limit: limit ? parseInt(limit as string) : 50,
            offset: offset ? parseInt(offset as string) : 0
        });

        res.json(result);
    } catch (error) {
        console.error('Error fetching labor alerts:', error);
        res.status(500).json({ error: 'Failed to fetch labor alerts' });
    }
};

// 未確認アラート数を取得（ダッシュボード用）
export const getUnacknowledgedCount = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;

    try {
        const result = await laborComplianceService.getCompanyAlerts(companyId, {
            acknowledged: false,
            limit: 1000  // 件数カウント用
        });

        // レベル別に集計
        const countByLevel: Record<string, number> = {
            critical: 0,
            violation: 0,
            warning: 0
        };

        for (const alert of result.alerts) {
            countByLevel[alert.alert_level]++;
        }

        res.json({
            total: result.total,
            byLevel: countByLevel
        });
    } catch (error) {
        console.error('Error fetching unacknowledged count:', error);
        res.status(500).json({ error: 'Failed to fetch count' });
    }
};

// アラートを確認済みにする
export const acknowledgeAlert = async (req: Request, res: Response) => {
    const { id } = req.params;
    const userId = (req as any).user?.userId;

    try {
        await laborComplianceService.acknowledgeAlert(parseInt(id), userId);
        res.json({ message: 'Alert acknowledged' });
    } catch (error) {
        console.error('Error acknowledging alert:', error);
        res.status(500).json({ error: 'Failed to acknowledge alert' });
    }
};

// 複数アラートを一括確認済みにする
export const bulkAcknowledgeAlerts = async (req: Request, res: Response) => {
    const { alert_ids } = req.body;
    const userId = (req as any).user?.userId;

    if (!alert_ids || !Array.isArray(alert_ids) || alert_ids.length === 0) {
        return res.status(400).json({ error: 'Alert IDs are required' });
    }

    try {
        const count = await laborComplianceService.acknowledgeAlerts(alert_ids, userId);
        res.json({
            message: 'Alerts acknowledged',
            count
        });
    } catch (error) {
        console.error('Error bulk acknowledging alerts:', error);
        res.status(500).json({ error: 'Failed to acknowledge alerts' });
    }
};

// コンプライアンス設定を取得
export const getSettings = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;

    try {
        const settings = await laborComplianceService.getComplianceSettings(companyId);
        res.json(settings);
    } catch (error) {
        console.error('Error fetching compliance settings:', error);
        res.status(500).json({ error: 'Failed to fetch settings' });
    }
};

// コンプライアンス設定を更新
export const updateSettings = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;
    const settings = req.body;

    try {
        const updated = await laborComplianceService.saveComplianceSettings(companyId, settings);
        res.json(updated);
    } catch (error) {
        console.error('Error updating compliance settings:', error);
        res.status(500).json({ error: 'Failed to update settings' });
    }
};

// ドライバーの月間サマリーを取得
export const getDriverMonthlySummary = async (req: Request, res: Response) => {
    const { driver_id, year_month } = req.query;

    if (!driver_id || !year_month) {
        return res.status(400).json({ error: 'driver_id and year_month are required' });
    }

    try {
        const summary = await laborComplianceService.getDriverMonthlySummary(
            parseInt(driver_id as string),
            year_month as string
        );
        res.json(summary);
    } catch (error) {
        console.error('Error fetching driver monthly summary:', error);
        res.status(500).json({ error: 'Failed to fetch summary' });
    }
};

// 会社全体の月間統計を取得
export const getCompanyMonthlyStats = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;
    const { year_month } = req.query;

    const targetMonth = year_month as string ||
        new Date().toISOString().substring(0, 7);

    try {
        const stats = await laborComplianceService.getCompanyMonthlyStats(companyId, targetMonth);
        res.json({
            year_month: targetMonth,
            ...stats
        });
    } catch (error) {
        console.error('Error fetching company monthly stats:', error);
        res.status(500).json({ error: 'Failed to fetch stats' });
    }
};

// 運行記録のコンプライアンスチェックを実行
export const processWorkRecord = async (req: Request, res: Response) => {
    const { work_record_id } = req.body;

    if (!work_record_id) {
        return res.status(400).json({ error: 'work_record_id is required' });
    }

    try {
        const alerts = await laborComplianceService.processWorkRecord(work_record_id);
        res.json({
            message: 'Compliance check completed',
            alerts_generated: alerts.length,
            alerts
        });
    } catch (error) {
        console.error('Error processing work record:', error);
        res.status(500).json({ error: 'Failed to process work record' });
    }
};

// ドライバー別の現在の拘束時間状況を取得（リアルタイム監視用）
export const getDriverCurrentStatus = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;
    const today = new Date().toISOString().split('T')[0];

    try {
        // 今日の運行記録と拘束時間を取得
        const { pool } = await import('../utils/db');

        const result = await pool.query(`
            SELECT
                u.id as driver_id,
                u.name as driver_name,
                u.employee_number,
                wr.id as work_record_id,
                wr.start_time,
                wr.end_time,
                wr.binding_time_minutes,
                wr.driving_time_minutes,
                wr.status,
                COALESCE(wr.manual_break_minutes, wr.auto_break_minutes, 0) as break_minutes,
                CASE
                    WHEN wr.end_time IS NULL THEN
                        EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - wr.start_time)) / 60
                    ELSE
                        EXTRACT(EPOCH FROM (wr.end_time - wr.start_time)) / 60
                END as current_binding_minutes
            FROM users u
            LEFT JOIN work_records wr ON u.id = wr.driver_id AND wr.work_date = $1
            WHERE u.company_id = $2 AND u.role = 'driver'
            ORDER BY
                CASE WHEN wr.end_time IS NULL THEN 0 ELSE 1 END,
                current_binding_minutes DESC
        `, [today, companyId]);

        // 設定を取得
        const settings = await laborComplianceService.getComplianceSettings(companyId);
        const warningThreshold = settings.daily_binding_time_limit * settings.warning_threshold_percent / 100;

        // ステータス付与
        const drivers = result.rows.map(row => {
            const currentBinding = Math.floor(row.current_binding_minutes || 0);
            let status = 'normal';

            if (currentBinding >= settings.daily_binding_time_extended) {
                status = 'critical';
            } else if (currentBinding >= settings.daily_binding_time_limit) {
                status = 'violation';
            } else if (currentBinding >= warningThreshold) {
                status = 'warning';
            }

            return {
                ...row,
                current_binding_minutes: currentBinding,
                binding_limit: settings.daily_binding_time_limit,
                binding_extended_limit: settings.daily_binding_time_extended,
                binding_status: status,
                is_working: row.work_record_id && !row.end_time
            };
        });

        res.json({
            date: today,
            drivers,
            summary: {
                total_drivers: drivers.length,
                working: drivers.filter(d => d.is_working).length,
                warning: drivers.filter(d => d.binding_status === 'warning').length,
                violation: drivers.filter(d => d.binding_status === 'violation').length,
                critical: drivers.filter(d => d.binding_status === 'critical').length
            }
        });
    } catch (error) {
        console.error('Error fetching driver current status:', error);
        res.status(500).json({ error: 'Failed to fetch driver status' });
    }
};

// ドライバー詳細（過去7日間のトレンド）
export const getDriverComplianceDetail = async (req: Request, res: Response) => {
    const { driver_id } = req.params;

    try {
        const { pool } = await import('../utils/db');

        // 過去7日間のサマリー
        const summaryResult = await pool.query(`
            SELECT
                summary_date,
                total_binding_minutes,
                total_driving_minutes,
                total_break_minutes,
                is_extended_day,
                has_violation
            FROM labor_daily_summary
            WHERE driver_id = $1
            ORDER BY summary_date DESC
            LIMIT 7
        `, [driver_id]);

        // 過去7日間のアラート
        const alertsResult = await pool.query(`
            SELECT
                id,
                alert_type,
                alert_level,
                alert_date,
                threshold_value,
                actual_value,
                description,
                acknowledged
            FROM labor_alerts
            WHERE driver_id = $1
            ORDER BY created_at DESC
            LIMIT 20
        `, [driver_id]);

        // 今月のサマリー
        const yearMonth = new Date().toISOString().substring(0, 7);
        const monthlySummary = await laborComplianceService.getDriverMonthlySummary(
            parseInt(driver_id),
            yearMonth
        );

        res.json({
            driver_id: parseInt(driver_id),
            daily_summary: summaryResult.rows,
            recent_alerts: alertsResult.rows,
            monthly_summary: monthlySummary
        });
    } catch (error) {
        console.error('Error fetching driver compliance detail:', error);
        res.status(500).json({ error: 'Failed to fetch driver detail' });
    }
};
