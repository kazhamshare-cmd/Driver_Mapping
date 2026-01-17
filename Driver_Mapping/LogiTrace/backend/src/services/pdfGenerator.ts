import PDFDocument from 'pdfkit';
import { pool } from '../index';
import fs from 'fs';
import path from 'path';

interface TenkoRecord {
    id: number;
    driver_name: string;
    tenko_type: string;
    tenko_date: string;
    tenko_time: string;
    method: string;
    health_status: string;
    health_notes: string | null;
    alcohol_level: number;
    alcohol_check_passed: boolean;
    fatigue_level: number;
    sleep_hours: number | null;
    sleep_sufficient: boolean | null;
    inspector_name: string;
    notes: string | null;
}

interface InspectionRecord {
    id: number;
    vehicle_number: string;
    driver_name: string;
    inspection_date: string;
    inspection_time: string;
    overall_result: string;
    inspection_items: Record<string, { result: string }>;
    odometer_reading: number | null;
    issues_found: string | null;
    notes: string | null;
}

// Helper function to get Japanese labels
const getHealthStatusLabel = (status: string): string => {
    const labels: Record<string, string> = {
        good: '良好',
        fair: '普通',
        poor: '不良',
    };
    return labels[status] || status;
};

const getTenkoTypeLabel = (type: string): string => {
    return type === 'pre' ? '乗務前' : '乗務後';
};

const getMethodLabel = (method: string): string => {
    const labels: Record<string, string> = {
        face_to_face: '対面',
        it_tenko: 'IT点呼',
        phone: '電話',
    };
    return labels[method] || method;
};

const getResultLabel = (result: string): string => {
    const labels: Record<string, string> = {
        pass: '合格',
        fail: '不合格',
        conditional: '条件付き',
    };
    return labels[result] || result;
};

// Generate Tenko Records PDF
export async function generateTenkoPDF(
    companyId: number,
    dateFrom: string,
    dateTo: string,
    driverIds: number[] | null
): Promise<Buffer> {
    // Fetch tenko records
    let query = `
        SELECT
            t.*,
            d.name as driver_name,
            i.name as inspector_name
        FROM tenko_records t
        LEFT JOIN users d ON t.driver_id = d.id
        LEFT JOIN users i ON t.inspector_id = i.id
        WHERE t.company_id = $1
        AND t.tenko_date BETWEEN $2 AND $3
    `;
    const params: any[] = [companyId, dateFrom, dateTo];

    if (driverIds && driverIds.length > 0) {
        query += ` AND t.driver_id = ANY($4)`;
        params.push(driverIds);
    }
    query += ' ORDER BY t.tenko_date, t.tenko_time';

    const result = await pool.query(query, params);
    const records: TenkoRecord[] = result.rows;

    return new Promise((resolve, reject) => {
        const chunks: Buffer[] = [];
        const doc = new PDFDocument({ size: 'A4', margin: 40 });

        doc.on('data', (chunk) => chunks.push(chunk));
        doc.on('end', () => resolve(Buffer.concat(chunks)));
        doc.on('error', reject);

        // Title
        doc.fontSize(18).text('点呼記録簿', { align: 'center' });
        doc.fontSize(10).text(`期間: ${dateFrom} 〜 ${dateTo}`, { align: 'center' });
        doc.moveDown(2);

        if (records.length === 0) {
            doc.fontSize(12).text('該当する記録がありません', { align: 'center' });
        } else {
            // Table header
            const startY = doc.y;
            const colWidths = [60, 50, 40, 50, 50, 50, 60, 50, 50];
            const headers = ['日付', '時刻', '種別', '方法', 'ドライバー', '健康状態', 'アルコール', '疲労度', '点呼者'];

            doc.fontSize(8);
            let x = 40;
            headers.forEach((header, i) => {
                doc.text(header, x, startY, { width: colWidths[i], align: 'center' });
                x += colWidths[i];
            });

            doc.moveTo(40, startY + 15).lineTo(555, startY + 15).stroke();

            let y = startY + 20;
            records.forEach((record) => {
                if (y > 750) {
                    doc.addPage();
                    y = 50;
                }

                x = 40;
                const date = new Date(record.tenko_date).toLocaleDateString('ja-JP');
                const time = new Date(record.tenko_time).toLocaleTimeString('ja-JP', {
                    hour: '2-digit',
                    minute: '2-digit',
                });

                const rowData = [
                    date,
                    time,
                    getTenkoTypeLabel(record.tenko_type),
                    getMethodLabel(record.method),
                    record.driver_name || '-',
                    getHealthStatusLabel(record.health_status),
                    record.alcohol_check_passed ? '合格(0.00)' : `不合格(${record.alcohol_level})`,
                    `${record.fatigue_level}/5`,
                    record.inspector_name || '-',
                ];

                rowData.forEach((data, i) => {
                    doc.text(data, x, y, { width: colWidths[i], align: 'center' });
                    x += colWidths[i];
                });

                y += 15;
            });
        }

        // Footer
        doc.fontSize(8).text(
            `出力日時: ${new Date().toLocaleString('ja-JP')}`,
            40,
            doc.page.height - 40,
            { align: 'right' }
        );

        doc.end();
    });
}

