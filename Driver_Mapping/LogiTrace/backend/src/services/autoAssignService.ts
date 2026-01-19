/**
 * Auto Assign Service - 自動配車割当サービス
 * 空き車両・ドライバーの自動提案、拘束時間を考慮した割当
 */

import { pool } from '../utils/db';
import * as laborComplianceService from './laborComplianceService';

interface Order {
    id: number;
    company_id: number;
    pickup_datetime: Date;
    delivery_datetime: Date | null;
    required_vehicle_type: string | null;
    required_license_type: string | null;
    cargo_weight: number | null;
}

interface AvailableVehicle {
    id: number;
    vehicle_number: string;
    vehicle_type: string;
    max_load_weight: number;
    is_available: boolean;
    current_dispatch_end: Date | null;
    availability_score: number;
}

interface AvailableDriver {
    id: number;
    name: string;
    employee_number: string;
    license_type: string;
    current_binding_minutes: number;
    projected_binding_minutes: number;
    binding_status: 'normal' | 'warning' | 'violation';
    is_available: boolean;
    current_dispatch_end: Date | null;
    availability_score: number;
}

interface AssignmentSuggestion {
    vehicle: AvailableVehicle;
    driver: AvailableDriver;
    score: number;
    warnings: string[];
}

// 指定日時に空いている車両を取得
export async function getAvailableVehicles(
    companyId: number,
    startTime: Date,
    endTime: Date | null,
    requirements?: {
        vehicleType?: string;
        minLoadWeight?: number;
    }
): Promise<AvailableVehicle[]> {
    const endDateTime = endTime || new Date(startTime.getTime() + 8 * 60 * 60 * 1000); // デフォルト8時間

    const result = await pool.query(`
        SELECT
            v.id,
            v.vehicle_number,
            v.vehicle_type,
            v.max_load_weight,
            v.is_active,
            (
                SELECT MAX(da.scheduled_end)
                FROM dispatch_assignments da
                WHERE da.vehicle_id = v.id
                  AND da.status NOT IN ('completed', 'cancelled')
                  AND da.scheduled_start < $3
                  AND da.scheduled_end > $2
            ) as conflicting_end,
            (
                SELECT da.scheduled_end
                FROM dispatch_assignments da
                WHERE da.vehicle_id = v.id
                  AND da.status NOT IN ('completed', 'cancelled')
                  AND da.scheduled_end <= $2
                ORDER BY da.scheduled_end DESC
                LIMIT 1
            ) as last_dispatch_end
        FROM vehicles v
        WHERE v.company_id = $1 AND v.is_active = TRUE
        ${requirements?.vehicleType ? `AND v.vehicle_type = $4` : ''}
        ${requirements?.minLoadWeight ? `AND v.max_load_weight >= $${requirements?.vehicleType ? 5 : 4}` : ''}
        ORDER BY v.vehicle_number
    `, requirements?.vehicleType && requirements?.minLoadWeight
        ? [companyId, startTime, endDateTime, requirements.vehicleType, requirements.minLoadWeight]
        : requirements?.vehicleType
            ? [companyId, startTime, endDateTime, requirements.vehicleType]
            : requirements?.minLoadWeight
                ? [companyId, startTime, endDateTime, requirements.minLoadWeight]
                : [companyId, startTime, endDateTime]);

    return result.rows.map(row => {
        const isAvailable = !row.conflicting_end;
        let availabilityScore = 100;

        if (!isAvailable) {
            availabilityScore = 0;
        } else if (row.last_dispatch_end) {
            // 前の配車終了から開始までの余裕時間でスコア調整
            const gapMinutes = (startTime.getTime() - new Date(row.last_dispatch_end).getTime()) / 60000;
            if (gapMinutes < 30) availabilityScore -= 20;
            else if (gapMinutes < 60) availabilityScore -= 10;
        }

        return {
            id: row.id,
            vehicle_number: row.vehicle_number,
            vehicle_type: row.vehicle_type,
            max_load_weight: parseFloat(row.max_load_weight) || 0,
            is_available: isAvailable,
            current_dispatch_end: row.conflicting_end,
            availability_score: availabilityScore
        };
    });
}

