import { Request, Response } from 'express';
import { pool } from '../utils/db';
import {
    parseTachographData,
    validateParsedRecords,
    TachographType
} from '../services/tachographParserService';

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

// CSVファイルアップロードとパース
export const parseUploadedFile = async (req: Request, res: Response) => {
    try {
        const { csv_content, file_type = 'auto' } = req.body;

        if (!csv_content) {
            return res.status(400).json({ error: 'CSVコンテンツが必要です' });
        }

        // パース実行
        const records = parseTachographData(csv_content, file_type as TachographType);
        const { valid, invalid } = validateParsedRecords(records);

        res.json({
            total_records: records.length,
            valid_records: valid.length,
            invalid_records: invalid.length,
            records: valid,
            errors: invalid.map(i => ({ reason: i.reason, record: i.record }))
        });
    } catch (error) {
        console.error('Error parsing tachograph file:', error);
        res.status(500).json({ error: 'ファイルのパースに失敗しました' });
    }
};

// デジタコデータをインポートしてtachograph_dataテーブルに保存
export const importTachographData = async (req: Request, res: Response) => {
    const client = await pool.connect();
    try {
        const { csv_content, file_type = 'auto', file_name = 'import.csv' } = req.body;
        const companyId = (req as any).user?.companyId;
        const userId = (req as any).user?.id;

        if (!csv_content) {
            return res.status(400).json({ error: 'CSVコンテンツが必要です' });
        }

        await client.query('BEGIN');

        // パース実行
        const records = parseTachographData(csv_content, file_type as TachographType);
        const { valid, invalid } = validateParsedRecords(records);

        // インポート履歴を作成
        const importResult = await client.query(
            `INSERT INTO tachograph_imports
            (company_id, file_name, file_type, import_date, records_count, uploaded_by, status)
            VALUES ($1, $2, $3, CURRENT_DATE, $4, $5, 'processing')
            RETURNING id`,
            [companyId, file_name, file_type, valid.length, userId]
        );
        const importId = importResult.rows[0].id;

        let insertedCount = 0;

        // 有効なレコードをtachograph_dataに保存
        for (const record of valid) {
            await client.query(
                `INSERT INTO tachograph_data
                (import_id, driver_code, vehicle_number, record_date, start_time, end_time,
                distance, max_speed, avg_speed, idle_time_minutes, driving_time_minutes,
                rest_time_minutes, harsh_braking_count, harsh_acceleration_count,
                speeding_count, raw_data, match_status)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, 'unmatched')`,
                [
                    importId,
                    record.driver_code,
                    record.vehicle_number,
                    record.record_date,
                    record.start_time,
                    record.end_time,
                    record.distance,
                    record.max_speed,
                    record.avg_speed,
                    record.idle_time_minutes,
                    record.driving_time_minutes,
                    record.rest_time_minutes,
                    record.harsh_braking_count,
                    record.harsh_acceleration_count,
                    record.speeding_count,
                    JSON.stringify(record.raw_data)
                ]
            );
            insertedCount++;
        }

        // インポート履歴を更新
        await client.query(
            `UPDATE tachograph_imports
            SET status = 'completed', records_count = $1
            WHERE id = $2`,
            [insertedCount, importId]
        );

        await client.query('COMMIT');

        res.json({
            success: true,
            import_id: importId,
            imported_count: insertedCount,
            invalid_count: invalid.length,
            errors: invalid.slice(0, 10) // 最初の10件のエラーのみ返す
        });
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Error importing tachograph data:', error);
        res.status(500).json({ error: 'インポートに失敗しました' });
    } finally {
        client.release();
    }
};

// 自動マッチング実行（デジタコデータと運行記録）
export const autoMatchTachographData = async (req: Request, res: Response) => {
    const client = await pool.connect();
    try {
        const { import_id } = req.params;
        const companyId = (req as any).user?.companyId;

        await client.query('BEGIN');

        // 未マッチのデジタコデータを取得
        const unmatchedResult = await client.query(
            `SELECT td.* FROM tachograph_data td
            JOIN tachograph_imports ti ON td.import_id = ti.id
            WHERE ti.company_id = $1 AND td.match_status = 'unmatched'
            ${import_id ? 'AND ti.id = $2' : ''}`,
            import_id ? [companyId, import_id] : [companyId]
        );

        let matchedCount = 0;
        let conflictCount = 0;

        for (const tacho of unmatchedResult.rows) {
            // ドライバーコードまたは車両番号で運行記録を検索
            const matchQuery = await client.query(
                `SELECT wr.id, wr.driver_id, wr.distance, wr.start_time, wr.end_time
                FROM work_records wr
                JOIN users u ON wr.driver_id = u.id
                LEFT JOIN vehicles v ON wr.vehicle_id = v.id
                WHERE u.company_id = $1
                AND wr.work_date = $2
                AND (
                    u.employee_number = $3
                    OR u.employee_number LIKE $4
                    OR v.vehicle_number = $5
                )`,
                [
                    companyId,
                    tacho.record_date,
                    tacho.driver_code,
                    `%${tacho.driver_code}%`,
                    tacho.vehicle_number
                ]
            );

            if (matchQuery.rows.length === 1) {
                // 一致する運行記録が1件見つかった
                const workRecord = matchQuery.rows[0];

                // マッチ状態を更新
                await client.query(
                    `UPDATE tachograph_data
                    SET work_record_id = $1, match_status = 'matched'
                    WHERE id = $2`,
                    [workRecord.id, tacho.id]
                );

                // 運行記録にデジタコデータを反映（auto_distanceとして保存）
                await client.query(
                    `UPDATE work_records
                    SET auto_distance = $1
                    WHERE id = $2 AND auto_distance IS NULL`,
                    [tacho.distance, workRecord.id]
                );

                matchedCount++;
            } else if (matchQuery.rows.length > 1) {
                // 複数の候補がある（コンフリクト）
                await client.query(
                    `UPDATE tachograph_data
                    SET match_status = 'conflict'
                    WHERE id = $1`,
                    [tacho.id]
                );
                conflictCount++;
            }
        }

        // インポート履歴を更新
        if (import_id) {
            await client.query(
                `UPDATE tachograph_imports
                SET matched_count = matched_count + $1
                WHERE id = $2`,
                [matchedCount, import_id]
            );
        }

        await client.query('COMMIT');

        res.json({
            success: true,
            processed: unmatchedResult.rows.length,
            matched: matchedCount,
            conflicts: conflictCount,
            unmatched: unmatchedResult.rows.length - matchedCount - conflictCount
        });
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Error auto-matching tachograph data:', error);
        res.status(500).json({ error: '自動マッチングに失敗しました' });
    } finally {
        client.release();
    }
};

