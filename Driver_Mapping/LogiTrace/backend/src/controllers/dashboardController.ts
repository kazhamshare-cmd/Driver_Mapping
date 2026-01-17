import { Request, Response } from 'express';
import { pool } from '../utils/db';

// ダッシュボード集計データ取得
export const getDashboardSummary = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.query;
        const today = new Date().toISOString().split('T')[0];

        // 並列でクエリ実行
        const [
            driversResult,
            vehiclesResult,
            todayRecordsResult,
            monthlyDistanceResult
        ] = await Promise.all([
            // ドライバー数
            pool.query(
                `SELECT
                    COUNT(*) FILTER (WHERE status = 'active') as active_count,
                    COUNT(*) as total_count
                 FROM users
                 WHERE company_id = $1 AND user_type = 'driver'`,
                [companyId]
            ),
            // 車両数
            pool.query(
                `SELECT
                    COUNT(*) FILTER (WHERE status = 'active') as active_count,
                    COUNT(*) as total_count
                 FROM vehicles
                 WHERE company_id = $1`,
                [companyId]
            ),
            // 本日の日報
            pool.query(
                `SELECT
                    COUNT(*) FILTER (WHERE status = 'confirmed') as confirmed_count,
                    COUNT(*) FILTER (WHERE status = 'pending') as pending_count,
                    COUNT(*) as total_count
                 FROM work_records wr
                 JOIN users u ON wr.driver_id = u.id
                 WHERE u.company_id = $1 AND wr.work_date = $2`,
                [companyId, today]
            ),
            // 今月の走行距離
            pool.query(
                `SELECT
                    COALESCE(SUM(distance), 0) as total_distance
                 FROM work_records wr
                 JOIN users u ON wr.driver_id = u.id
                 WHERE u.company_id = $1
                 AND EXTRACT(YEAR FROM wr.work_date) = EXTRACT(YEAR FROM CURRENT_DATE)
                 AND EXTRACT(MONTH FROM wr.work_date) = EXTRACT(MONTH FROM CURRENT_DATE)`,
                [companyId]
            )
        ]);

        res.json({
            drivers: {
                active: parseInt(driversResult.rows[0]?.active_count || '0'),
                total: parseInt(driversResult.rows[0]?.total_count || '0')
            },
            vehicles: {
                active: parseInt(vehiclesResult.rows[0]?.active_count || '0'),
                total: parseInt(vehiclesResult.rows[0]?.total_count || '0')
            },
            todayReports: {
                confirmed: parseInt(todayRecordsResult.rows[0]?.confirmed_count || '0'),
                pending: parseInt(todayRecordsResult.rows[0]?.pending_count || '0'),
                total: parseInt(todayRecordsResult.rows[0]?.total_count || '0')
            },
            monthlyDistance: parseFloat(monthlyDistanceResult.rows[0]?.total_distance || '0')
        });
    } catch (error) {
        console.error('Error fetching dashboard summary:', error);
        res.status(500).json({ error: 'Failed to fetch dashboard summary' });
    }
};

// 最近の活動取得
export const getRecentActivities = async (req: Request, res: Response) => {
    try {
        const { companyId, limit = 10 } = req.query;

        const result = await pool.query(
            `SELECT
                wr.id,
                wr.work_date,
                wr.start_time,
                wr.end_time,
                wr.distance,
                wr.status,
                u.name as driver_name,
                v.vehicle_number
             FROM work_records wr
             JOIN users u ON wr.driver_id = u.id
             LEFT JOIN vehicles v ON wr.vehicle_id = v.id
             WHERE u.company_id = $1
             ORDER BY wr.created_at DESC
             LIMIT $2`,
            [companyId, limit]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching recent activities:', error);
        res.status(500).json({ error: 'Failed to fetch recent activities' });
    }
};

// 車両ステータス取得
export const getVehicleStatus = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.query;
        const today = new Date().toISOString().split('T')[0];

        const result = await pool.query(
            `SELECT
                v.id,
                v.vehicle_number,
                v.vehicle_type,
                v.status,
                u.name as current_driver,
                wr.start_time,
                wr.end_time
             FROM vehicles v
             LEFT JOIN (
                SELECT DISTINCT ON (vehicle_id) *
                FROM work_records
                WHERE work_date = $2
                ORDER BY vehicle_id, start_time DESC
             ) wr ON v.id = wr.vehicle_id
             LEFT JOIN users u ON wr.driver_id = u.id
             WHERE v.company_id = $1
             ORDER BY v.vehicle_number`,
            [companyId, today]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching vehicle status:', error);
        res.status(500).json({ error: 'Failed to fetch vehicle status' });
    }
};
