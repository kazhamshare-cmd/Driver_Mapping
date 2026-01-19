/**
 * Cost Calculation Service - 原価計算サービス
 * 国土交通省「トラック運送業の標準的運賃」指針準拠
 */

import { pool } from '../index';

// 車両タイプ別の標準的なコスト係数
const VEHICLE_COST_COEFFICIENTS: Record<string, { fuel: number; maintenance: number; depreciation: number }> = {
    '2t': { fuel: 0.8, maintenance: 0.7, depreciation: 0.6 },
    '4t': { fuel: 1.0, maintenance: 1.0, depreciation: 1.0 },
    '10t': { fuel: 1.5, maintenance: 1.3, depreciation: 1.4 },
    'trailer': { fuel: 2.0, maintenance: 1.5, depreciation: 1.8 }
};

// 燃費の目安（km/L）
const FUEL_EFFICIENCY: Record<string, number> = {
    '2t': 10.0,
    '4t': 7.0,
    '10t': 4.5,
    'trailer': 3.5,
    'default': 6.0
};

/**
 * 運行ごとの原価を計算
 */
export async function calculateDispatchCost(
    dispatchId: number,
    options?: {
        fuelPrice?: number;  // 燃料単価（円/L）
        includeDriverCost?: boolean;
        includeVehicleCost?: boolean;
    }
): Promise<{
    fuelCost: number;
    tollCost: number;
    driverCost: number;
    vehicleCost: number;
    totalCost: number;
    revenue: number;
    profit: number;
    profitRate: number;
}> {
    const fuelPrice = options?.fuelPrice || 160; // デフォルト160円/L

    // 運行情報取得
    const dispatchResult = await pool.query(`
        SELECT
            da.*,
            o.shipper_id,
            v.vehicle_type,
            v.vehicle_number,
            EXTRACT(EPOCH FROM (da.actual_end - da.actual_start)) / 3600 AS operating_hours,
            COALESCE(ii.total_revenue, 0) AS revenue
        FROM dispatch_assignments da
        JOIN orders o ON da.order_id = o.id
        LEFT JOIN vehicles v ON da.vehicle_id = v.id
        LEFT JOIN (
            SELECT dispatch_id, SUM(amount) AS total_revenue
            FROM invoice_items
            WHERE dispatch_id IS NOT NULL
            GROUP BY dispatch_id
        ) ii ON da.id = ii.dispatch_id
        WHERE da.id = $1
    `, [dispatchId]);

    if (dispatchResult.rows.length === 0) {
        throw new Error('運行が見つかりません');
    }

    const dispatch = dispatchResult.rows[0];
    const vehicleType = dispatch.vehicle_type || 'default';
    const distanceKm = dispatch.actual_distance || 0;
    const operatingHours = dispatch.operating_hours || 0;

    // 燃料費計算
    const fuelEfficiency = FUEL_EFFICIENCY[vehicleType] || FUEL_EFFICIENCY.default;
    const fuelVolume = distanceKm / fuelEfficiency;
    const fuelCost = Math.round(fuelVolume * fuelPrice);

    // 高速代（既に記録されている場合はそれを使用）
    const tollCost = dispatch.toll_fee || 0;

    // ドライバー人件費（按分計算）
    let driverCost = 0;
    if (options?.includeDriverCost !== false && dispatch.driver_id) {
        // 月間の人件費を取得し、時間で按分
        const driverCostResult = await pool.query(`
            SELECT
                total_labor_cost,
                total_working_hours
            FROM driver_monthly_costs
            WHERE driver_id = $1 AND cost_month = DATE_TRUNC('month', $2::date)
        `, [dispatch.driver_id, dispatch.scheduled_start]);

        if (driverCostResult.rows.length > 0) {
            const { total_labor_cost, total_working_hours } = driverCostResult.rows[0];
            if (total_working_hours > 0) {
                const hourlyRate = parseFloat(total_labor_cost) / parseFloat(total_working_hours);
                driverCost = Math.round(hourlyRate * operatingHours);
            }
        } else {
            // 標準的な時給で計算（時給2,000円として）
            driverCost = Math.round(2000 * operatingHours);
        }
    }

    // 車両費（按分計算）
    let vehicleCost = 0;
    if (options?.includeVehicleCost !== false && dispatch.vehicle_id) {
        const vehicleCostResult = await pool.query(`
            SELECT
                total_cost,
                total_distance_km
            FROM vehicle_monthly_costs
            WHERE vehicle_id = $1 AND cost_month = DATE_TRUNC('month', $2::date)
        `, [dispatch.vehicle_id, dispatch.scheduled_start]);

        if (vehicleCostResult.rows.length > 0) {
            const { total_cost, total_distance_km } = vehicleCostResult.rows[0];
            if (total_distance_km > 0) {
                const costPerKm = parseFloat(total_cost) / parseFloat(total_distance_km);
                vehicleCost = Math.round(costPerKm * distanceKm);
            }
        } else {
            // 標準的なkm単価で計算（50円/km）
            vehicleCost = Math.round(50 * distanceKm);
        }
    }

    const totalCost = fuelCost + tollCost + driverCost + vehicleCost;
    const revenue = parseFloat(dispatch.revenue) || 0;
    const profit = revenue - totalCost;
    const profitRate = revenue > 0 ? (profit / revenue) * 100 : 0;

    return {
        fuelCost,
        tollCost,
        driverCost,
        vehicleCost,
        totalCost,
        revenue,
        profit,
        profitRate: Math.round(profitRate * 10) / 10
    };
}