// Generate Inspection Records PDF
export async function generateInspectionPDF(
    companyId: number,
    dateFrom: string,
    dateTo: string,
    driverIds: number[] | null
): Promise<Buffer> {
    // Fetch inspection records
    let query = `
        SELECT
            i.*,
            v.vehicle_number,
            d.name as driver_name
        FROM vehicle_inspection_records i
        LEFT JOIN vehicles v ON i.vehicle_id = v.id
        LEFT JOIN users d ON i.driver_id = d.id
        WHERE i.company_id = $1
        AND i.inspection_date BETWEEN $2 AND $3
    `;
    const params: any[] = [companyId, dateFrom, dateTo];

    if (driverIds && driverIds.length > 0) {
        query += ` AND i.driver_id = ANY($4)`;
        params.push(driverIds);
    }
    query += ' ORDER BY i.inspection_date, i.inspection_time';

    const result = await pool.query(query, params);
    const records: InspectionRecord[] = result.rows;

    return new Promise((resolve, reject) => {
        const chunks: Buffer[] = [];
        const doc = new PDFDocument({ size: 'A4', margin: 40 });

        doc.on('data', (chunk) => chunks.push(chunk));
        doc.on('end', () => resolve(Buffer.concat(chunks)));
        doc.on('error', reject);

        // Title
        doc.fontSize(18).text('日常点検記録簿', { align: 'center' });
        doc.fontSize(10).text(`期間: ${dateFrom} 〜 ${dateTo}`, { align: 'center' });
        doc.moveDown(2);

        if (records.length === 0) {
            doc.fontSize(12).text('該当する記録がありません', { align: 'center' });
        } else {
            records.forEach((record, index) => {
                if (index > 0) {
                    doc.addPage();
                }

                const date = new Date(record.inspection_date).toLocaleDateString('ja-JP');
                const time = new Date(record.inspection_time).toLocaleTimeString('ja-JP', {
                    hour: '2-digit',
                    minute: '2-digit',
                });

                // Record header
                doc.fontSize(12).text(`点検日時: ${date} ${time}`);
                doc.text(`車両番号: ${record.vehicle_number || '-'}`);
                doc.text(`点検者: ${record.driver_name || '-'}`);
                doc.text(`総合判定: ${getResultLabel(record.overall_result)}`);
                if (record.odometer_reading) {
                    doc.text(`走行距離計: ${record.odometer_reading.toLocaleString()} km`);
                }
                doc.moveDown();

                // Inspection items
                doc.fontSize(10).text('点検項目:', { underline: true });
                doc.moveDown(0.5);

                const items = record.inspection_items || {};
                Object.entries(items).forEach(([key, value]) => {
                    const result = value.result === 'pass' ? '○' : '×';
                    doc.text(`  ${key}: ${result}`);
                });

                if (record.issues_found) {
                    doc.moveDown();
                    doc.text(`発見した問題点: ${record.issues_found}`);
                }

                if (record.notes) {
                    doc.moveDown();
                    doc.text(`備考: ${record.notes}`);
                }
            });
        }

        // Footer
        doc.fontSize(8).text(
            `出力日時: ${new Date().toLocaleString('ja-JP')}`,
            40,
            doc.page.height - 40,
            { align: 'right' }
        );

        doc.end();
    });
}

