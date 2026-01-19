/**
 * デジタコデータパーサーサービス
 * 各メーカー（矢崎、富士通、デンソー等）のCSV/データ形式を統一形式に変換
 */

export interface ParsedTachographRecord {
    driver_code: string;
    vehicle_number: string;
    record_date: string; // YYYY-MM-DD
    start_time: string;  // HH:MM
    end_time: string;    // HH:MM
    distance: number;
    max_speed: number;
    avg_speed: number;
    idle_time_minutes: number;
    driving_time_minutes: number;
    rest_time_minutes: number;
    harsh_braking_count: number;
    harsh_acceleration_count: number;
    speeding_count: number;
    raw_data: any;
}

export type TachographType = 'yazaki' | 'fujitsu' | 'denso' | 'auto';

// 矢崎デジタコ形式パーサー
function parseYazakiFormat(csvContent: string): ParsedTachographRecord[] {
    const lines = csvContent.split('\n').filter(line => line.trim());
    const records: ParsedTachographRecord[] = [];

    // ヘッダー行をスキップ（最初の行）
    for (let i = 1; i < lines.length; i++) {
        const columns = lines[i].split(',');
        if (columns.length < 10) continue;

        try {
            const record: ParsedTachographRecord = {
                driver_code: columns[0]?.trim() || '',
                vehicle_number: columns[1]?.trim() || '',
                record_date: formatDate(columns[2]?.trim()),
                start_time: formatTime(columns[3]?.trim()),
                end_time: formatTime(columns[4]?.trim()),
                distance: parseFloat(columns[5]) || 0,
                max_speed: parseFloat(columns[6]) || 0,
                avg_speed: parseFloat(columns[7]) || 0,
                idle_time_minutes: parseInt(columns[8]) || 0,
                driving_time_minutes: parseInt(columns[9]) || 0,
                rest_time_minutes: parseInt(columns[10]) || 0,
                harsh_braking_count: parseInt(columns[11]) || 0,
                harsh_acceleration_count: parseInt(columns[12]) || 0,
                speeding_count: parseInt(columns[13]) || 0,
                raw_data: { format: 'yazaki', original: columns }
            };
            records.push(record);
        } catch (e) {
            console.error(`Line ${i} parse error:`, e);
        }
    }

    return records;
}

// 富士通デジタコ形式パーサー
function parseFujitsuFormat(csvContent: string): ParsedTachographRecord[] {
    const lines = csvContent.split('\n').filter(line => line.trim());
    const records: ParsedTachographRecord[] = [];

    // 富士通形式はヘッダーが2行ある場合がある
    const startIndex = lines[0].includes('ドライバー') || lines[0].includes('運転者') ? 1 : 0;

    for (let i = startIndex; i < lines.length; i++) {
        const columns = lines[i].split(',');
        if (columns.length < 8) continue;

        try {
            const record: ParsedTachographRecord = {
                driver_code: columns[1]?.trim() || '',
                vehicle_number: columns[0]?.trim() || '',
                record_date: formatDate(columns[2]?.trim()),
                start_time: formatTime(columns[3]?.trim()),
                end_time: formatTime(columns[4]?.trim()),
                distance: parseFloat(columns[5]) || 0,
                max_speed: parseFloat(columns[6]) || 0,
                avg_speed: parseFloat(columns[7]) || 0,
                idle_time_minutes: parseInt(columns[8]) || 0,
                driving_time_minutes: parseInt(columns[9]) || 0,
                rest_time_minutes: parseInt(columns[10]) || 0,
                harsh_braking_count: parseInt(columns[11]) || 0,
                harsh_acceleration_count: parseInt(columns[12]) || 0,
                speeding_count: parseInt(columns[13]) || 0,
                raw_data: { format: 'fujitsu', original: columns }
            };
            records.push(record);
        } catch (e) {
            console.error(`Line ${i} parse error:`, e);
        }
    }

    return records;
}

