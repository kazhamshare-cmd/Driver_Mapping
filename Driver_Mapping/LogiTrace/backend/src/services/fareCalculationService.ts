/**
 * Fare Calculation Service - 運賃計算サービス
 * 距離制・時間制・固定運賃・割増料金の計算
 */

import { pool } from '../index';

// 運賃タイプ
export type FareType = 'distance' | 'time' | 'fixed' | 'mixed';

// 割増タイプ
export type SurchargeType = 'night' | 'early_morning' | 'holiday';

// 運賃マスタ
export interface FareMaster {
    id: number;
    companyId: number;
    shipperId: number;
    name: string;
    fareType: FareType;
    baseDistanceKm: number;
    baseRate: number;
    ratePerKm: number;
    baseTimeHours: number;
    ratePerHour: number;
    fixedRate: number;
    nightSurchargeRate: number;
    earlyMorningSurchargeRate: number;
    holidaySurchargeRate: number;
    loadingFee: number;
    unloadingFee: number;
    waitingFeePerHour: number;
    vehicleTypeCoefficients: Record<string, number>;
    effectiveFrom: string;
    effectiveTo: string | null;
}

// 運賃計算入力
export interface FareCalculationInput {
    companyId: number;
    shipperId?: number;
    fareMasterId?: number;

    // 距離・時間
    distanceKm?: number;
    drivingTimeMinutes?: number;

    // 日時（割増計算用）
    workDate: string;
    startTime?: string;
    endTime?: string;

    // 附帯作業
    hasLoading?: boolean;
    hasUnloading?: boolean;
    waitingMinutes?: number;

    // 高速代
    tollFee?: number;

    // 車両タイプ
    vehicleType?: string;

    // 祝日フラグ
    isHoliday?: boolean;
}

// 運賃計算結果
export interface FareCalculationResult {
    baseFare: number;
    distanceFare: number;
    timeFare: number;
    loadingFee: number;
    unloadingFee: number;
    waitingFee: number;
    nightSurcharge: number;
    earlyMorningSurcharge: number;
    holidaySurcharge: number;
    tollFee: number;
    subtotal: number;
    taxRate: number;
    taxAmount: number;
    total: number;
    breakdown: FareBreakdownItem[];
}

export interface FareBreakdownItem {
    itemType: string;
    description: string;
    quantity: number;
    unit: string;
    unitPrice: number;
    amount: number;
}

// 祝日判定（日本の祝日）
const JAPAN_HOLIDAYS_2026 = [
    '2026-01-01', '2026-01-12', '2026-02-11', '2026-02-23',
    '2026-03-20', '2026-04-29', '2026-05-03', '2026-05-04', '2026-05-05', '2026-05-06',
    '2026-07-20', '2026-08-11', '2026-09-21', '2026-09-22', '2026-09-23',
    '2026-10-12', '2026-11-03', '2026-11-23', '2026-12-23'
];

function isJapaneseHoliday(dateStr: string): boolean {
    return JAPAN_HOLIDAYS_2026.includes(dateStr);
}

function isSunday(dateStr: string): boolean {
    const date = new Date(dateStr);
    return date.getDay() === 0;
}

function isSaturday(dateStr: string): boolean {
    const date = new Date(dateStr);
    return date.getDay() === 6;
}

// 時間帯判定
function getTimeType(timeStr: string): 'night' | 'early_morning' | 'normal' {
    const [hours] = timeStr.split(':').map(Number);
    if (hours >= 22 || hours < 5) return 'night';
    if (hours >= 5 && hours < 7) return 'early_morning';
    return 'normal';
}

// 深夜・早朝時間の比率を計算
function calculateSurchargeRatio(
    startTime: string,
    endTime: string
): { nightRatio: number; earlyMorningRatio: number } {
    const parseTime = (t: string) => {
        const [h, m] = t.split(':').map(Number);
        return h * 60 + m;
    };

    let start = parseTime(startTime);
    let end = parseTime(endTime);

    // 日付またぎ対応
    if (end < start) end += 24 * 60;

    const totalMinutes = end - start;
    if (totalMinutes <= 0) return { nightRatio: 0, earlyMorningRatio: 0 };

    let nightMinutes = 0;
    let earlyMorningMinutes = 0;

    for (let t = start; t < end; t++) {
        const hour = Math.floor((t % (24 * 60)) / 60);
        if (hour >= 22 || hour < 5) {
            nightMinutes++;
        } else if (hour >= 5 && hour < 7) {
            earlyMorningMinutes++;
        }
    }

    return {
        nightRatio: nightMinutes / totalMinutes,
        earlyMorningRatio: earlyMorningMinutes / totalMinutes
    };
}