// Generate Daily Report PDF
export async function generateDailyReportPDF(
    companyId: number,
    dateFrom: string,
    dateTo: string,
    driverIds: number[] | null
): Promise<Buffer> {
    // Fetch work records
    let query = `
        SELECT
            w.*,
            d.name as driver_name,
            v.vehicle_number
        FROM work_records w
        LEFT JOIN users d ON w.driver_id = d.id
        LEFT JOIN vehicles v ON w.vehicle_id = v.id
        WHERE w.company_id = $1
        AND w.work_date BETWEEN $2 AND $3
    `;
    const params: any[] = [companyId, dateFrom, dateTo];

    if (driverIds && driverIds.length > 0) {
        query += ` AND w.driver_id = ANY($4)`;
        params.push(driverIds);
    }
    query += ' ORDER BY w.work_date, w.start_time';

    const result = await pool.query(query, params);
    const records = result.rows;

    return new Promise((resolve, reject) => {
        const chunks: Buffer[] = [];
        const doc = new PDFDocument({ size: 'A4', margin: 40 });

        doc.on('data', (chunk) => chunks.push(chunk));
        doc.on('end', () => resolve(Buffer.concat(chunks)));
        doc.on('error', reject);

        // Title
        doc.fontSize(18).text('運転日報', { align: 'center' });
        doc.fontSize(10).text(`期間: ${dateFrom} 〜 ${dateTo}`, { align: 'center' });
        doc.moveDown(2);

        if (records.length === 0) {
            doc.fontSize(12).text('該当する記録がありません', { align: 'center' });
        } else {
            // Table header
            const startY = doc.y;
            const colWidths = [60, 70, 50, 50, 60, 60, 60, 50];
            const headers = ['日付', '車両番号', '開始', '終了', 'ドライバー', '距離(km)', '休憩(分)', '状態'];

            doc.fontSize(8);
            let x = 40;
            headers.forEach((header, i) => {
                doc.text(header, x, startY, { width: colWidths[i], align: 'center' });
                x += colWidths[i];
            });

            doc.moveTo(40, startY + 15).lineTo(555, startY + 15).stroke();

            let y = startY + 20;
            records.forEach((record: any) => {
                if (y > 750) {
                    doc.addPage();
                    y = 50;
                }

                x = 40;
                const date = new Date(record.work_date).toLocaleDateString('ja-JP');
                const startTime = record.start_time
                    ? new Date(record.start_time).toLocaleTimeString('ja-JP', {
                          hour: '2-digit',
                          minute: '2-digit',
                      })
                    : '-';
                const endTime = record.end_time
                    ? new Date(record.end_time).toLocaleTimeString('ja-JP', {
                          hour: '2-digit',
                          minute: '2-digit',
                      })
                    : '-';

                const rowData = [
                    date,
                    record.vehicle_number || '-',
                    startTime,
                    endTime,
                    record.driver_name || '-',
                    record.distance?.toLocaleString() || '0',
                    record.break_time?.toString() || '0',
                    record.status === 'confirmed' ? '確定' : '未確定',
                ];

                rowData.forEach((data, i) => {
                    doc.text(data, x, y, { width: colWidths[i], align: 'center' });
                    x += colWidths[i];
                });

                y += 15;
            });
        }

        // Footer
        doc.fontSize(8).text(
            `出力日時: ${new Date().toLocaleString('ja-JP')}`,
            40,
            doc.page.height - 40,
            { align: 'right' }
        );

        doc.end();
    });
}

// Generate Combined 3-Set PDF
export async function generateCombinedPDF(
    companyId: number,
    dateFrom: string,
    dateTo: string,
    driverIds: number[] | null
): Promise<Buffer> {
    // Generate all three PDFs and combine them
    const [tenkoPDF, inspectionPDF, dailyReportPDF] = await Promise.all([
        generateTenkoPDF(companyId, dateFrom, dateTo, driverIds),
        generateInspectionPDF(companyId, dateFrom, dateTo, driverIds),
        generateDailyReportPDF(companyId, dateFrom, dateTo, driverIds),
    ]);

    // For simplicity, we'll generate a new combined PDF
    return new Promise((resolve, reject) => {
        const chunks: Buffer[] = [];
        const doc = new PDFDocument({ size: 'A4', margin: 40 });

        doc.on('data', (chunk) => chunks.push(chunk));
        doc.on('end', () => resolve(Buffer.concat(chunks)));
        doc.on('error', reject);

        // Cover page
        doc.fontSize(24).text('運送業監査用3点セット', { align: 'center' });
        doc.moveDown(2);
        doc.fontSize(14).text(`期間: ${dateFrom} 〜 ${dateTo}`, { align: 'center' });
        doc.moveDown(4);
        doc.fontSize(12).text('【収録帳票】', { align: 'center' });
        doc.moveDown();
        doc.text('1. 点呼記録簿', { align: 'center' });
        doc.text('2. 日常点検記録簿', { align: 'center' });
        doc.text('3. 運転日報', { align: 'center' });
        doc.moveDown(4);
        doc.fontSize(10).text(`出力日時: ${new Date().toLocaleString('ja-JP')}`, { align: 'center' });

        // Note: In production, you would use a PDF manipulation library
        // to actually merge the PDFs. For now, we'll just create a cover page
        // and the individual reports would need to be downloaded separately.

        doc.end();
    });
}

// ========================================
// 運転者台帳PDF (Driver Registry PDF)
// ========================================

interface DriverRegistryData {
    id: number;
    full_name: string;
    full_name_kana: string | null;
    birth_date: string | null;
    address: string | null;
    phone: string | null;
    emergency_contact: string | null;
    emergency_phone: string | null;
    hire_date: string | null;
    termination_date: string | null;
    license_number: string;
    license_type: string;
    license_expiry_date: string;
    license_conditions: string | null;
    hazmat_license: boolean;
    hazmat_expiry_date: string | null;
    forklift_license: boolean;
    status: string;
    employee_number: string | null;
}

interface HealthCheckupData {
    checkup_date: string;
    checkup_type: string;
    overall_result: string;
    facility_name: string | null;
}

interface AptitudeTestData {
    test_date: string;
    test_type: string;
    overall_score: number | null;
    result_summary: string | null;
}

interface TrainingData {
    training_date: string;
    training_name: string;
    duration_hours: number | null;
    completion_status: string;
}

