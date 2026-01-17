import { Request, Response } from 'express';
import { pool } from '../utils/db';

// 対応フォーマット一覧
const SUPPORTED_FORMATS = [
    { id: 'yazaki', name: '矢崎 (Yazaki)', description: 'DTG/DTS形式' },
    { id: 'denso', name: 'デンソー (Denso)', description: 'クラウド/ローカルCSV形式' },
    { id: 'manual', name: '手動入力', description: 'アナタコ・その他' }
];

// 対応フォーマット取得
export const getSupportedFormats = async (req: Request, res: Response) => {
    res.json(SUPPORTED_FORMATS);
};

// CSVアップロード・インポート
export const uploadTachographData = async (req: Request, res: Response) => {
    try {
        const { company_id, file_type, driver_mapping, records } = req.body;
        const user = (req as any).user;

        // インポートレコード作成
        const importResult = await pool.query(
            `INSERT INTO tachograph_imports (company_id, file_name, file_type, status, uploaded_by, started_at)
             VALUES ($1, $2, $3, 'processing', $4, NOW())
             RETURNING id`,
            [company_id, req.body.file_name || 'manual_import.csv', file_type, user?.id || 1]
        );
        const importId = importResult.rows[0].id;

        let recordsImported = 0;
        let recordsFailed = 0;
        const errors: { row: number; error: string }[] = [];
        const createdRecordIds: number[] = [];

        // レコードをwork_recordsに変換して保存
        for (let i = 0; i < records.length; i++) {
            const record = records[i];
            try {
                // ドライバーIDのマッピング（デバイスIDからシステムユーザーIDへ）
                let driverId = record.driver_id;
                if (driver_mapping && driver_mapping[record.device_driver_id]) {
                    driverId = driver_mapping[record.device_driver_id];
                }

                // work_recordを作成
                const workRecordResult = await pool.query(
                    `INSERT INTO work_records (
                        driver_id, vehicle_id, work_date, start_time, end_time,
                        record_method, distance, status
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'confirmed')
                    RETURNING id`,
                    [
                        driverId,
                        record.vehicle_id || null,
                        record.work_date,
                        record.start_time,
                        record.end_time,
                        'manual', // デジタコからのインポートも記録上は手動扱い
                        record.distance || 0
                    ]
                );

                createdRecordIds.push(workRecordResult.rows[0].id);
                recordsImported++;
            } catch (err: any) {
                recordsFailed++;
                errors.push({ row: i + 1, error: err.message });
            }
        }

        // インポート結果を更新
        await pool.query(
            `UPDATE tachograph_imports
             SET status = $1, records_imported = $2, records_failed = $3,
                 error_log = $4, completed_at = NOW()
             WHERE id = $5`,
            [
                recordsFailed === records.length ? 'failed' : 'completed',
                recordsImported,
                recordsFailed,
                JSON.stringify(errors),
                importId
            ]
        );

        res.status(201).json({
            import_id: importId,
            status: recordsFailed === records.length ? 'failed' : (recordsFailed > 0 ? 'partial' : 'completed'),
            records_imported: recordsImported,
            records_failed: recordsFailed,
            work_records_created: createdRecordIds,
            errors
        });
    } catch (error) {
        console.error('Error uploading tachograph data:', error);
        res.status(500).json({ error: 'Failed to upload tachograph data' });
    }
};

// CSVプレビュー（保存せずにパース結果を返す）
export const previewTachographData = async (req: Request, res: Response) => {
    try {
        const { file_type, csv_content, driver_mapping } = req.body;

        // CSVをパースしてプレビュー用データを返す
        const records = parseCSV(file_type, csv_content);

        // ドライバーマッピングを適用
        const mappedRecords = records.map(record => {
            const mappedDriverId = driver_mapping?.[record.device_driver_id];
            return {
                ...record,
                system_driver_id: mappedDriverId || null,
                mapping_status: mappedDriverId ? 'mapped' : 'unmapped'
            };
        });

        res.json({
            total_records: records.length,
            records: mappedRecords,
            unmapped_drivers: [...new Set(mappedRecords.filter(r => !r.system_driver_id).map(r => r.device_driver_id))]
        });
    } catch (error) {
        console.error('Error previewing tachograph data:', error);
        res.status(500).json({ error: 'Failed to preview tachograph data' });
    }
};