/**
 * 運行原価を保存
 */
export async function saveDispatchProfitLoss(
    dispatchId: number,
    companyId: number,
    fuelPrice?: number
): Promise<void> {
    const costs = await calculateDispatchCost(dispatchId, { fuelPrice });

    // 運行情報取得
    const dispatchResult = await pool.query(`
        SELECT
            da.order_id,
            da.actual_distance,
            EXTRACT(EPOCH FROM (da.actual_end - da.actual_start)) / 3600 AS operating_hours
        FROM dispatch_assignments da
        WHERE da.id = $1
    `, [dispatchId]);

    const dispatch = dispatchResult.rows[0];

    await pool.query(`
        INSERT INTO dispatch_profit_loss (
            company_id, dispatch_id, order_id,
            revenue, fuel_cost, toll_cost, driver_cost, vehicle_cost,
            distance_km, operating_hours
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        ON CONFLICT (dispatch_id)
        DO UPDATE SET
            revenue = EXCLUDED.revenue,
            fuel_cost = EXCLUDED.fuel_cost,
            toll_cost = EXCLUDED.toll_cost,
            driver_cost = EXCLUDED.driver_cost,
            vehicle_cost = EXCLUDED.vehicle_cost,
            distance_km = EXCLUDED.distance_km,
            operating_hours = EXCLUDED.operating_hours,
            calculated_at = NOW()
    `, [
        companyId,
        dispatchId,
        dispatch.order_id,
        costs.revenue,
        costs.fuelCost,
        costs.tollCost,
        costs.driverCost,
        costs.vehicleCost,
        dispatch.actual_distance || 0,
        dispatch.operating_hours || 0
    ]);
}

/**
 * 月次損益サマリーを計算・保存
 */