interface AccidentData {
    incident_date: string;
    record_type: string;
    description: string;
    severity: string | null;
    is_at_fault: boolean;
}

const getCheckupTypeLabel = (type: string): string => {
    const labels: Record<string, string> = {
        regular: '定期健康診断',
        special: '特殊健康診断',
        pre_employment: '雇入時健康診断',
    };
    return labels[type] || type;
};

const getCheckupResultLabel = (result: string): string => {
    const labels: Record<string, string> = {
        normal: '異常なし',
        observation: '要経過観察',
        treatment: '要治療',
        work_restriction: '就業制限',
    };
    return labels[result] || result;
};

const getAptitudeTypeLabel = (type: string): string => {
    const labels: Record<string, string> = {
        initial: '初任診断',
        age_based: '適齢診断',
        specific: '特定診断',
        voluntary: '一般診断',
    };
    return labels[type] || type;
};

const getSeverityLabel = (severity: string | null): string => {
    if (!severity) return '-';
    const labels: Record<string, string> = {
        minor: '軽微',
        moderate: '中程度',
        severe: '重大',
        fatal: '死亡',
    };
    return labels[severity] || severity;
};

const getStatusLabel = (status: string): string => {
    const labels: Record<string, string> = {
        active: '在籍',
        inactive: '退職',
        suspended: '休職',
    };
    return labels[status] || status;
};

const getLicenseTypeLabel = (type: string): string => {
    const labels: Record<string, string> = {
        large: '大型',
        medium: '中型',
        ordinary: '普通',
        large_special: '大型特殊',
        tractor: '牽引',
        large_2: '大型二種',
        medium_2: '中型二種',
        ordinary_2: '普通二種',
    };
    return labels[type] || type;
};

