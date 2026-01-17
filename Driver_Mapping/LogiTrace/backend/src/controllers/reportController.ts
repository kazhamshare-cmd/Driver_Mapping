import { Request, Response } from 'express';
import { pool } from '../utils/db';
import PDFDocument from 'pdfkit';

// Get report summary for a date range
export const getReportSummary = async (req: Request, res: Response) => {
    try {
        const user = (req as any).user;
        const { startDate, endDate } = req.query;

        if (!startDate || !endDate) {
            return res.status(400).json({ error: 'startDate and endDate are required' });
        }

        // Get company ID from user
        const userResult = await pool.query('SELECT company_id FROM users WHERE id = $1', [user.userId]);
        const companyId = userResult.rows[0]?.company_id;

        if (!companyId) {
            return res.status(400).json({ error: 'Company not found' });
        }

        // Parallel queries for all metrics
        const [
            workRecordsResult,
            driversResult,
            vehiclesResult,
            tenkoResult,
            inspectionResult,
            accidentResult,
            violationResult
        ] = await Promise.all([
            // Work records summary
            pool.query(`
                SELECT
                    COUNT(DISTINCT work_date) as work_days,
                    COALESCE(SUM(distance), 0) as total_distance,
                    COUNT(DISTINCT driver_id) as active_drivers
                FROM work_records wr
                JOIN users u ON wr.driver_id = u.id
                WHERE u.company_id = $1
                AND wr.work_date BETWEEN $2 AND $3
            `, [companyId, startDate, endDate]),

            // Total drivers
            pool.query(`
                SELECT COUNT(*) as total
                FROM users
                WHERE company_id = $1 AND user_type = 'driver' AND status = 'active'
            `, [companyId]),

            // Total vehicles
            pool.query(`
                SELECT COUNT(*) as total
                FROM vehicles
                WHERE company_id = $1 AND status = 'active'
            `, [companyId]),

            // Tenko records
            pool.query(`
                SELECT
                    COUNT(*) as total,
                    COUNT(*) FILTER (WHERE alcohol_check_passed = true AND health_status != 'poor') as passed
                FROM tenko_records
                WHERE company_id = $1
                AND tenko_date BETWEEN $2 AND $3
            `, [companyId, startDate, endDate]),

            // Inspection records
            pool.query(`
                SELECT
                    COUNT(*) as total,
                    COUNT(*) FILTER (WHERE overall_result = 'pass') as passed
                FROM vehicle_inspection_records
                WHERE company_id = $1
                AND inspection_date BETWEEN $2 AND $3
            `, [companyId, startDate, endDate]),

            // Accidents
            pool.query(`
                SELECT COUNT(*) as total
                FROM accident_violation_records
                WHERE company_id = $1
                AND record_type = 'accident'
                AND incident_date BETWEEN $2 AND $3
            `, [companyId, startDate, endDate]),

            // Violations
            pool.query(`
                SELECT COUNT(*) as total
                FROM accident_violation_records
                WHERE company_id = $1
                AND record_type = 'violation'
                AND incident_date BETWEEN $2 AND $3
            `, [companyId, startDate, endDate])
        ]);

        const workDays = parseInt(workRecordsResult.rows[0]?.work_days || '0');
        const totalDistance = parseFloat(workRecordsResult.rows[0]?.total_distance || '0');
        const activeDrivers = parseInt(workRecordsResult.rows[0]?.active_drivers || '0');
        const totalDrivers = parseInt(driversResult.rows[0]?.total || '0');
        const totalVehicles = parseInt(vehiclesResult.rows[0]?.total || '0');
        const tenkoTotal = parseInt(tenkoResult.rows[0]?.total || '0');
        const tenkoPassed = parseInt(tenkoResult.rows[0]?.passed || '0');
        const inspectionTotal = parseInt(inspectionResult.rows[0]?.total || '0');
        const inspectionPassed = parseInt(inspectionResult.rows[0]?.passed || '0');
        const accidentCount = parseInt(accidentResult.rows[0]?.total || '0');
        const violationCount = parseInt(violationResult.rows[0]?.total || '0');

        res.json({
            period: `${startDate} ~ ${endDate}`,
            totalWorkDays: workDays,
            totalDistance: Math.round(totalDistance),
            totalDrivers: activeDrivers || totalDrivers,
            totalVehicles,
            tenkoCount: tenkoTotal,
            tenkoPassRate: tenkoTotal > 0 ? Math.round((tenkoPassed / tenkoTotal) * 100) : 100,
            inspectionCount: inspectionTotal,
            inspectionPassRate: inspectionTotal > 0 ? Math.round((inspectionPassed / inspectionTotal) * 100) : 100,
            accidentCount,
            violationCount,
            avgDistancePerDay: workDays > 0 ? totalDistance / workDays : 0,
            avgDistancePerDriver: activeDrivers > 0 ? totalDistance / activeDrivers : 0
        });
    } catch (error) {
        console.error('Error fetching report summary:', error);
        res.status(500).json({ error: 'Failed to fetch report summary' });
    }
};