export async function calculateMonthlySummary(
    companyId: number,
    month: string  // 'YYYY-MM-01'形式
): Promise<void> {
    // 売上集計
    const revenueResult = await pool.query(`
        SELECT
            COALESCE(SUM(i.total_amount), 0) AS total_revenue
        FROM invoices i
        WHERE i.company_id = $1
          AND DATE_TRUNC('month', i.invoice_date) = $2::date
          AND i.status != 'cancelled'
    `, [companyId, month]);

    const totalRevenue = parseFloat(revenueResult.rows[0].total_revenue) || 0;

    // 変動費集計（運行ごとの燃料・高速代）
    const variableCostResult = await pool.query(`
        SELECT
            COALESCE(SUM(dpl.fuel_cost), 0) AS fuel_cost,
            COALESCE(SUM(dpl.toll_cost), 0) AS toll_cost,
            COALESCE(SUM(dpl.driver_cost), 0) AS driver_variable_cost
        FROM dispatch_profit_loss dpl
        JOIN dispatch_assignments da ON dpl.dispatch_id = da.id
        WHERE dpl.company_id = $1
          AND DATE_TRUNC('month', da.scheduled_start) = $2::date
    `, [companyId, month]);

    const { fuel_cost, toll_cost, driver_variable_cost } = variableCostResult.rows[0];
    const totalVariableCost = parseFloat(fuel_cost) + parseFloat(toll_cost) + parseFloat(driver_variable_cost);

    // 車両固定費
    const vehicleFixedResult = await pool.query(`
        SELECT COALESCE(SUM(total_cost), 0) AS vehicle_fixed_cost
        FROM vehicle_monthly_costs
        WHERE company_id = $1 AND cost_month = $2::date
    `, [companyId, month]);
    const vehicleFixedCost = parseFloat(vehicleFixedResult.rows[0].vehicle_fixed_cost) || 0;

    // ドライバー固定費（基本給部分）
    const driverFixedResult = await pool.query(`
        SELECT COALESCE(SUM(base_salary + health_insurance + pension + employment_insurance + workers_comp), 0) AS driver_fixed_cost
        FROM driver_monthly_costs
        WHERE company_id = $1 AND cost_month = $2::date
    `, [companyId, month]);
    const driverFixedCost = parseFloat(driverFixedResult.rows[0].driver_fixed_cost) || 0;

    // 管理固定費
    const adminFixedResult = await pool.query(`
        SELECT COALESCE(total_fixed_cost, 0) AS admin_fixed_cost
        FROM company_monthly_fixed_costs
        WHERE company_id = $1 AND cost_month = $2::date
    `, [companyId, month]);
    const adminFixedCost = parseFloat(adminFixedResult.rows[0]?.admin_fixed_cost) || 0;

    const totalFixedCost = vehicleFixedCost + driverFixedCost + adminFixedCost;

    // KPI計算
    const kpiResult = await pool.query(`
        SELECT
            COUNT(DISTINCT v.id) AS vehicle_count,
            COUNT(DISTINCT da.driver_id) AS driver_count,
            COUNT(da.id) AS dispatch_count,
            COALESCE(SUM(da.actual_distance), 0) AS total_distance_km
        FROM vehicles v
        LEFT JOIN dispatch_assignments da ON v.id = da.vehicle_id
            AND DATE_TRUNC('month', da.scheduled_start) = $2::date
            AND da.status = 'completed'
        WHERE v.company_id = $1 AND v.is_active = true
    `, [companyId, month]);

    const kpi = kpiResult.rows[0];
    const vehicleCount = parseInt(kpi.vehicle_count) || 1;
    const driverCount = parseInt(kpi.driver_count) || 1;
    const dispatchCount = parseInt(kpi.dispatch_count) || 0;
    const totalDistanceKm = parseFloat(kpi.total_distance_km) || 0;

    // 損益分岐点計算
    // 損益分岐点売上 = 固定費 / (1 - 変動費率)
    const variableRatio = totalRevenue > 0 ? totalVariableCost / totalRevenue : 0.5;
    const breakevenRevenue = variableRatio < 1 ? totalFixedCost / (1 - variableRatio) : totalFixedCost * 2;
    const safetyMarginRate = totalRevenue > 0 ? ((totalRevenue - breakevenRevenue) / totalRevenue) * 100 : 0;

    // 保存
    await pool.query(`
        INSERT INTO monthly_profit_summary (
            company_id, summary_month,
            total_revenue, transport_revenue,
            total_variable_cost, fuel_cost, toll_cost, driver_variable_cost,
            total_fixed_cost, vehicle_fixed_cost, driver_fixed_cost, admin_fixed_cost,
            vehicle_count, driver_count, dispatch_count, total_distance_km,
            average_revenue_per_vehicle, average_revenue_per_km,
            breakeven_revenue, safety_margin_rate
        ) VALUES ($1, $2, $3, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19)
        ON CONFLICT (company_id, summary_month)
        DO UPDATE SET
            total_revenue = EXCLUDED.total_revenue,
            transport_revenue = EXCLUDED.transport_revenue,
            total_variable_cost = EXCLUDED.total_variable_cost,
            fuel_cost = EXCLUDED.fuel_cost,
            toll_cost = EXCLUDED.toll_cost,
            driver_variable_cost = EXCLUDED.driver_variable_cost,
            total_fixed_cost = EXCLUDED.total_fixed_cost,
            vehicle_fixed_cost = EXCLUDED.vehicle_fixed_cost,
            driver_fixed_cost = EXCLUDED.driver_fixed_cost,
            admin_fixed_cost = EXCLUDED.admin_fixed_cost,
            vehicle_count = EXCLUDED.vehicle_count,
            driver_count = EXCLUDED.driver_count,
            dispatch_count = EXCLUDED.dispatch_count,
            total_distance_km = EXCLUDED.total_distance_km,
            average_revenue_per_vehicle = EXCLUDED.average_revenue_per_vehicle,
            average_revenue_per_km = EXCLUDED.average_revenue_per_km,
            breakeven_revenue = EXCLUDED.breakeven_revenue,
            safety_margin_rate = EXCLUDED.safety_margin_rate,
            calculated_at = NOW()
    `, [
        companyId,
        month,
        totalRevenue,
        totalVariableCost,
        parseFloat(fuel_cost),
        parseFloat(toll_cost),
        parseFloat(driver_variable_cost),
        totalFixedCost,
        vehicleFixedCost,
        driverFixedCost,
        adminFixedCost,
        vehicleCount,
        driverCount,
        dispatchCount,
        totalDistanceKm,
        vehicleCount > 0 ? totalRevenue / vehicleCount : 0,
        totalDistanceKm > 0 ? totalRevenue / totalDistanceKm : 0,
        breakevenRevenue,
        safetyMarginRate
    ]);
}