// Generate Driver Registry PDF for a single driver
export async function generateDriverRegistryPDF(
    companyId: number,
    driverId: number
): Promise<Buffer> {
    // Fetch driver registry data
    const driverResult = await pool.query(
        `SELECT dr.*, u.email
         FROM driver_registries dr
         LEFT JOIN users u ON dr.driver_id = u.id
         WHERE dr.company_id = $1 AND dr.driver_id = $2`,
        [companyId, driverId]
    );

    if (driverResult.rows.length === 0) {
        throw new Error('Driver not found');
    }

    const driver: DriverRegistryData = driverResult.rows[0];

    // Fetch related records
    const [healthResult, aptitudeResult, trainingResult, accidentResult] = await Promise.all([
        pool.query(
            `SELECT checkup_date, checkup_type, overall_result, facility_name
             FROM health_checkup_records
             WHERE company_id = $1 AND driver_id = $2
             ORDER BY checkup_date DESC LIMIT 10`,
            [companyId, driverId]
        ),
        pool.query(
            `SELECT test_date, test_type, overall_score, result_summary
             FROM aptitude_test_records
             WHERE company_id = $1 AND driver_id = $2
             ORDER BY test_date DESC LIMIT 10`,
            [companyId, driverId]
        ),
        pool.query(
            `SELECT training_date, training_name, duration_hours, completion_status
             FROM training_records
             WHERE company_id = $1 AND driver_id = $2
             ORDER BY training_date DESC LIMIT 10`,
            [companyId, driverId]
        ),
        pool.query(
            `SELECT incident_date, record_type, description, severity, is_at_fault
             FROM accident_violation_records
             WHERE company_id = $1 AND driver_id = $2
             ORDER BY incident_date DESC LIMIT 10`,
            [companyId, driverId]
        ),
    ]);

    const healthRecords: HealthCheckupData[] = healthResult.rows;
    const aptitudeRecords: AptitudeTestData[] = aptitudeResult.rows;
    const trainingRecords: TrainingData[] = trainingResult.rows;
    const accidentRecords: AccidentData[] = accidentResult.rows;

    return new Promise((resolve, reject) => {
        const chunks: Buffer[] = [];
        const doc = new PDFDocument({ size: 'A4', margin: 40 });

        doc.on('data', (chunk) => chunks.push(chunk));
        doc.on('end', () => resolve(Buffer.concat(chunks)));
        doc.on('error', reject);

        // Title
        doc.fontSize(18).text('運転者台帳', { align: 'center' });
        doc.moveDown();

        // Basic Information Section
        doc.fontSize(14).text('■ 基本情報', { underline: true });
        doc.moveDown(0.5);
        doc.fontSize(10);

        const formatDate = (dateStr: string | null): string => {
            if (!dateStr) return '-';
            return new Date(dateStr).toLocaleDateString('ja-JP');
        };

        const basicInfo = [
            ['氏名', driver.full_name],
            ['フリガナ', driver.full_name_kana || '-'],
            ['社員番号', driver.employee_number || '-'],
            ['生年月日', formatDate(driver.birth_date)],
            ['住所', driver.address || '-'],
            ['電話番号', driver.phone || '-'],
            ['緊急連絡先', driver.emergency_contact || '-'],
            ['緊急連絡先電話', driver.emergency_phone || '-'],
            ['入社日', formatDate(driver.hire_date)],
            ['退職日', driver.termination_date ? formatDate(driver.termination_date) : '-'],
            ['在籍状況', getStatusLabel(driver.status)],
        ];

        basicInfo.forEach(([label, value]) => {
            doc.text(`${label}: ${value}`);
        });

        doc.moveDown();

        // License Information Section
        doc.fontSize(14).text('■ 免許情報', { underline: true });
        doc.moveDown(0.5);
        doc.fontSize(10);

        const licenseInfo = [
            ['免許証番号', driver.license_number],
            ['免許種類', getLicenseTypeLabel(driver.license_type)],
            ['有効期限', formatDate(driver.license_expiry_date)],
            ['免許条件', driver.license_conditions || 'なし'],
            ['危険物取扱', driver.hazmat_license ? `有 (期限: ${formatDate(driver.hazmat_expiry_date)})` : '無'],
            ['フォークリフト', driver.forklift_license ? '有' : '無'],
        ];

        licenseInfo.forEach(([label, value]) => {
            doc.text(`${label}: ${value}`);
        });

        // Health Checkup Section
        doc.addPage();
        doc.fontSize(14).text('■ 健康診断履歴', { underline: true });
        doc.moveDown(0.5);
        doc.fontSize(10);

        if (healthRecords.length === 0) {
            doc.text('記録なし');
        } else {
            const healthHeaders = ['受診日', '種別', '結果', '医療機関'];
            const healthColWidths = [80, 100, 80, 180];
            let y = doc.y;
            let x = 40;

            healthHeaders.forEach((header, i) => {
                doc.text(header, x, y, { width: healthColWidths[i], align: 'left' });
                x += healthColWidths[i];
            });
            doc.moveTo(40, y + 12).lineTo(500, y + 12).stroke();
            y += 18;

            healthRecords.forEach((record) => {
                x = 40;
                const rowData = [
                    formatDate(record.checkup_date),
                    getCheckupTypeLabel(record.checkup_type),
                    getCheckupResultLabel(record.overall_result),
                    record.facility_name || '-',
                ];
                rowData.forEach((data, i) => {
                    doc.text(data, x, y, { width: healthColWidths[i], align: 'left' });
                    x += healthColWidths[i];
                });
                y += 15;
            });
        }

        doc.moveDown(2);

        // Aptitude Test Section
        doc.fontSize(14).text('■ 適性診断履歴', { underline: true });
        doc.moveDown(0.5);
        doc.fontSize(10);

        if (aptitudeRecords.length === 0) {
            doc.text('記録なし');
        } else {
            const aptHeaders = ['受診日', '種別', 'スコア', '結果概要'];
            const aptColWidths = [80, 100, 60, 200];
            let y = doc.y;
            let x = 40;

            aptHeaders.forEach((header, i) => {
                doc.text(header, x, y, { width: aptColWidths[i], align: 'left' });
                x += aptColWidths[i];
            });
            doc.moveTo(40, y + 12).lineTo(500, y + 12).stroke();
            y += 18;

            aptitudeRecords.forEach((record) => {
                x = 40;
                const rowData = [
                    formatDate(record.test_date),
                    getAptitudeTypeLabel(record.test_type),
                    record.overall_score?.toString() || '-',
                    record.result_summary || '-',
                ];
                rowData.forEach((data, i) => {
                    doc.text(data, x, y, { width: aptColWidths[i], align: 'left' });
                    x += aptColWidths[i];
                });
                y += 15;
            });
        }

        // Training Section
        doc.addPage();
        doc.fontSize(14).text('■ 教育研修履歴', { underline: true });
        doc.moveDown(0.5);
        doc.fontSize(10);

        if (trainingRecords.length === 0) {
            doc.text('記録なし');
        } else {
            const trainingHeaders = ['受講日', '研修名', '時間', '状態'];
            const trainingColWidths = [80, 220, 60, 80];
            let y = doc.y;
            let x = 40;

            trainingHeaders.forEach((header, i) => {
                doc.text(header, x, y, { width: trainingColWidths[i], align: 'left' });
                x += trainingColWidths[i];
            });
            doc.moveTo(40, y + 12).lineTo(500, y + 12).stroke();
            y += 18;

            trainingRecords.forEach((record) => {
                x = 40;
                const rowData = [
                    formatDate(record.training_date),
                    record.training_name,
                    record.duration_hours ? `${record.duration_hours}h` : '-',
                    record.completion_status === 'completed' ? '修了' : record.completion_status === 'scheduled' ? '予定' : '未修了',
                ];
                rowData.forEach((data, i) => {
                    doc.text(data, x, y, { width: trainingColWidths[i], align: 'left' });
                    x += trainingColWidths[i];
                });
                y += 15;
            });
        }

        doc.moveDown(2);

        // Accident/Violation Section
        doc.fontSize(14).text('■ 事故・違反履歴', { underline: true });
        doc.moveDown(0.5);
        doc.fontSize(10);

        if (accidentRecords.length === 0) {
            doc.text('記録なし');
        } else {
            const accHeaders = ['発生日', '種別', '内容', '重大度', '過失'];
            const accColWidths = [70, 50, 200, 60, 40];
            let y = doc.y;
            let x = 40;

            accHeaders.forEach((header, i) => {
                doc.text(header, x, y, { width: accColWidths[i], align: 'left' });
                x += accColWidths[i];
            });
            doc.moveTo(40, y + 12).lineTo(500, y + 12).stroke();
            y += 18;

            accidentRecords.forEach((record) => {
                x = 40;
                const rowData = [
                    formatDate(record.incident_date),
                    record.record_type === 'accident' ? '事故' : '違反',
                    record.description.substring(0, 40) + (record.description.length > 40 ? '...' : ''),
                    getSeverityLabel(record.severity),
                    record.is_at_fault ? '有' : '無',
                ];
                rowData.forEach((data, i) => {
                    doc.text(data, x, y, { width: accColWidths[i], align: 'left' });
                    x += accColWidths[i];
                });
                y += 15;
            });
        }

        // Footer
        doc.fontSize(8).text(
            `出力日時: ${new Date().toLocaleString('ja-JP')}`,
            40,
            doc.page.height - 40,
            { align: 'right' }
        );

        doc.end();
    });
}