// デンソーデジタコ形式パーサー
function parseDensoFormat(csvContent: string): ParsedTachographRecord[] {
    const lines = csvContent.split('\n').filter(line => line.trim());
    const records: ParsedTachographRecord[] = [];

    // デンソー形式
    for (let i = 1; i < lines.length; i++) {
        const columns = lines[i].split(',');
        if (columns.length < 8) continue;

        try {
            const record: ParsedTachographRecord = {
                driver_code: columns[2]?.trim() || '',
                vehicle_number: columns[0]?.trim() || '',
                record_date: formatDate(columns[1]?.trim()),
                start_time: formatTime(columns[3]?.trim()),
                end_time: formatTime(columns[4]?.trim()),
                distance: parseFloat(columns[5]) || 0,
                max_speed: parseFloat(columns[6]) || 0,
                avg_speed: parseFloat(columns[7]) || 0,
                idle_time_minutes: parseInt(columns[8]) || 0,
                driving_time_minutes: parseInt(columns[9]) || 0,
                rest_time_minutes: parseInt(columns[10]) || 0,
                harsh_braking_count: parseInt(columns[11]) || 0,
                harsh_acceleration_count: parseInt(columns[12]) || 0,
                speeding_count: parseInt(columns[13]) || 0,
                raw_data: { format: 'denso', original: columns }
            };
            records.push(record);
        } catch (e) {
            console.error(`Line ${i} parse error:`, e);
        }
    }

    return records;
}

// 汎用CSVパーサー（自動検出できない場合）
function parseGenericFormat(csvContent: string): ParsedTachographRecord[] {
    const lines = csvContent.split('\n').filter(line => line.trim());
    const records: ParsedTachographRecord[] = [];

    // ヘッダー行から列の位置を推測
    const header = lines[0].toLowerCase();
    const columns = header.split(',');

    // 列インデックスを検出
    const findColumnIndex = (keywords: string[]): number => {
        return columns.findIndex(col =>
            keywords.some(kw => col.includes(kw))
        );
    };

    const driverIdx = findColumnIndex(['driver', 'ドライバー', '運転者', '乗務員']);
    const vehicleIdx = findColumnIndex(['vehicle', '車両', '車番']);
    const dateIdx = findColumnIndex(['date', '日付', '運行日']);
    const startIdx = findColumnIndex(['start', '出発', '開始']);
    const endIdx = findColumnIndex(['end', '到着', '終了']);
    const distanceIdx = findColumnIndex(['distance', '走行距離', '距離']);
    const maxSpeedIdx = findColumnIndex(['max', '最高速度']);
    const avgSpeedIdx = findColumnIndex(['avg', '平均速度']);

    for (let i = 1; i < lines.length; i++) {
        const cols = lines[i].split(',');
        if (cols.length < 5) continue;

        try {
            const record: ParsedTachographRecord = {
                driver_code: driverIdx >= 0 ? cols[driverIdx]?.trim() : cols[0]?.trim() || '',
                vehicle_number: vehicleIdx >= 0 ? cols[vehicleIdx]?.trim() : cols[1]?.trim() || '',
                record_date: dateIdx >= 0 ? formatDate(cols[dateIdx]?.trim()) : formatDate(cols[2]?.trim()),
                start_time: startIdx >= 0 ? formatTime(cols[startIdx]?.trim()) : formatTime(cols[3]?.trim()),
                end_time: endIdx >= 0 ? formatTime(cols[endIdx]?.trim()) : formatTime(cols[4]?.trim()),
                distance: distanceIdx >= 0 ? parseFloat(cols[distanceIdx]) || 0 : parseFloat(cols[5]) || 0,
                max_speed: maxSpeedIdx >= 0 ? parseFloat(cols[maxSpeedIdx]) || 0 : 0,
                avg_speed: avgSpeedIdx >= 0 ? parseFloat(cols[avgSpeedIdx]) || 0 : 0,
                idle_time_minutes: 0,
                driving_time_minutes: 0,
                rest_time_minutes: 0,
                harsh_braking_count: 0,
                harsh_acceleration_count: 0,
                speeding_count: 0,
                raw_data: { format: 'generic', original: cols }
            };
            records.push(record);
        } catch (e) {
            console.error(`Line ${i} parse error:`, e);
        }
    }

    return records;
}