/**
 * 損益分岐点分析
 */
export async function calculateBreakevenAnalysis(
    companyId: number,
    month: string
): Promise<{
    fixedCost: number;
    variableCostRatio: number;
    breakevenRevenue: number;
    currentRevenue: number;
    safetyMargin: number;
    safetyMarginRate: number;
    operatingLeverage: number;
}> {
    const result = await pool.query(`
        SELECT * FROM monthly_profit_summary
        WHERE company_id = $1 AND summary_month = $2::date
    `, [companyId, month]);

    if (result.rows.length === 0) {
        return {
            fixedCost: 0,
            variableCostRatio: 0,
            breakevenRevenue: 0,
            currentRevenue: 0,
            safetyMargin: 0,
            safetyMarginRate: 0,
            operatingLeverage: 0
        };
    }

    const summary = result.rows[0];
    const totalRevenue = parseFloat(summary.total_revenue) || 0;
    const totalVariableCost = parseFloat(summary.total_variable_cost) || 0;
    const totalFixedCost = parseFloat(summary.total_fixed_cost) || 0;

    const variableCostRatio = totalRevenue > 0 ? totalVariableCost / totalRevenue : 0;
    const contributionMarginRatio = 1 - variableCostRatio;
    const breakevenRevenue = contributionMarginRatio > 0 ? totalFixedCost / contributionMarginRatio : 0;
    const safetyMargin = totalRevenue - breakevenRevenue;
    const safetyMarginRate = totalRevenue > 0 ? (safetyMargin / totalRevenue) * 100 : 0;

    // 営業レバレッジ = 限界利益 / 営業利益
    const contributionMargin = totalRevenue - totalVariableCost;
    const operatingProfit = contributionMargin - totalFixedCost;
    const operatingLeverage = operatingProfit > 0 ? contributionMargin / operatingProfit : 0;

    return {
        fixedCost: totalFixedCost,
        variableCostRatio: Math.round(variableCostRatio * 1000) / 10,
        breakevenRevenue: Math.round(breakevenRevenue),
        currentRevenue: totalRevenue,
        safetyMargin: Math.round(safetyMargin),
        safetyMarginRate: Math.round(safetyMarginRate * 10) / 10,
        operatingLeverage: Math.round(operatingLeverage * 100) / 100
    };
}

/**
 * 車両別収益性ランキング
 */
export async function getVehicleProfitRanking(
    companyId: number,
    month: string,
    limit: number = 10
): Promise<Array<{
    vehicleId: number;
    vehicleNumber: string;
    vehicleType: string;
    revenue: number;
    cost: number;
    profit: number;
    profitRate: number;
    distanceKm: number;
    revenuePerKm: number;
}>> {
    const result = await pool.query(`
        SELECT * FROM vehicle_monthly_profit
        WHERE company_id = $1 AND cost_month = $2::date
        ORDER BY profit DESC
        LIMIT $3
    `, [companyId, month, limit]);

    return result.rows.map(row => ({
        vehicleId: row.vehicle_id,
        vehicleNumber: row.vehicle_number,
        vehicleType: row.vehicle_type,
        revenue: parseFloat(row.revenue) || 0,
        cost: parseFloat(row.cost) || 0,
        profit: parseFloat(row.profit) || 0,
        profitRate: parseFloat(row.profit_rate) || 0,
        distanceKm: parseFloat(row.total_distance_km) || 0,
        revenuePerKm: parseFloat(row.total_distance_km) > 0 ?
            parseFloat(row.revenue) / parseFloat(row.total_distance_km) : 0
    }));
}

/**
 * ドライバー別収益性ランキング
 */
export async function getDriverProfitRanking(
    companyId: number,
    month: string,
    limit: number = 10
): Promise<Array<{
    driverId: number;
    driverName: string;
    revenue: number;
    cost: number;
    profit: number;
    profitRate: number;
    workingDays: number;
    revenuePerDay: number;
}>> {
    const result = await pool.query(`
        SELECT * FROM driver_monthly_profit
        WHERE company_id = $1 AND cost_month = $2::date
        ORDER BY profit DESC
        LIMIT $3
    `, [companyId, month, limit]);

    return result.rows.map(row => ({
        driverId: row.driver_id,
        driverName: row.driver_name,
        revenue: parseFloat(row.revenue) || 0,
        cost: parseFloat(row.cost) || 0,
        profit: parseFloat(row.profit) || 0,
        profitRate: parseFloat(row.profit_rate) || 0,
        workingDays: parseInt(row.working_days) || 0,
        revenuePerDay: parseFloat(row.revenue_per_day) || 0
    }));
}