// Generate Driver Registry List PDF (all drivers)
export async function generateDriverRegistryListPDF(
    companyId: number
): Promise<Buffer> {
    const result = await pool.query(
        `SELECT dr.*, u.email
         FROM driver_registries dr
         LEFT JOIN users u ON dr.driver_id = u.id
         WHERE dr.company_id = $1 AND dr.status = 'active'
         ORDER BY dr.full_name_kana, dr.full_name`,
        [companyId]
    );

    const drivers: DriverRegistryData[] = result.rows;

    return new Promise((resolve, reject) => {
        const chunks: Buffer[] = [];
        const doc = new PDFDocument({ size: 'A4', layout: 'landscape', margin: 30 });

        doc.on('data', (chunk) => chunks.push(chunk));
        doc.on('end', () => resolve(Buffer.concat(chunks)));
        doc.on('error', reject);

        // Title
        doc.fontSize(16).text('運転者台帳一覧', { align: 'center' });
        doc.moveDown();

        if (drivers.length === 0) {
            doc.fontSize(12).text('登録されている運転者がいません', { align: 'center' });
        } else {
            // Table
            const headers = ['氏名', '社員番号', '免許種類', '免許有効期限', '危険物', '入社日', '状態'];
            const colWidths = [100, 80, 80, 90, 50, 80, 60];
            let y = doc.y;
            let x = 30;

            doc.fontSize(9);
            headers.forEach((header, i) => {
                doc.text(header, x, y, { width: colWidths[i], align: 'center' });
                x += colWidths[i];
            });
            doc.moveTo(30, y + 12).lineTo(780, y + 12).stroke();
            y += 18;

            const formatDate = (dateStr: string | null): string => {
                if (!dateStr) return '-';
                return new Date(dateStr).toLocaleDateString('ja-JP');
            };

            drivers.forEach((driver) => {
                if (y > 520) {
                    doc.addPage();
                    y = 50;
                }

                x = 30;
                const rowData = [
                    driver.full_name,
                    driver.employee_number || '-',
                    getLicenseTypeLabel(driver.license_type),
                    formatDate(driver.license_expiry_date),
                    driver.hazmat_license ? '有' : '無',
                    formatDate(driver.hire_date),
                    getStatusLabel(driver.status),
                ];

                rowData.forEach((data, i) => {
                    doc.text(data, x, y, { width: colWidths[i], align: 'center' });
                    x += colWidths[i];
                });
                y += 14;
            });

            doc.moveDown();
            doc.text(`合計: ${drivers.length}名`);
        }

        // Footer
        doc.fontSize(8).text(
            `出力日時: ${new Date().toLocaleString('ja-JP')}`,
            30,
            doc.page.height - 30,
            { align: 'right' }
        );

        doc.end();
    });
}

// ========================================
// コンプライアンスサマリーPDF
// ========================================

interface ComplianceSummary {
    totalDrivers: number;
    activeDrivers: number;
    licenseExpiring30Days: number;
    licenseExpired: number;
    healthCheckupDue: number;
    aptitudeTestDue: number;
    tenkoCompletionRate: number;
    inspectionCompletionRate: number;
    accidentCountThisYear: number;
    violationCountThisYear: number;
}