// 指定日時に空いているドライバーを取得（拘束時間考慮）
export async function getAvailableDrivers(
    companyId: number,
    startTime: Date,
    endTime: Date | null,
    estimatedDurationMinutes: number,
    requirements?: {
        licenseType?: string;
    }
): Promise<AvailableDriver[]> {
    const endDateTime = endTime || new Date(startTime.getTime() + estimatedDurationMinutes * 60 * 1000);
    const workDate = startTime.toISOString().split('T')[0];

    // 設定を取得
    const settings = await laborComplianceService.getComplianceSettings(companyId);

    const result = await pool.query(`
        SELECT
            u.id,
            u.name,
            u.employee_number,
            dr.license_type,
            (
                SELECT MAX(da.scheduled_end)
                FROM dispatch_assignments da
                WHERE da.driver_id = u.id
                  AND da.status NOT IN ('completed', 'cancelled')
                  AND da.scheduled_start < $3
                  AND da.scheduled_end > $2
            ) as conflicting_end,
            (
                SELECT da.scheduled_end
                FROM dispatch_assignments da
                WHERE da.driver_id = u.id
                  AND da.status NOT IN ('completed', 'cancelled')
                  AND da.scheduled_end <= $2
                ORDER BY da.scheduled_end DESC
                LIMIT 1
            ) as last_dispatch_end,
            COALESCE(lds.total_binding_minutes, 0) as current_binding_minutes,
            (
                SELECT SUM(
                    EXTRACT(EPOCH FROM (LEAST(da.scheduled_end, $3::timestamp) - GREATEST(da.scheduled_start, $2::timestamp))) / 60
                )::INTEGER
                FROM dispatch_assignments da
                WHERE da.driver_id = u.id
                  AND da.status NOT IN ('completed', 'cancelled')
                  AND DATE(da.scheduled_start) = $4::date
            ) as scheduled_binding_today
        FROM users u
        LEFT JOIN driver_registry dr ON u.id = dr.user_id
        LEFT JOIN labor_daily_summary lds ON u.id = lds.driver_id AND lds.summary_date = $4::date
        WHERE u.company_id = $1 AND u.role = 'driver' AND u.is_active = TRUE
        ${requirements?.licenseType ? `AND dr.license_type = $5` : ''}
        ORDER BY u.name
    `, requirements?.licenseType
        ? [companyId, startTime, endDateTime, workDate, requirements.licenseType]
        : [companyId, startTime, endDateTime, workDate]);

    const warningThreshold = settings.daily_binding_time_limit * settings.warning_threshold_percent / 100;

    return result.rows.map(row => {
        const isAvailable = !row.conflicting_end;
        const currentBinding = parseInt(row.current_binding_minutes) || 0;
        const scheduledToday = parseInt(row.scheduled_binding_today) || 0;
        const projectedBinding = currentBinding + scheduledToday + estimatedDurationMinutes;

        let bindingStatus: 'normal' | 'warning' | 'violation' = 'normal';
        if (projectedBinding >= settings.daily_binding_time_limit) {
            bindingStatus = 'violation';
        } else if (projectedBinding >= warningThreshold) {
            bindingStatus = 'warning';
        }

        let availabilityScore = 100;

        if (!isAvailable) {
            availabilityScore = 0;
        } else {
            // 拘束時間によるスコア調整
            if (bindingStatus === 'violation') {
                availabilityScore -= 50;
            } else if (bindingStatus === 'warning') {
                availabilityScore -= 20;
            }

            // 余裕時間によるスコア調整
            if (row.last_dispatch_end) {
                const gapMinutes = (startTime.getTime() - new Date(row.last_dispatch_end).getTime()) / 60000;
                if (gapMinutes < 30) availabilityScore -= 15;
                else if (gapMinutes < 60) availabilityScore -= 5;
            }
        }

        return {
            id: row.id,
            name: row.name,
            employee_number: row.employee_number || '',
            license_type: row.license_type || '',
            current_binding_minutes: currentBinding,
            projected_binding_minutes: projectedBinding,
            binding_status: bindingStatus,
            is_available: isAvailable,
            current_dispatch_end: row.conflicting_end,
            availability_score: Math.max(0, availabilityScore)
        };
    });
}