// インポート履歴取得
export const getImportHistory = async (req: Request, res: Response) => {
    try {
        const { companyId, limit = 50, offset = 0 } = req.query;

        const result = await pool.query(
            `SELECT ti.*, u.name as uploaded_by_name
             FROM tachograph_imports ti
             LEFT JOIN users u ON ti.uploaded_by = u.id
             WHERE ti.company_id = $1
             ORDER BY ti.created_at DESC
             LIMIT $2 OFFSET $3`,
            [companyId, limit, offset]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching import history:', error);
        res.status(500).json({ error: 'Failed to fetch import history' });
    }
};

// インポート詳細取得
export const getImportById = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        const result = await pool.query(
            `SELECT ti.*, u.name as uploaded_by_name
             FROM tachograph_imports ti
             LEFT JOIN users u ON ti.uploaded_by = u.id
             WHERE ti.id = $1`,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Import record not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching import:', error);
        res.status(500).json({ error: 'Failed to fetch import' });
    }
};

// CSVパーサー（フォーマット別）
function parseCSV(fileType: string, csvContent: string): any[] {
    const lines = csvContent.split('\n').filter(line => line.trim());
    if (lines.length < 2) return []; // ヘッダー + 1行以上必要

    switch (fileType) {
        case 'yazaki':
            return parseYazakiCSV(lines);
        case 'denso':
            return parseDensoCSV(lines);
        default:
            return parseGenericCSV(lines);
    }
}

// 矢崎フォーマットパーサー
function parseYazakiCSV(lines: string[]): any[] {
    const records: any[] = [];
    // ヘッダー行をスキップ
    for (let i = 1; i < lines.length; i++) {
        const cols = lines[i].split(',').map(c => c.trim());
        if (cols.length < 4) continue;

        records.push({
            work_date: cols[0], // 日付
            device_driver_id: cols[2], // 運転者ID
            start_time: `${cols[0]} ${cols[1]}`, // 開始時刻
            end_time: null, // 終了時刻は別行にある可能性
            distance: parseFloat(cols[4]) || 0, // 走行距離
            raw: cols
        });
    }
    return records;
}

// デンソーフォーマットパーサー
function parseDensoCSV(lines: string[]): any[] {
    const records: any[] = [];
    for (let i = 1; i < lines.length; i++) {
        const cols = lines[i].split(',').map(c => c.trim());
        if (cols.length < 4) continue;

        // DENSOフォーマット: DATE,TIME,DRIVER_CODE,EVENT,ODO,SPEED
        const date = cols[0]; // YYYYMMDD
        const formattedDate = `${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6, 8)}`;

        records.push({
            work_date: formattedDate,
            device_driver_id: cols[2],
            start_time: `${formattedDate} ${formatDensoTime(cols[1])}`,
            end_time: null,
            distance: 0, // ODOから計算が必要
            event: cols[3],
            raw: cols
        });
    }
    return records;
}

// 汎用CSVパーサー
function parseGenericCSV(lines: string[]): any[] {
    const records: any[] = [];
    const headers = lines[0].split(',').map(h => h.trim().toLowerCase());

    for (let i = 1; i < lines.length; i++) {
        const cols = lines[i].split(',').map(c => c.trim());
        const record: any = { raw: cols };

        headers.forEach((header, idx) => {
            if (cols[idx]) {
                record[header] = cols[idx];
            }
        });

        records.push(record);
    }
    return records;
}

// デンソー時刻フォーマット変換 (HHMMSS -> HH:MM:SS)
function formatDensoTime(time: string): string {
    if (time.length !== 6) return time;
    return `${time.substring(0, 2)}:${time.substring(2, 4)}:${time.substring(4, 6)}`;
}