/**
 * 運賃マスタを取得
 */
export async function getFareMaster(
    companyId: number,
    shipperId?: number,
    fareMasterId?: number,
    date?: string
): Promise<FareMaster | null> {
    const targetDate = date || new Date().toISOString().split('T')[0];

    let query = `
        SELECT * FROM fare_masters
        WHERE company_id = $1
          AND is_active = TRUE
          AND effective_from <= $2
          AND (effective_to IS NULL OR effective_to >= $2)
    `;
    const params: any[] = [companyId, targetDate];

    if (fareMasterId) {
        query += ` AND id = $${params.length + 1}`;
        params.push(fareMasterId);
    } else if (shipperId) {
        query += ` AND shipper_id = $${params.length + 1}`;
        params.push(shipperId);
    }

    query += ` ORDER BY shipper_id NULLS LAST, effective_from DESC LIMIT 1`;

    const result = await pool.query(query, params);

    if (result.rows.length === 0) return null;

    const row = result.rows[0];
    return {
        id: row.id,
        companyId: row.company_id,
        shipperId: row.shipper_id,
        name: row.name,
        fareType: row.fare_type,
        baseDistanceKm: parseFloat(row.base_distance_km) || 0,
        baseRate: parseFloat(row.base_rate) || 0,
        ratePerKm: parseFloat(row.rate_per_km) || 0,
        baseTimeHours: parseFloat(row.base_time_hours) || 0,
        ratePerHour: parseFloat(row.rate_per_hour) || 0,
        fixedRate: parseFloat(row.fixed_rate) || 0,
        nightSurchargeRate: parseFloat(row.night_surcharge_rate) || 25,
        earlyMorningSurchargeRate: parseFloat(row.early_morning_surcharge_rate) || 25,
        holidaySurchargeRate: parseFloat(row.holiday_surcharge_rate) || 35,
        loadingFee: parseFloat(row.loading_fee) || 0,
        unloadingFee: parseFloat(row.unloading_fee) || 0,
        waitingFeePerHour: parseFloat(row.waiting_fee_per_hour) || 0,
        vehicleTypeCoefficients: row.vehicle_type_coefficients || {},
        effectiveFrom: row.effective_from,
        effectiveTo: row.effective_to
    };
}

/**
 * 運賃を計算
 */