// フォーマット自動検出
function detectFormat(csvContent: string): TachographType {
    const firstLines = csvContent.split('\n').slice(0, 3).join('\n').toLowerCase();

    if (firstLines.includes('矢崎') || firstLines.includes('yazaki') || firstLines.includes('yt-')) {
        return 'yazaki';
    }
    if (firstLines.includes('富士通') || firstLines.includes('fujitsu') || firstLines.includes('dts-')) {
        return 'fujitsu';
    }
    if (firstLines.includes('デンソー') || firstLines.includes('denso') || firstLines.includes('d-trace')) {
        return 'denso';
    }

    return 'auto';
}

// 日付フォーマット変換（YYYY-MM-DD形式に統一）
function formatDate(dateStr: string): string {
    if (!dateStr) return '';

    // YYYY/MM/DD or YYYY-MM-DD
    if (/^\d{4}[\/\-]\d{1,2}[\/\-]\d{1,2}$/.test(dateStr)) {
        return dateStr.replace(/\//g, '-');
    }

    // MM/DD/YYYY
    const mdyMatch = dateStr.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/);
    if (mdyMatch) {
        return `${mdyMatch[3]}-${mdyMatch[1].padStart(2, '0')}-${mdyMatch[2].padStart(2, '0')}`;
    }

    // YYYYMMDD
    const compactMatch = dateStr.match(/^(\d{4})(\d{2})(\d{2})$/);
    if (compactMatch) {
        return `${compactMatch[1]}-${compactMatch[2]}-${compactMatch[3]}`;
    }

    return dateStr;
}

// 時刻フォーマット変換（HH:MM形式に統一）
function formatTime(timeStr: string): string {
    if (!timeStr) return '';

    // HH:MM or HH:MM:SS
    if (/^\d{1,2}:\d{2}(:\d{2})?$/.test(timeStr)) {
        return timeStr.substring(0, 5);
    }

    // HHMM
    const compactMatch = timeStr.match(/^(\d{2})(\d{2})$/);
    if (compactMatch) {
        return `${compactMatch[1]}:${compactMatch[2]}`;
    }

    return timeStr;
}

// メインパース関数
export function parseTachographData(
    csvContent: string,
    fileType: TachographType = 'auto'
): ParsedTachographRecord[] {
    const detectedType = fileType === 'auto' ? detectFormat(csvContent) : fileType;

    switch (detectedType) {
        case 'yazaki':
            return parseYazakiFormat(csvContent);
        case 'fujitsu':
            return parseFujitsuFormat(csvContent);
        case 'denso':
            return parseDensoFormat(csvContent);
        default:
            return parseGenericFormat(csvContent);
    }
}

// バリデーション
export function validateParsedRecords(records: ParsedTachographRecord[]): {
    valid: ParsedTachographRecord[];
    invalid: { record: ParsedTachographRecord; reason: string }[];
} {
    const valid: ParsedTachographRecord[] = [];
    const invalid: { record: ParsedTachographRecord; reason: string }[] = [];

    for (const record of records) {
        const errors: string[] = [];

        if (!record.record_date || !/^\d{4}-\d{2}-\d{2}$/.test(record.record_date)) {
            errors.push('日付が無効');
        }
        if (!record.driver_code && !record.vehicle_number) {
            errors.push('ドライバーコードまたは車両番号が必要');
        }
        if (record.distance < 0) {
            errors.push('走行距離が無効');
        }

        if (errors.length === 0) {
            valid.push(record);
        } else {
            invalid.push({ record, reason: errors.join(', ') });
        }
    }

    return { valid, invalid };
}
