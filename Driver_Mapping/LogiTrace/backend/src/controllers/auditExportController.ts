import { Request, Response } from 'express';
import { pool } from '../utils/db';
import * as pdfGenerator from '../services/pdfGenerator';
import path from 'path';
import fs from 'fs';

// PDF出力開始
export const createAuditExport = async (req: Request, res: Response) => {
    try {
        const {
            company_id,
            export_type,
            date_from,
            date_to,
            driver_ids,
            vehicle_ids
        } = req.body;
        const user = (req as any).user;

        // 出力レコード作成
        const result = await pool.query(
            `INSERT INTO audit_exports (
                company_id, export_type, date_from, date_to,
                driver_ids, vehicle_ids, status, generated_by, started_at
            ) VALUES ($1, $2, $3, $4, $5, $6, 'generating', $7, NOW())
            RETURNING id`,
            [company_id, export_type, date_from, date_to, driver_ids || null, vehicle_ids || null, user?.id || 1]
        );

        const exportId = result.rows[0].id;

        // 非同期でPDF生成を開始（実際の実装ではキュー処理が望ましい）
        generatePDFAsync(exportId, company_id, export_type, date_from, date_to, driver_ids, vehicle_ids)
            .catch(err => console.error('PDF generation error:', err));

        res.status(201).json({
            export_id: exportId,
            status: 'generating',
            message: 'PDF generation started. Check status endpoint for completion.'
        });
    } catch (error) {
        console.error('Error creating audit export:', error);
        res.status(500).json({ error: 'Failed to create audit export' });
    }
};

// 出力履歴取得
export const getExportHistory = async (req: Request, res: Response) => {
    try {
        const { companyId, limit = 50, offset = 0 } = req.query;

        const result = await pool.query(
            `SELECT ae.*, u.name as generated_by_name
             FROM audit_exports ae
             LEFT JOIN users u ON ae.generated_by = u.id
             WHERE ae.company_id = $1
             ORDER BY ae.created_at DESC
             LIMIT $2 OFFSET $3`,
            [companyId, limit, offset]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching export history:', error);
        res.status(500).json({ error: 'Failed to fetch export history' });
    }
};

// 出力詳細・ステータス取得
export const getExportById = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        const result = await pool.query(
            `SELECT ae.*, u.name as generated_by_name
             FROM audit_exports ae
             LEFT JOIN users u ON ae.generated_by = u.id
             WHERE ae.id = $1`,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Export record not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching export:', error);
        res.status(500).json({ error: 'Failed to fetch export' });
    }
};

// PDFダウンロード
export const downloadExport = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        const result = await pool.query(
            'SELECT pdf_url, status, export_type, date_from, date_to FROM audit_exports WHERE id = $1',
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Export record not found' });
        }

        const exportRecord = result.rows[0];

        if (exportRecord.status !== 'completed') {
            return res.status(400).json({ error: 'Export not yet completed', status: exportRecord.status });
        }

        if (!exportRecord.pdf_url) {
            return res.status(404).json({ error: 'PDF file not found' });
        }

        // Serve file from file system
        const filePath = path.join(__dirname, '../../', exportRecord.pdf_url);

        if (!fs.existsSync(filePath)) {
            return res.status(404).json({ error: 'PDF file not found on disk' });
        }

        const fileName = `監査帳票_${exportRecord.export_type}_${exportRecord.date_from}_${exportRecord.date_to}.pdf`;

        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `attachment; filename*=UTF-8''${encodeURIComponent(fileName)}`);

        const fileStream = fs.createReadStream(filePath);
        fileStream.pipe(res);
    } catch (error) {
        console.error('Error downloading export:', error);
        res.status(500).json({ error: 'Failed to download export' });
    }
};

// 出力削除
export const deleteExport = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        // TODO: 実際のPDFファイルも削除する

        const result = await pool.query(
            'DELETE FROM audit_exports WHERE id = $1 RETURNING id',
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Export record not found' });
        }

        res.json({ message: 'Export deleted successfully' });
    } catch (error) {
        console.error('Error deleting export:', error);
        res.status(500).json({ error: 'Failed to delete export' });
    }
};