export async function calculateFare(input: FareCalculationInput): Promise<FareCalculationResult> {
    // 運賃マスタ取得
    const fareMaster = await getFareMaster(
        input.companyId,
        input.shipperId,
        input.fareMasterId,
        input.workDate
    );

    const breakdown: FareBreakdownItem[] = [];

    let baseFare = 0;
    let distanceFare = 0;
    let timeFare = 0;

    if (fareMaster) {
        // 車両タイプ係数
        const vehicleCoefficient = input.vehicleType
            ? (fareMaster.vehicleTypeCoefficients[input.vehicleType] || 1)
            : 1;

        switch (fareMaster.fareType) {
            case 'distance':
                // 距離制運賃
                baseFare = fareMaster.baseRate;
                if (input.distanceKm && input.distanceKm > fareMaster.baseDistanceKm) {
                    const extraKm = input.distanceKm - fareMaster.baseDistanceKm;
                    distanceFare = extraKm * fareMaster.ratePerKm;
                }
                breakdown.push({
                    itemType: 'transport',
                    description: `基本運賃（${fareMaster.baseDistanceKm}kmまで）`,
                    quantity: 1,
                    unit: '式',
                    unitPrice: baseFare * vehicleCoefficient,
                    amount: baseFare * vehicleCoefficient
                });
                if (distanceFare > 0) {
                    const extraKm = (input.distanceKm || 0) - fareMaster.baseDistanceKm;
                    breakdown.push({
                        itemType: 'transport',
                        description: `距離加算（${extraKm.toFixed(1)}km × @${fareMaster.ratePerKm}）`,
                        quantity: extraKm,
                        unit: 'km',
                        unitPrice: fareMaster.ratePerKm * vehicleCoefficient,
                        amount: distanceFare * vehicleCoefficient
                    });
                }
                baseFare *= vehicleCoefficient;
                distanceFare *= vehicleCoefficient;
                break;

            case 'time':
                // 時間制運賃
                baseFare = fareMaster.baseRate;
                if (input.drivingTimeMinutes) {
                    const hours = input.drivingTimeMinutes / 60;
                    if (hours > fareMaster.baseTimeHours) {
                        const extraHours = hours - fareMaster.baseTimeHours;
                        timeFare = extraHours * fareMaster.ratePerHour;
                    }
                }
                breakdown.push({
                    itemType: 'transport',
                    description: `基本運賃（${fareMaster.baseTimeHours}時間まで）`,
                    quantity: 1,
                    unit: '式',
                    unitPrice: baseFare * vehicleCoefficient,
                    amount: baseFare * vehicleCoefficient
                });
                if (timeFare > 0) {
                    const extraHours = ((input.drivingTimeMinutes || 0) / 60) - fareMaster.baseTimeHours;
                    breakdown.push({
                        itemType: 'transport',
                        description: `時間加算（${extraHours.toFixed(1)}時間 × @${fareMaster.ratePerHour}）`,
                        quantity: extraHours,
                        unit: '時間',
                        unitPrice: fareMaster.ratePerHour * vehicleCoefficient,
                        amount: timeFare * vehicleCoefficient
                    });
                }
                baseFare *= vehicleCoefficient;
                timeFare *= vehicleCoefficient;
                break;

            case 'fixed':
                // 固定運賃
                baseFare = fareMaster.fixedRate * vehicleCoefficient;
                breakdown.push({
                    itemType: 'transport',
                    description: '運賃',
                    quantity: 1,
                    unit: '式',
                    unitPrice: baseFare,
                    amount: baseFare
                });
                break;

            case 'mixed':
                // 距離制 + 時間制の組み合わせ
                baseFare = fareMaster.baseRate;
                if (input.distanceKm && input.distanceKm > fareMaster.baseDistanceKm) {
                    distanceFare = (input.distanceKm - fareMaster.baseDistanceKm) * fareMaster.ratePerKm;
                }
                if (input.drivingTimeMinutes) {
                    const hours = input.drivingTimeMinutes / 60;
                    if (hours > fareMaster.baseTimeHours) {
                        timeFare = (hours - fareMaster.baseTimeHours) * fareMaster.ratePerHour;
                    }
                }
                baseFare *= vehicleCoefficient;
                distanceFare *= vehicleCoefficient;
                timeFare *= vehicleCoefficient;
                breakdown.push({
                    itemType: 'transport',
                    description: '基本運賃',
                    quantity: 1,
                    unit: '式',
                    unitPrice: baseFare,
                    amount: baseFare
                });
                if (distanceFare > 0) {
                    breakdown.push({
                        itemType: 'transport',
                        description: '距離加算',
                        quantity: (input.distanceKm || 0) - fareMaster.baseDistanceKm,
                        unit: 'km',
                        unitPrice: fareMaster.ratePerKm * vehicleCoefficient,
                        amount: distanceFare
                    });
                }
                if (timeFare > 0) {
                    breakdown.push({
                        itemType: 'transport',
                        description: '時間加算',
                        quantity: ((input.drivingTimeMinutes || 0) / 60) - fareMaster.baseTimeHours,
                        unit: '時間',
                        unitPrice: fareMaster.ratePerHour * vehicleCoefficient,
                        amount: timeFare
                    });
                }
                break;
        }
    }

    // 附帯作業費
    let loadingFee = 0;
    let unloadingFee = 0;
    let waitingFee = 0;

    if (fareMaster) {
        if (input.hasLoading && fareMaster.loadingFee > 0) {
            loadingFee = fareMaster.loadingFee;
            breakdown.push({
                itemType: 'loading',
                description: '積込作業料',
                quantity: 1,
                unit: '式',
                unitPrice: loadingFee,
                amount: loadingFee
            });
        }

        if (input.hasUnloading && fareMaster.unloadingFee > 0) {
            unloadingFee = fareMaster.unloadingFee;
            breakdown.push({
                itemType: 'unloading',
                description: '荷卸作業料',
                quantity: 1,
                unit: '式',
                unitPrice: unloadingFee,
                amount: unloadingFee
            });
        }

        if (input.waitingMinutes && input.waitingMinutes > 0 && fareMaster.waitingFeePerHour > 0) {
            const waitingHours = input.waitingMinutes / 60;
            waitingFee = waitingHours * fareMaster.waitingFeePerHour;
            breakdown.push({
                itemType: 'waiting',
                description: `待機料（${waitingHours.toFixed(1)}時間）`,
                quantity: waitingHours,
                unit: '時間',
                unitPrice: fareMaster.waitingFeePerHour,
                amount: waitingFee
            });
        }
    }

    // 割増料金計算
    let nightSurcharge = 0;
    let earlyMorningSurcharge = 0;
    let holidaySurcharge = 0;

    const transportFare = baseFare + distanceFare + timeFare;

    if (fareMaster && transportFare > 0) {
        // 深夜・早朝割増
        if (input.startTime && input.endTime) {
            const { nightRatio, earlyMorningRatio } = calculateSurchargeRatio(
                input.startTime,
                input.endTime
            );

            if (nightRatio > 0) {
                nightSurcharge = transportFare * nightRatio * (fareMaster.nightSurchargeRate / 100);
                if (nightSurcharge > 0) {
                    breakdown.push({
                        itemType: 'surcharge',
                        description: `深夜割増（${(nightRatio * 100).toFixed(0)}% × ${fareMaster.nightSurchargeRate}%）`,
                        quantity: 1,
                        unit: '式',
                        unitPrice: nightSurcharge,
                        amount: nightSurcharge
                    });
                }
            }

            if (earlyMorningRatio > 0) {
                earlyMorningSurcharge = transportFare * earlyMorningRatio * (fareMaster.earlyMorningSurchargeRate / 100);
                if (earlyMorningSurcharge > 0) {
                    breakdown.push({
                        itemType: 'surcharge',
                        description: `早朝割増（${(earlyMorningRatio * 100).toFixed(0)}% × ${fareMaster.earlyMorningSurchargeRate}%）`,
                        quantity: 1,
                        unit: '式',
                        unitPrice: earlyMorningSurcharge,
                        amount: earlyMorningSurcharge
                    });
                }
            }
        }

        // 休日割増
        const isHoliday = input.isHoliday ||
            isJapaneseHoliday(input.workDate) ||
            isSunday(input.workDate);

        if (isHoliday) {
            holidaySurcharge = transportFare * (fareMaster.holidaySurchargeRate / 100);
            breakdown.push({
                itemType: 'surcharge',
                description: `休日割増（${fareMaster.holidaySurchargeRate}%）`,
                quantity: 1,
                unit: '式',
                unitPrice: holidaySurcharge,
                amount: holidaySurcharge
            });
        }
    }

    // 高速代
    const tollFee = input.tollFee || 0;
    if (tollFee > 0) {
        breakdown.push({
            itemType: 'toll',
            description: '高速代',
            quantity: 1,
            unit: '式',
            unitPrice: tollFee,
            amount: tollFee
        });
    }

    // 合計計算
    const subtotal = baseFare + distanceFare + timeFare +
        loadingFee + unloadingFee + waitingFee +
        nightSurcharge + earlyMorningSurcharge + holidaySurcharge +
        tollFee;

    const taxRate = 10; // 消費税率10%
    const taxAmount = Math.floor(subtotal * taxRate / 100);
    const total = subtotal + taxAmount;

    return {
        baseFare,
        distanceFare,
        timeFare,
        loadingFee,
        unloadingFee,
        waitingFee,
        nightSurcharge,
        earlyMorningSurcharge,
        holidaySurcharge,
        tollFee,
        subtotal,
        taxRate,
        taxAmount,
        total,
        breakdown
    };
}