// Get yearly report with monthly breakdown
export const getYearlyReport = async (req: Request, res: Response) => {
    try {
        const user = (req as any).user;
        const { year } = req.query;

        if (!year) {
            return res.status(400).json({ error: 'year is required' });
        }

        const yearInt = parseInt(year as string);
        const startDate = `${yearInt}-01-01`;
        const endDate = `${yearInt}-12-31`;

        // Get company ID
        const userResult = await pool.query('SELECT company_id FROM users WHERE id = $1', [user.userId]);
        const companyId = userResult.rows[0]?.company_id;

        if (!companyId) {
            return res.status(400).json({ error: 'Company not found' });
        }

        // Get yearly summary
        const [
            workRecordsResult,
            driversResult,
            tenkoResult,
            inspectionResult,
            accidentResult,
            violationResult
        ] = await Promise.all([
            pool.query(`
                SELECT
                    COUNT(DISTINCT work_date) as work_days,
                    COALESCE(SUM(distance), 0) as total_distance,
                    COUNT(DISTINCT driver_id) as active_drivers
                FROM work_records wr
                JOIN users u ON wr.driver_id = u.id
                WHERE u.company_id = $1
                AND wr.work_date BETWEEN $2 AND $3
            `, [companyId, startDate, endDate]),

            pool.query(`
                SELECT COUNT(*) as total
                FROM users
                WHERE company_id = $1 AND user_type = 'driver' AND status = 'active'
            `, [companyId]),

            pool.query(`
                SELECT
                    COUNT(*) as total,
                    COUNT(*) FILTER (WHERE alcohol_check_passed = true AND health_status != 'poor') as passed
                FROM tenko_records
                WHERE company_id = $1
                AND tenko_date BETWEEN $2 AND $3
            `, [companyId, startDate, endDate]),

            pool.query(`
                SELECT
                    COUNT(*) as total,
                    COUNT(*) FILTER (WHERE overall_result = 'pass') as passed
                FROM vehicle_inspection_records
                WHERE company_id = $1
                AND inspection_date BETWEEN $2 AND $3
            `, [companyId, startDate, endDate]),

            pool.query(`
                SELECT COUNT(*) as total
                FROM accident_violation_records
                WHERE company_id = $1 AND record_type = 'accident'
                AND incident_date BETWEEN $2 AND $3
            `, [companyId, startDate, endDate]),

            pool.query(`
                SELECT COUNT(*) as total
                FROM accident_violation_records
                WHERE company_id = $1 AND record_type = 'violation'
                AND incident_date BETWEEN $2 AND $3
            `, [companyId, startDate, endDate])
        ]);

        // Get monthly breakdown
        const monthlyResult = await pool.query(`
            SELECT
                EXTRACT(MONTH FROM work_date)::int as month,
                COUNT(DISTINCT work_date) as work_days,
                COALESCE(SUM(distance), 0) as distance
            FROM work_records wr
            JOIN users u ON wr.driver_id = u.id
            WHERE u.company_id = $1
            AND wr.work_date BETWEEN $2 AND $3
            GROUP BY EXTRACT(MONTH FROM work_date)
            ORDER BY month
        `, [companyId, startDate, endDate]);

        const monthlyTenkoResult = await pool.query(`
            SELECT
                EXTRACT(MONTH FROM tenko_date)::int as month,
                COUNT(*) as count
            FROM tenko_records
            WHERE company_id = $1
            AND tenko_date BETWEEN $2 AND $3
            GROUP BY EXTRACT(MONTH FROM tenko_date)
            ORDER BY month
        `, [companyId, startDate, endDate]);

        const monthlyInspectionResult = await pool.query(`
            SELECT
                EXTRACT(MONTH FROM inspection_date)::int as month,
                COUNT(*) as count
            FROM vehicle_inspection_records
            WHERE company_id = $1
            AND inspection_date BETWEEN $2 AND $3
            GROUP BY EXTRACT(MONTH FROM inspection_date)
            ORDER BY month
        `, [companyId, startDate, endDate]);

        const monthlyAccidentResult = await pool.query(`
            SELECT
                EXTRACT(MONTH FROM incident_date)::int as month,
                COUNT(*) as count
            FROM accident_violation_records
            WHERE company_id = $1 AND record_type = 'accident'
            AND incident_date BETWEEN $2 AND $3
            GROUP BY EXTRACT(MONTH FROM incident_date)
            ORDER BY month
        `, [companyId, startDate, endDate]);

        // Build monthly breakdown
        const monthlyData: { [key: number]: any } = {};
        for (let m = 1; m <= 12; m++) {
            monthlyData[m] = {
                month: `${m}月`,
                workDays: 0,
                distance: 0,
                tenkoCount: 0,
                inspectionCount: 0,
                accidents: 0
            };
        }

        monthlyResult.rows.forEach((row: any) => {
            monthlyData[row.month].workDays = parseInt(row.work_days);
            monthlyData[row.month].distance = Math.round(parseFloat(row.distance));
        });

        monthlyTenkoResult.rows.forEach((row: any) => {
            monthlyData[row.month].tenkoCount = parseInt(row.count);
        });

        monthlyInspectionResult.rows.forEach((row: any) => {
            monthlyData[row.month].inspectionCount = parseInt(row.count);
        });

        monthlyAccidentResult.rows.forEach((row: any) => {
            monthlyData[row.month].accidents = parseInt(row.count);
        });

        const workDays = parseInt(workRecordsResult.rows[0]?.work_days || '0');
        const totalDistance = parseFloat(workRecordsResult.rows[0]?.total_distance || '0');
        const activeDrivers = parseInt(workRecordsResult.rows[0]?.active_drivers || '0');
        const totalDrivers = parseInt(driversResult.rows[0]?.total || '0');
        const tenkoTotal = parseInt(tenkoResult.rows[0]?.total || '0');
        const tenkoPassed = parseInt(tenkoResult.rows[0]?.passed || '0');
        const inspectionTotal = parseInt(inspectionResult.rows[0]?.total || '0');
        const inspectionPassed = parseInt(inspectionResult.rows[0]?.passed || '0');
        const accidentCount = parseInt(accidentResult.rows[0]?.total || '0');
        const violationCount = parseInt(violationResult.rows[0]?.total || '0');

        res.json({
            summary: {
                period: `${yearInt}年`,
                totalWorkDays: workDays,
                totalDistance: Math.round(totalDistance),
                totalDrivers: activeDrivers || totalDrivers,
                totalVehicles: 0,
                tenkoCount: tenkoTotal,
                tenkoPassRate: tenkoTotal > 0 ? Math.round((tenkoPassed / tenkoTotal) * 100) : 100,
                inspectionCount: inspectionTotal,
                inspectionPassRate: inspectionTotal > 0 ? Math.round((inspectionPassed / inspectionTotal) * 100) : 100,
                accidentCount,
                violationCount,
                avgDistancePerDay: workDays > 0 ? totalDistance / workDays : 0,
                avgDistancePerDriver: activeDrivers > 0 ? totalDistance / activeDrivers : 0
            },
            monthlyBreakdown: Object.values(monthlyData)
        });
    } catch (error) {
        console.error('Error fetching yearly report:', error);
        res.status(500).json({ error: 'Failed to fetch yearly report' });
    }
};