// 受注に対する割当候補を提案
export async function suggestAssignments(
    order: Order,
    estimatedDurationMinutes: number = 240 // デフォルト4時間
): Promise<AssignmentSuggestion[]> {
    const startTime = new Date(order.pickup_datetime);
    const endTime = order.delivery_datetime ? new Date(order.delivery_datetime) : null;

    // 空き車両とドライバーを取得
    const [vehicles, drivers] = await Promise.all([
        getAvailableVehicles(order.company_id, startTime, endTime, {
            vehicleType: order.required_vehicle_type || undefined,
            minLoadWeight: order.cargo_weight || undefined
        }),
        getAvailableDrivers(order.company_id, startTime, endTime, estimatedDurationMinutes, {
            licenseType: order.required_license_type || undefined
        })
    ]);

    const suggestions: AssignmentSuggestion[] = [];

    // 空いている車両とドライバーの組み合わせを生成
    const availableVehicles = vehicles.filter(v => v.is_available);
    const availableDrivers = drivers.filter(d => d.is_available);

    for (const vehicle of availableVehicles) {
        for (const driver of availableDrivers) {
            const warnings: string[] = [];

            // 警告を生成
            if (driver.binding_status === 'warning') {
                warnings.push(`拘束時間が上限の90%を超過します（予想: ${Math.floor(driver.projected_binding_minutes / 60)}時間${driver.projected_binding_minutes % 60}分）`);
            } else if (driver.binding_status === 'violation') {
                warnings.push(`拘束時間が上限を超過します（予想: ${Math.floor(driver.projected_binding_minutes / 60)}時間${driver.projected_binding_minutes % 60}分）`);
            }

            // スコア計算（車両とドライバーのスコアの平均）
            const score = (vehicle.availability_score + driver.availability_score) / 2;

            suggestions.push({
                vehicle,
                driver,
                score,
                warnings
            });
        }
    }

    // スコアで降順ソート
    suggestions.sort((a, b) => b.score - a.score);

    return suggestions;
}

// ベスト割当を取得
export async function getBestAssignment(
    order: Order,
    estimatedDurationMinutes: number = 240
): Promise<AssignmentSuggestion | null> {
    const suggestions = await suggestAssignments(order, estimatedDurationMinutes);

    // 違反のない最良の組み合わせを返す
    const bestWithoutViolation = suggestions.find(s =>
        s.driver.binding_status !== 'violation' && s.score > 0
    );

    if (bestWithoutViolation) {
        return bestWithoutViolation;
    }

    // 違反があっても利用可能な場合は警告付きで返す
    return suggestions.length > 0 ? suggestions[0] : null;
}

// 配車時間の見積もり
export async function estimateDispatchDuration(
    pickupLocationId: number | null,
    deliveryLocationId: number | null,
    pickupAddress: string | null,
    deliveryAddress: string | null
): Promise<{ distance_km: number; duration_minutes: number }> {
    // TODO: Google Maps Distance Matrix API等との連携

    // 暫定: 発着地マスタの標準時間を使用
    let loadingTime = 30;
    let unloadingTime = 30;

    if (pickupLocationId) {
        const pickup = await pool.query(
            'SELECT loading_time_minutes FROM locations WHERE id = $1',
            [pickupLocationId]
        );
        if (pickup.rows.length > 0) {
            loadingTime = pickup.rows[0].loading_time_minutes || 30;
        }
    }

    if (deliveryLocationId) {
        const delivery = await pool.query(
            'SELECT unloading_time_minutes FROM locations WHERE id = $1',
            [deliveryLocationId]
        );
        if (delivery.rows.length > 0) {
            unloadingTime = delivery.rows[0].unloading_time_minutes || 30;
        }
    }

    // 暫定値（実際は距離計算が必要）
    const estimatedDrivingMinutes = 120; // 2時間
    const estimatedDistanceKm = 100; // 100km

    return {
        distance_km: estimatedDistanceKm,
        duration_minutes: loadingTime + estimatedDrivingMinutes + unloadingTime
    };
}