// 監査データサマリー取得（プレビュー用）
export const getAuditSummary = async (req: Request, res: Response) => {
    try {
        const { companyId, dateFrom, dateTo, driverIds, vehicleIds } = req.query;

        // 対象期間のデータ件数を取得
        const driverFilter = driverIds ? `AND driver_id = ANY($4::int[])` : '';
        const vehicleFilter = vehicleIds ? `AND vehicle_id = ANY($5::int[])` : '';

        const [workRecords, tenkoRecords, inspectionRecords] = await Promise.all([
            pool.query(
                `SELECT COUNT(*) as count FROM work_records
                 WHERE driver_id IN (SELECT id FROM users WHERE company_id = $1)
                   AND work_date BETWEEN $2 AND $3 ${driverFilter}`,
                driverIds
                    ? [companyId, dateFrom, dateTo, driverIds]
                    : [companyId, dateFrom, dateTo]
            ),
            pool.query(
                `SELECT COUNT(*) as count FROM tenko_records
                 WHERE company_id = $1 AND tenko_date BETWEEN $2 AND $3 ${driverFilter}`,
                driverIds
                    ? [companyId, dateFrom, dateTo, driverIds]
                    : [companyId, dateFrom, dateTo]
            ),
            pool.query(
                `SELECT COUNT(*) as count FROM vehicle_inspection_records
                 WHERE company_id = $1 AND inspection_date BETWEEN $2 AND $3 ${vehicleFilter}`,
                vehicleIds
                    ? [companyId, dateFrom, dateTo, vehicleIds]
                    : [companyId, dateFrom, dateTo]
            )
        ]);

        res.json({
            date_from: dateFrom,
            date_to: dateTo,
            work_records_count: parseInt(workRecords.rows[0].count),
            tenko_records_count: parseInt(tenkoRecords.rows[0].count),
            inspection_records_count: parseInt(inspectionRecords.rows[0].count),
            estimated_pages: Math.ceil(
                (parseInt(workRecords.rows[0].count) +
                parseInt(tenkoRecords.rows[0].count) +
                parseInt(inspectionRecords.rows[0].count)) / 20
            )
        });
    } catch (error) {
        console.error('Error fetching audit summary:', error);
        res.status(500).json({ error: 'Failed to fetch audit summary' });
    }
};

// 非同期PDF生成関数
async function generatePDFAsync(
    exportId: number,
    companyId: number,
    exportType: string,
    dateFrom: string,
    dateTo: string,
    driverIds: number[] | null,
    vehicleIds: number[] | null
) {
    try {
        // PDF生成
        const pdfUrl = await generatePDF(exportId, companyId, exportType, dateFrom, dateTo, driverIds);

        // 完了ステータス更新
        await pool.query(
            `UPDATE audit_exports
             SET status = 'completed', pdf_url = $1, completed_at = NOW()
             WHERE id = $2`,
            [pdfUrl, exportId]
        );
    } catch (error: any) {
        console.error('PDF generation failed:', error);
        await pool.query(
            `UPDATE audit_exports
             SET status = 'failed', error_message = $1, completed_at = NOW()
             WHERE id = $2`,
            [error.message, exportId]
        );
    }
}

// 出力用データ取得
async function fetchExportData(
    companyId: number,
    exportType: string,
    dateFrom: string,
    dateTo: string,
    driverIds: number[] | null,
    vehicleIds: number[] | null
) {
    const data: any = { company: null, workRecords: [], tenkoRecords: [], inspectionRecords: [] };

    // 会社情報
    const companyResult = await pool.query(
        'SELECT * FROM companies WHERE id = $1',
        [companyId]
    );
    data.company = companyResult.rows[0];

    // ドライバーフィルター条件
    const driverFilter = driverIds ? 'AND driver_id = ANY($4::int[])' : '';

    if (exportType === 'three_point_set' || exportType === 'nippo_only') {
        // 日報（work_records）
        const workQuery = `
            SELECT wr.*, u.name as driver_name, v.vehicle_number
            FROM work_records wr
            LEFT JOIN users u ON wr.driver_id = u.id
            LEFT JOIN vehicles v ON wr.vehicle_id = v.id
            WHERE u.company_id = $1 AND wr.work_date BETWEEN $2 AND $3 ${driverFilter}
            ORDER BY wr.work_date, u.name
        `;
        const workResult = await pool.query(
            workQuery,
            driverIds ? [companyId, dateFrom, dateTo, driverIds] : [companyId, dateFrom, dateTo]
        );
        data.workRecords = workResult.rows;
    }

    if (exportType === 'three_point_set' || exportType === 'tenko_only') {
        // 点呼記録
        const tenkoQuery = `
            SELECT * FROM tenko_records
            WHERE company_id = $1 AND tenko_date BETWEEN $2 AND $3 ${driverFilter}
            ORDER BY tenko_date, driver_name
        `;
        const tenkoResult = await pool.query(
            tenkoQuery,
            driverIds ? [companyId, dateFrom, dateTo, driverIds] : [companyId, dateFrom, dateTo]
        );
        data.tenkoRecords = tenkoResult.rows;
    }

    if (exportType === 'three_point_set' || exportType === 'tenken_only') {
        // 点検記録
        const vehicleFilter = vehicleIds ? 'AND vehicle_id = ANY($4::int[])' : '';
        const inspectionQuery = `
            SELECT ir.*, v.vehicle_number, u.name as driver_name
            FROM vehicle_inspection_records ir
            LEFT JOIN vehicles v ON ir.vehicle_id = v.id
            LEFT JOIN users u ON ir.driver_id = u.id
            WHERE ir.company_id = $1 AND ir.inspection_date BETWEEN $2 AND $3 ${vehicleFilter}
            ORDER BY ir.inspection_date, v.vehicle_number
        `;
        const inspectionResult = await pool.query(
            inspectionQuery,
            vehicleIds ? [companyId, dateFrom, dateTo, vehicleIds] : [companyId, dateFrom, dateTo]
        );
        data.inspectionRecords = inspectionResult.rows;
    }

    // ページ数推定
    data.pageCount = Math.ceil(
        (data.workRecords.length + data.tenkoRecords.length + data.inspectionRecords.length) / 20
    ) || 1;

    return data;
}