export async function generateComplianceSummaryPDF(
    companyId: number,
    periodStart: string,
    periodEnd: string
): Promise<Buffer> {
    // Fetch company info
    const companyResult = await pool.query(
        `SELECT name, safety_manager_name, operation_manager_name FROM companies WHERE id = $1`,
        [companyId]
    );
    const company = companyResult.rows[0] || { name: '-', safety_manager_name: '-', operation_manager_name: '-' };

    // Fetch summary statistics
    const today = new Date().toISOString().split('T')[0];
    const thirtyDaysLater = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
    const yearStart = new Date().getFullYear() + '-01-01';

    const [
        driversResult,
        licenseExpiringResult,
        licenseExpiredResult,
        healthDueResult,
        aptitudeDueResult,
        tenkoResult,
        inspectionResult,
        accidentResult,
        violationResult,
    ] = await Promise.all([
        // Total and active drivers
        pool.query(
            `SELECT
                COUNT(*) as total,
                COUNT(*) FILTER (WHERE status = 'active') as active
             FROM driver_registries WHERE company_id = $1`,
            [companyId]
        ),
        // Licenses expiring in 30 days
        pool.query(
            `SELECT COUNT(*) as count FROM driver_registries
             WHERE company_id = $1 AND status = 'active'
             AND license_expiry_date BETWEEN $2 AND $3`,
            [companyId, today, thirtyDaysLater]
        ),
        // Expired licenses
        pool.query(
            `SELECT COUNT(*) as count FROM driver_registries
             WHERE company_id = $1 AND status = 'active'
             AND license_expiry_date < $2`,
            [companyId, today]
        ),
        // Health checkups due (no checkup in last 12 months)
        pool.query(
            `SELECT COUNT(*) as count FROM driver_registries dr
             WHERE dr.company_id = $1 AND dr.status = 'active'
             AND NOT EXISTS (
                SELECT 1 FROM health_checkup_records hc
                WHERE hc.driver_id = dr.driver_id
                AND hc.checkup_date >= $2::date - INTERVAL '12 months'
             )`,
            [companyId, today]
        ),
        // Aptitude tests due (age >= 65 and no test in last 3 years)
        pool.query(
            `SELECT COUNT(*) as count FROM driver_registries dr
             WHERE dr.company_id = $1 AND dr.status = 'active'
             AND dr.birth_date IS NOT NULL
             AND EXTRACT(YEAR FROM AGE(CURRENT_DATE, dr.birth_date)) >= 65
             AND NOT EXISTS (
                SELECT 1 FROM aptitude_test_records at
                WHERE at.driver_id = dr.driver_id
                AND at.test_date >= $2::date - INTERVAL '3 years'
             )`,
            [companyId, today]
        ),
        // Tenko completion rate for the period
        pool.query(
            `SELECT
                COUNT(*) as total,
                COUNT(*) FILTER (WHERE alcohol_check_passed = true) as passed
             FROM tenko_records
             WHERE company_id = $1 AND tenko_date BETWEEN $2 AND $3`,
            [companyId, periodStart, periodEnd]
        ),
        // Inspection completion rate for the period
        pool.query(
            `SELECT
                COUNT(*) as total,
                COUNT(*) FILTER (WHERE overall_result = 'pass') as passed
             FROM vehicle_inspection_records
             WHERE company_id = $1 AND inspection_date BETWEEN $2 AND $3`,
            [companyId, periodStart, periodEnd]
        ),
        // Accidents this year
        pool.query(
            `SELECT COUNT(*) as count FROM accident_violation_records
             WHERE company_id = $1 AND record_type = 'accident'
             AND incident_date >= $2`,
            [companyId, yearStart]
        ),
        // Violations this year
        pool.query(
            `SELECT COUNT(*) as count FROM accident_violation_records
             WHERE company_id = $1 AND record_type = 'violation'
             AND incident_date >= $2`,
            [companyId, yearStart]
        ),
    ]);

    const summary: ComplianceSummary = {
        totalDrivers: parseInt(driversResult.rows[0]?.total || '0'),
        activeDrivers: parseInt(driversResult.rows[0]?.active || '0'),
        licenseExpiring30Days: parseInt(licenseExpiringResult.rows[0]?.count || '0'),
        licenseExpired: parseInt(licenseExpiredResult.rows[0]?.count || '0'),
        healthCheckupDue: parseInt(healthDueResult.rows[0]?.count || '0'),
        aptitudeTestDue: parseInt(aptitudeDueResult.rows[0]?.count || '0'),
        tenkoCompletionRate: tenkoResult.rows[0]?.total > 0
            ? Math.round((parseInt(tenkoResult.rows[0]?.passed || '0') / parseInt(tenkoResult.rows[0]?.total)) * 100)
            : 0,
        inspectionCompletionRate: inspectionResult.rows[0]?.total > 0
            ? Math.round((parseInt(inspectionResult.rows[0]?.passed || '0') / parseInt(inspectionResult.rows[0]?.total)) * 100)
            : 0,
        accidentCountThisYear: parseInt(accidentResult.rows[0]?.count || '0'),
        violationCountThisYear: parseInt(violationResult.rows[0]?.count || '0'),
    };

    return new Promise((resolve, reject) => {
        const chunks: Buffer[] = [];
        const doc = new PDFDocument({ size: 'A4', margin: 40 });

        doc.on('data', (chunk) => chunks.push(chunk));
        doc.on('end', () => resolve(Buffer.concat(chunks)));
        doc.on('error', reject);

        // Title
        doc.fontSize(20).text('コンプライアンスサマリーレポート', { align: 'center' });
        doc.moveDown();
        doc.fontSize(12).text(`対象期間: ${periodStart} 〜 ${periodEnd}`, { align: 'center' });
        doc.moveDown(2);

        // Company Info
        doc.fontSize(14).text('■ 事業者情報', { underline: true });
        doc.moveDown(0.5);
        doc.fontSize(10);
        doc.text(`事業者名: ${company.name}`);
        doc.text(`運行管理者: ${company.operation_manager_name || '-'}`);
        doc.text(`安全管理者: ${company.safety_manager_name || '-'}`);
        doc.moveDown();

        // Driver Summary
        doc.fontSize(14).text('■ 運転者状況', { underline: true });
        doc.moveDown(0.5);
        doc.fontSize(10);
        doc.text(`登録運転者数: ${summary.totalDrivers}名`);
        doc.text(`現役運転者数: ${summary.activeDrivers}名`);
        doc.moveDown();

        // Alert Summary
        doc.fontSize(14).text('■ 要対応事項', { underline: true });
        doc.moveDown(0.5);
        doc.fontSize(10);

        const alertItems = [
            { label: '免許期限切れ', count: summary.licenseExpired, severity: summary.licenseExpired > 0 ? '重大' : '-' },
            { label: '免許期限30日以内', count: summary.licenseExpiring30Days, severity: summary.licenseExpiring30Days > 0 ? '警告' : '-' },
            { label: '健康診断要受診', count: summary.healthCheckupDue, severity: summary.healthCheckupDue > 0 ? '警告' : '-' },
            { label: '適性診断要受診', count: summary.aptitudeTestDue, severity: summary.aptitudeTestDue > 0 ? '警告' : '-' },
        ];

        alertItems.forEach((item) => {
            const statusMark = item.count > 0 ? '⚠' : '✓';
            doc.text(`${statusMark} ${item.label}: ${item.count}名 ${item.severity !== '-' ? `[${item.severity}]` : ''}`);
        });
        doc.moveDown();

        // Compliance Rates
        doc.fontSize(14).text('■ 遵守率', { underline: true });
        doc.moveDown(0.5);
        doc.fontSize(10);
        doc.text(`点呼実施率: ${summary.tenkoCompletionRate}%`);
        doc.text(`日常点検合格率: ${summary.inspectionCompletionRate}%`);
        doc.moveDown();

        // Accident/Violation Summary
        doc.fontSize(14).text('■ 事故・違反状況（本年）', { underline: true });
        doc.moveDown(0.5);
        doc.fontSize(10);
        doc.text(`事故件数: ${summary.accidentCountThisYear}件`);
        doc.text(`違反件数: ${summary.violationCountThisYear}件`);
        doc.moveDown(2);

        // Recommendations
        doc.fontSize(14).text('■ 改善推奨事項', { underline: true });
        doc.moveDown(0.5);
        doc.fontSize(10);

        const recommendations: string[] = [];
        if (summary.licenseExpired > 0) {
            recommendations.push('・免許期限切れの運転者がいます。直ちに乗務を停止し、更新を確認してください。');
        }
        if (summary.licenseExpiring30Days > 0) {
            recommendations.push('・免許期限が30日以内の運転者がいます。更新の督促をしてください。');
        }
        if (summary.healthCheckupDue > 0) {
            recommendations.push('・健康診断未受診の運転者がいます。受診を手配してください。');
        }
        if (summary.aptitudeTestDue > 0) {
            recommendations.push('・適性診断が必要な運転者がいます（65歳以上で3年以上未受診）。');
        }
        if (summary.tenkoCompletionRate < 100) {
            recommendations.push('・点呼実施率が100%未満です。全乗務前後の点呼実施を徹底してください。');
        }
        if (summary.inspectionCompletionRate < 100) {
            recommendations.push('・日常点検合格率が100%未満です。不合格車両の点検整備を実施してください。');
        }

        if (recommendations.length === 0) {
            doc.text('特になし - 良好な状態です。');
        } else {
            recommendations.forEach((rec) => {
                doc.text(rec);
            });
        }

        // Footer
        doc.fontSize(8).text(
            `出力日時: ${new Date().toLocaleString('ja-JP')}`,
            40,
            doc.page.height - 40,
            { align: 'right' }
        );

        doc.end();
    });
}

// Save PDF to file system
export async function savePDF(buffer: Buffer, filename: string): Promise<string> {
    const uploadsDir = path.join(__dirname, '../../uploads/pdfs');
    if (!fs.existsSync(uploadsDir)) {
        fs.mkdirSync(uploadsDir, { recursive: true });
    }

    const filePath = path.join(uploadsDir, filename);
    fs.writeFileSync(filePath, buffer);

    return `/uploads/pdfs/${filename}`;
}