// Generate PDF report
export const generateReportPDF = async (req: Request, res: Response) => {
    try {
        const user = (req as any).user;
        const { type, startDate, endDate, year } = req.query;

        // Get company info
        const userResult = await pool.query(`
            SELECT u.company_id, c.name as company_name
            FROM users u
            LEFT JOIN companies c ON u.company_id = c.id
            WHERE u.id = $1
        `, [user.userId]);
        const companyId = userResult.rows[0]?.company_id;
        const companyName = userResult.rows[0]?.company_name || 'Unknown Company';

        if (!companyId) {
            return res.status(400).json({ error: 'Company not found' });
        }

        let periodStart: string, periodEnd: string, reportTitle: string;

        if (type === 'monthly') {
            periodStart = startDate as string;
            periodEnd = endDate as string;
            const start = new Date(periodStart);
            reportTitle = `月次レポート（${start.getFullYear()}年${start.getMonth() + 1}月）`;
        } else if (type === 'yearly') {
            const yearInt = parseInt(year as string);
            periodStart = `${yearInt}-01-01`;
            periodEnd = `${yearInt}-12-31`;
            reportTitle = `年次レポート（${yearInt}年）`;
        } else {
            return res.status(400).json({ error: 'Invalid report type' });
        }

        // Fetch data
        const [workResult, tenkoResult, inspectionResult, accidentResult] = await Promise.all([
            pool.query(`
                SELECT
                    COUNT(DISTINCT work_date) as work_days,
                    COALESCE(SUM(distance), 0) as total_distance,
                    COUNT(DISTINCT driver_id) as active_drivers
                FROM work_records wr
                JOIN users u ON wr.driver_id = u.id
                WHERE u.company_id = $1 AND wr.work_date BETWEEN $2 AND $3
            `, [companyId, periodStart, periodEnd]),
            pool.query(`
                SELECT
                    COUNT(*) as total,
                    COUNT(*) FILTER (WHERE alcohol_check_passed = true) as passed
                FROM tenko_records
                WHERE company_id = $1 AND tenko_date BETWEEN $2 AND $3
            `, [companyId, periodStart, periodEnd]),
            pool.query(`
                SELECT
                    COUNT(*) as total,
                    COUNT(*) FILTER (WHERE overall_result = 'pass') as passed
                FROM vehicle_inspection_records
                WHERE company_id = $1 AND inspection_date BETWEEN $2 AND $3
            `, [companyId, periodStart, periodEnd]),
            pool.query(`
                SELECT
                    COUNT(*) FILTER (WHERE record_type = 'accident') as accidents,
                    COUNT(*) FILTER (WHERE record_type = 'violation') as violations
                FROM accident_violation_records
                WHERE company_id = $1 AND incident_date BETWEEN $2 AND $3
            `, [companyId, periodStart, periodEnd])
        ]);

        // Generate PDF
        const doc = new PDFDocument({ size: 'A4', margin: 50 });
        const chunks: Buffer[] = [];

        doc.on('data', (chunk) => chunks.push(chunk));
        doc.on('end', () => {
            const pdfBuffer = Buffer.concat(chunks);
            res.setHeader('Content-Type', 'application/pdf');
            res.setHeader('Content-Disposition', `attachment; filename="${reportTitle}.pdf"`);
            res.send(pdfBuffer);
        });

        // Title
        doc.fontSize(20).text(reportTitle, { align: 'center' });
        doc.moveDown();
        doc.fontSize(12).text(`事業者名: ${companyName}`, { align: 'center' });
        doc.fontSize(10).text(`期間: ${periodStart} ～ ${periodEnd}`, { align: 'center' });
        doc.moveDown(2);

        // Summary section
        doc.fontSize(14).text('■ 実績サマリー', { underline: true });
        doc.moveDown();
        doc.fontSize(11);

        const workDays = parseInt(workResult.rows[0]?.work_days || '0');
        const totalDistance = Math.round(parseFloat(workResult.rows[0]?.total_distance || '0'));
        const activeDrivers = parseInt(workResult.rows[0]?.active_drivers || '0');
        const tenkoTotal = parseInt(tenkoResult.rows[0]?.total || '0');
        const tenkoPassed = parseInt(tenkoResult.rows[0]?.passed || '0');
        const inspectionTotal = parseInt(inspectionResult.rows[0]?.total || '0');
        const inspectionPassed = parseInt(inspectionResult.rows[0]?.passed || '0');
        const accidents = parseInt(accidentResult.rows[0]?.accidents || '0');
        const violations = parseInt(accidentResult.rows[0]?.violations || '0');

        const summaryItems = [
            ['総稼働日数', `${workDays} 日`],
            ['総走行距離', `${totalDistance.toLocaleString()} km`],
            ['稼働ドライバー数', `${activeDrivers} 名`],
            ['1日あたり平均走行距離', `${workDays > 0 ? Math.round(totalDistance / workDays).toLocaleString() : 0} km`],
        ];

        summaryItems.forEach(([label, value]) => {
            doc.text(`${label}: ${value}`);
        });

        doc.moveDown(2);

        // Compliance section
        doc.fontSize(14).text('■ コンプライアンス実績', { underline: true });
        doc.moveDown();
        doc.fontSize(11);

        const tenkoRate = tenkoTotal > 0 ? Math.round((tenkoPassed / tenkoTotal) * 100) : 100;
        const inspectionRate = inspectionTotal > 0 ? Math.round((inspectionPassed / inspectionTotal) * 100) : 100;

        const complianceItems = [
            ['点呼実施件数', `${tenkoTotal} 件`],
            ['点呼合格率', `${tenkoRate}%`],
            ['日常点検実施件数', `${inspectionTotal} 件`],
            ['日常点検合格率', `${inspectionRate}%`],
            ['事故件数', `${accidents} 件`],
            ['違反件数', `${violations} 件`],
        ];

        complianceItems.forEach(([label, value]) => {
            doc.text(`${label}: ${value}`);
        });

        doc.moveDown(2);

        // Evaluation
        doc.fontSize(14).text('■ 総合評価', { underline: true });
        doc.moveDown();
        doc.fontSize(11);

        const issues: string[] = [];
        if (tenkoRate < 100) issues.push('点呼実施率が100%未満です');
        if (inspectionRate < 100) issues.push('日常点検合格率が100%未満です');
        if (accidents > 0) issues.push(`事故が${accidents}件発生しています`);
        if (violations > 0) issues.push(`違反が${violations}件発生しています`);

        if (issues.length === 0) {
            doc.text('良好: 全てのコンプライアンス基準を満たしています。');
        } else {
            doc.text('要改善項目:');
            issues.forEach((issue) => {
                doc.text(`  ・${issue}`);
            });
        }

        // Footer
        doc.fontSize(8).text(
            `出力日時: ${new Date().toLocaleString('ja-JP')}`,
            50,
            doc.page.height - 50,
            { align: 'right' }
        );

        doc.end();
    } catch (error) {
        console.error('Error generating report PDF:', error);
        res.status(500).json({ error: 'Failed to generate PDF' });
    }
};