// PDF生成
async function generatePDF(
    exportId: number,
    companyId: number,
    exportType: string,
    dateFrom: string,
    dateTo: string,
    driverIds: number[] | null
): Promise<string> {
    const timestamp = Date.now();
    const fileName = `audit_${exportType}_${exportId}_${timestamp}.pdf`;

    let pdfBuffer: Buffer;

    switch (exportType) {
        case 'tenko':
            pdfBuffer = await pdfGenerator.generateTenkoPDF(companyId, dateFrom, dateTo, driverIds);
            break;
        case 'inspection':
            pdfBuffer = await pdfGenerator.generateInspectionPDF(companyId, dateFrom, dateTo, driverIds);
            break;
        case 'daily_report':
            pdfBuffer = await pdfGenerator.generateDailyReportPDF(companyId, dateFrom, dateTo, driverIds);
            break;
        case 'driver_registry_list':
            pdfBuffer = await pdfGenerator.generateDriverRegistryListPDF(companyId);
            break;
        case 'compliance_summary':
            pdfBuffer = await pdfGenerator.generateComplianceSummaryPDF(companyId, dateFrom, dateTo);
            break;
        case 'all':
        default:
            pdfBuffer = await pdfGenerator.generateCombinedPDF(companyId, dateFrom, dateTo, driverIds);
            break;
    }

    // Save to file system
    const pdfUrl = await pdfGenerator.savePDF(pdfBuffer, fileName);
    return pdfUrl;
}

// 運転者台帳PDF直接ダウンロード（個人）
export const downloadDriverRegistryPDF = async (req: Request, res: Response) => {
    try {
        const { driverId } = req.params;
        const { companyId } = req.query;

        if (!companyId || !driverId) {
            return res.status(400).json({ error: 'companyId and driverId are required' });
        }

        const pdfBuffer = await pdfGenerator.generateDriverRegistryPDF(
            parseInt(companyId as string),
            parseInt(driverId)
        );

        const fileName = `運転者台帳_${driverId}_${Date.now()}.pdf`;

        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `attachment; filename*=UTF-8''${encodeURIComponent(fileName)}`);
        res.send(pdfBuffer);
    } catch (error: any) {
        console.error('Error generating driver registry PDF:', error);
        if (error.message === 'Driver not found') {
            return res.status(404).json({ error: 'Driver not found' });
        }
        res.status(500).json({ error: 'Failed to generate driver registry PDF' });
    }
};

// 運転者台帳一覧PDF直接ダウンロード
export const downloadDriverRegistryListPDF = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.query;

        if (!companyId) {
            return res.status(400).json({ error: 'companyId is required' });
        }

        const pdfBuffer = await pdfGenerator.generateDriverRegistryListPDF(
            parseInt(companyId as string)
        );

        const fileName = `運転者台帳一覧_${Date.now()}.pdf`;

        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `attachment; filename*=UTF-8''${encodeURIComponent(fileName)}`);
        res.send(pdfBuffer);
    } catch (error) {
        console.error('Error generating driver registry list PDF:', error);
        res.status(500).json({ error: 'Failed to generate driver registry list PDF' });
    }
};

// コンプライアンスサマリーPDF直接ダウンロード
export const downloadComplianceSummaryPDF = async (req: Request, res: Response) => {
    try {
        const { companyId, dateFrom, dateTo } = req.query;

        if (!companyId || !dateFrom || !dateTo) {
            return res.status(400).json({ error: 'companyId, dateFrom, and dateTo are required' });
        }

        const pdfBuffer = await pdfGenerator.generateComplianceSummaryPDF(
            parseInt(companyId as string),
            dateFrom as string,
            dateTo as string
        );

        const fileName = `コンプライアンスサマリー_${dateFrom}_${dateTo}.pdf`;

        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `attachment; filename*=UTF-8''${encodeURIComponent(fileName)}`);
        res.send(pdfBuffer);
    } catch (error) {
        console.error('Error generating compliance summary PDF:', error);
        res.status(500).json({ error: 'Failed to generate compliance summary PDF' });
    }
};