// 手動マッチング
export const manualMatchTachographData = async (req: Request, res: Response) => {
    try {
        const { tachograph_data_id, work_record_id } = req.body;

        if (!tachograph_data_id || !work_record_id) {
            return res.status(400).json({ error: 'デジタコデータIDと運行記録IDが必要です' });
        }

        // デジタコデータを取得
        const tachoResult = await pool.query(
            `SELECT * FROM tachograph_data WHERE id = $1`,
            [tachograph_data_id]
        );

        if (tachoResult.rows.length === 0) {
            return res.status(404).json({ error: 'デジタコデータが見つかりません' });
        }

        const tacho = tachoResult.rows[0];

        // マッチ状態を更新
        await pool.query(
            `UPDATE tachograph_data
            SET work_record_id = $1, match_status = 'matched'
            WHERE id = $2`,
            [work_record_id, tachograph_data_id]
        );

        // 運行記録にデジタコデータを反映
        await pool.query(
            `UPDATE work_records
            SET auto_distance = $1
            WHERE id = $2`,
            [tacho.distance, work_record_id]
        );

        res.json({
            success: true,
            message: 'マッチングが完了しました'
        });
    } catch (error) {
        console.error('Error manual matching:', error);
        res.status(500).json({ error: '手動マッチングに失敗しました' });
    }
};

// 未マッチデータ一覧取得
export const getUnmatchedData = async (req: Request, res: Response) => {
    try {
        const companyId = (req as any).user?.companyId;
        const { import_id, limit = 50, offset = 0 } = req.query;

        const result = await pool.query(
            `SELECT td.*, ti.file_name, ti.file_type
            FROM tachograph_data td
            JOIN tachograph_imports ti ON td.import_id = ti.id
            WHERE ti.company_id = $1
            AND td.match_status IN ('unmatched', 'conflict')
            ${import_id ? 'AND ti.id = $2' : ''}
            ORDER BY td.record_date DESC, td.id
            LIMIT $${import_id ? 3 : 2} OFFSET $${import_id ? 4 : 3}`,
            import_id
                ? [companyId, import_id, limit, offset]
                : [companyId, limit, offset]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching unmatched data:', error);
        res.status(500).json({ error: '未マッチデータの取得に失敗しました' });
    }
};

// マッチ候補の運行記録を取得
export const getMatchCandidates = async (req: Request, res: Response) => {
    try {
        const { tachograph_data_id } = req.params;
        const companyId = (req as any).user?.companyId;

        // デジタコデータを取得
        const tachoResult = await pool.query(
            `SELECT * FROM tachograph_data WHERE id = $1`,
            [tachograph_data_id]
        );

        if (tachoResult.rows.length === 0) {
            return res.status(404).json({ error: 'デジタコデータが見つかりません' });
        }

        const tacho = tachoResult.rows[0];

        // 同日の運行記録を候補として取得
        const candidates = await pool.query(
            `SELECT wr.*, u.name as driver_name, u.employee_number, v.vehicle_number
            FROM work_records wr
            JOIN users u ON wr.driver_id = u.id
            LEFT JOIN vehicles v ON wr.vehicle_id = v.id
            WHERE u.company_id = $1
            AND wr.work_date = $2
            AND NOT EXISTS (
                SELECT 1 FROM tachograph_data td
                WHERE td.work_record_id = wr.id AND td.match_status = 'matched'
            )
            ORDER BY
                CASE WHEN u.employee_number = $3 THEN 0 ELSE 1 END,
                CASE WHEN v.vehicle_number = $4 THEN 0 ELSE 1 END,
                wr.start_time`,
            [companyId, tacho.record_date, tacho.driver_code, tacho.vehicle_number]
        );

        res.json({
            tachograph_data: tacho,
            candidates: candidates.rows
        });
    } catch (error) {
        console.error('Error fetching match candidates:', error);
        res.status(500).json({ error: '候補の取得に失敗しました' });
    }
};
