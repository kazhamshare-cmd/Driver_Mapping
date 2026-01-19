import { pool } from '../utils/db';

interface GpsTrack {
    id: number;
    timestamp: Date;
    latitude: number;
    longitude: number;
    speed: number;
}

interface DetectedBreak {
    start_time: Date;
    end_time: Date;
    duration_minutes: number;
    latitude: number;
    longitude: number;
    location_name?: string;
}

// 2点間の距離を計算（メートル）- Haversine公式
function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371000; // 地球の半径（メートル）
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
              Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
              Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

// GPS停止検出の設定
const BREAK_DETECTION_CONFIG = {
    MIN_BREAK_DURATION_MINUTES: 15,   // 最小休憩時間（分）- 踏切・信号待ち等の誤検出を防ぐため15分以上
    MAX_MOVEMENT_METERS: 50,          // 停止とみなす最大移動距離（メートル）
    SPEED_THRESHOLD_KMH: 3,           // 停止とみなす速度閾値（km/h）
};

/**
 * GPSトラックから休憩を自動検出
 */
export async function detectBreaksFromGpsTracks(workRecordId: number): Promise<DetectedBreak[]> {
    // GPSトラックを時系列で取得
    const result = await pool.query(`
        SELECT id, timestamp, latitude, longitude, speed
        FROM gps_tracks
        WHERE work_record_id = $1
        ORDER BY timestamp ASC
    `, [workRecordId]);

    const tracks: GpsTrack[] = result.rows.map(row => ({
        ...row,
        timestamp: new Date(row.timestamp),
        latitude: parseFloat(row.latitude),
        longitude: parseFloat(row.longitude),
        speed: parseFloat(row.speed) || 0
    }));

    if (tracks.length < 2) {
        return [];
    }

    const detectedBreaks: DetectedBreak[] = [];
    let breakStart: GpsTrack | null = null;
    let breakCenter = { lat: 0, lon: 0 };

    for (let i = 1; i < tracks.length; i++) {
        const prev = tracks[i - 1];
        const curr = tracks[i];

        // 移動距離と速度をチェック
        const distance = calculateDistance(prev.latitude, prev.longitude, curr.latitude, curr.longitude);
        const isStationary = distance < BREAK_DETECTION_CONFIG.MAX_MOVEMENT_METERS &&
                            curr.speed < BREAK_DETECTION_CONFIG.SPEED_THRESHOLD_KMH;

        if (isStationary) {
            // 停止開始
            if (!breakStart) {
                breakStart = prev;
                breakCenter = { lat: prev.latitude, lon: prev.longitude };
            }
        } else {
            // 移動再開 - 休憩終了を記録
            if (breakStart) {
                const durationMs = curr.timestamp.getTime() - breakStart.timestamp.getTime();
                const durationMinutes = Math.round(durationMs / 60000);

                if (durationMinutes >= BREAK_DETECTION_CONFIG.MIN_BREAK_DURATION_MINUTES) {
                    detectedBreaks.push({
                        start_time: breakStart.timestamp,
                        end_time: prev.timestamp,
                        duration_minutes: durationMinutes,
                        latitude: breakCenter.lat,
                        longitude: breakCenter.lon
                    });
                }
                breakStart = null;
            }
        }
    }

    // 最後が停止状態で終わっている場合
    if (breakStart && tracks.length > 0) {
        const lastTrack = tracks[tracks.length - 1];
        const durationMs = lastTrack.timestamp.getTime() - breakStart.timestamp.getTime();
        const durationMinutes = Math.round(durationMs / 60000);

        if (durationMinutes >= BREAK_DETECTION_CONFIG.MIN_BREAK_DURATION_MINUTES) {
            detectedBreaks.push({
                start_time: breakStart.timestamp,
                end_time: lastTrack.timestamp,
                duration_minutes: durationMinutes,
                latitude: breakCenter.lat,
                longitude: breakCenter.lon
            });
        }
    }

    return detectedBreaks;
}

/**
 * 検出した休憩をDBに保存
 */
export async function saveDetectedBreaks(workRecordId: number, breaks: DetectedBreak[]): Promise<void> {
    // 既存の自動検出休憩を削除
    await pool.query(
        `DELETE FROM break_records WHERE work_record_id = $1 AND detection_method = 'auto'`,
        [workRecordId]
    );

    // 新しい休憩を挿入
    for (const brk of breaks) {
        await pool.query(`
            INSERT INTO break_records
            (work_record_id, start_time, end_time, duration_minutes, latitude, longitude, detection_method)
            VALUES ($1, $2, $3, $4, $5, $6, 'auto')
        `, [workRecordId, brk.start_time, brk.end_time, brk.duration_minutes, brk.latitude, brk.longitude]);
    }

    // work_recordsのauto_break_minutesを更新
    const totalBreakMinutes = breaks.reduce((sum, b) => sum + b.duration_minutes, 0);
    await pool.query(
        `UPDATE work_records SET auto_break_minutes = $1 WHERE id = $2`,
        [totalBreakMinutes, workRecordId]
    );
}

/**
 * 運行記録の休憩を検出して保存（乗務終了時に呼び出す）
 */
export async function processBreakDetection(workRecordId: number): Promise<{
    detected_breaks: DetectedBreak[];
    total_break_minutes: number;
}> {
    const breaks = await detectBreaksFromGpsTracks(workRecordId);
    await saveDetectedBreaks(workRecordId, breaks);

    const totalBreakMinutes = breaks.reduce((sum, b) => sum + b.duration_minutes, 0);

    return {
        detected_breaks: breaks,
        total_break_minutes: totalBreakMinutes
    };
}

/**
 * 逆ジオコーディング（座標から住所取得）- オプション
 * 注: 実際の実装では外部APIを使用
 */
export async function reverseGeocode(latitude: number, longitude: number): Promise<string | null> {
    // TODO: Google Maps API や OpenStreetMap Nominatim などを使用
    // 現時点では座標を返す
    return `${latitude.toFixed(4)}, ${longitude.toFixed(4)}`;
}