/**
 * 複数の運行の運賃を一括計算
 */
export async function calculateMultipleFares(
    inputs: FareCalculationInput[]
): Promise<FareCalculationResult[]> {
    const results: FareCalculationResult[] = [];
    for (const input of inputs) {
        const result = await calculateFare(input);
        results.push(result);
    }
    return results;
}

/**
 * 高速代マスタから料金を取得
 */
export async function getTollFee(
    companyId: number,
    routeName?: string,
    fromLocation?: string,
    toLocation?: string,
    vehicleType: 'normal' | 'medium' | 'large' | 'extra_large' = 'large'
): Promise<number> {
    let query = `
        SELECT * FROM toll_masters
        WHERE company_id = $1 AND is_active = TRUE
    `;
    const params: any[] = [companyId];

    if (routeName) {
        query += ` AND route_name ILIKE $${params.length + 1}`;
        params.push(`%${routeName}%`);
    }

    if (fromLocation && toLocation) {
        query += ` AND (
            (from_location ILIKE $${params.length + 1} AND to_location ILIKE $${params.length + 2})
            OR (from_location ILIKE $${params.length + 2} AND to_location ILIKE $${params.length + 1})
        )`;
        params.push(`%${fromLocation}%`, `%${toLocation}%`);
    }

    query += ` LIMIT 1`;

    const result = await pool.query(query, params);

    if (result.rows.length === 0) return 0;

    const row = result.rows[0];
    const feeColumn = `${vehicleType}_fee`;
    const baseFee = parseFloat(row[feeColumn]) || 0;
    const etcDiscount = parseFloat(row.etc_discount_rate) || 0;

    // ETC割引適用
    return baseFee * (1 - etcDiscount / 100);
}
