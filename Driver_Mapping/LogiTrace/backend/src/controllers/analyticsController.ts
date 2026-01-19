/**
 * Analytics Controller - 経営分析・原価管理
 */

import { Request, Response } from 'express';
import { pool } from '../index';
import {
    calculateMonthlySummary,
    calculateBreakevenAnalysis,
    getVehicleProfitRanking,
    getDriverProfitRanking,
    saveDispatchProfitLoss
} from '../services/costCalculationService';

interface AuthRequest extends Request {
    user?: { id: number; companyId: number; role: string };
}

/**
 * 月次損益サマリー取得
 */
export const getMonthlySummary = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.query.companyId;
        const { year } = req.query;

        let query = `
            SELECT * FROM monthly_profit_summary
            WHERE company_id = $1
        `;
        const params: any[] = [companyId];

        if (year) {
            params.push(year);
            query += ` AND EXTRACT(YEAR FROM summary_month) = $${params.length}`;
        }

        query += ` ORDER BY summary_month DESC`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Failed to get monthly summary:', error);
        res.status(500).json({ error: '月次サマリーの取得に失敗しました' });
    }
};

/**
 * 月次サマリー再計算
 */
export const recalculateMonthlySummary = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.body.companyId;
        const { month } = req.body;  // 'YYYY-MM-01'形式

        if (!month) {
            return res.status(400).json({ error: '月を指定してください' });
        }

        await calculateMonthlySummary(companyId, month);

        const result = await pool.query(`
            SELECT * FROM monthly_profit_summary
            WHERE company_id = $1 AND summary_month = $2::date
        `, [companyId, month]);

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Failed to recalculate summary:', error);
        res.status(500).json({ error: '再計算に失敗しました' });
    }
};

/**
 * 損益分岐点分析
 */
export const getBreakevenAnalysis = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.query.companyId;
        const month = req.query.month as string || new Date().toISOString().slice(0, 7) + '-01';

        const analysis = await calculateBreakevenAnalysis(companyId as number, month);
        res.json(analysis);
    } catch (error) {
        console.error('Failed to get breakeven analysis:', error);
        res.status(500).json({ error: '損益分岐点分析の取得に失敗しました' });
    }
};

/**
 * 車両別損益取得
 */
export const getVehicleProfit = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.query.companyId;
        const { month, limit = 20 } = req.query;

        const targetMonth = month as string || new Date().toISOString().slice(0, 7) + '-01';

        const result = await pool.query(`
            SELECT * FROM vehicle_monthly_profit
            WHERE company_id = $1 AND cost_month = $2::date
            ORDER BY profit DESC
            LIMIT $3
        `, [companyId, targetMonth, limit]);

        res.json(result.rows);
    } catch (error) {
        console.error('Failed to get vehicle profit:', error);
        res.status(500).json({ error: '車両別損益の取得に失敗しました' });
    }
};

/**
 * ドライバー別損益取得
 */
export const getDriverProfit = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.query.companyId;
        const { month, limit = 20 } = req.query;

        const targetMonth = month as string || new Date().toISOString().slice(0, 7) + '-01';

        const result = await pool.query(`
            SELECT * FROM driver_monthly_profit
            WHERE company_id = $1 AND cost_month = $2::date
            ORDER BY profit DESC
            LIMIT $3
        `, [companyId, targetMonth, limit]);

        res.json(result.rows);
    } catch (error) {
        console.error('Failed to get driver profit:', error);
        res.status(500).json({ error: 'ドライバー別損益の取得に失敗しました' });
    }
};

/**
 * 荷主別損益取得
 */
export const getShipperProfit = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.query.companyId;
        const { month } = req.query;

        const targetMonth = month as string || new Date().toISOString().slice(0, 7) + '-01';

        const result = await pool.query(`
            SELECT * FROM shipper_monthly_profit
            WHERE company_id = $1 AND month = $2::date
            ORDER BY total_profit DESC
        `, [companyId, targetMonth]);

        res.json(result.rows);
    } catch (error) {
        console.error('Failed to get shipper profit:', error);
        res.status(500).json({ error: '荷主別損益の取得に失敗しました' });
    }
};

/**
 * 稼働率取得
 */
export const getUtilization = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.query.companyId;
        const { month } = req.query;

        const targetMonth = month as string || new Date().toISOString().slice(0, 7) + '-01';

        const result = await pool.query(`
            SELECT * FROM vehicle_utilization
            WHERE company_id = $1 AND month = $2::date
            ORDER BY utilization_rate DESC
        `, [companyId, targetMonth]);

        res.json(result.rows);
    } catch (error) {
        console.error('Failed to get utilization:', error);
        res.status(500).json({ error: '稼働率の取得に失敗しました' });
    }
};

/**
 * 車両コスト一覧取得
 */
export const getVehicleCosts = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.query.companyId;
        const { vehicleId, month } = req.query;

        let query = `
            SELECT vmc.*, v.vehicle_number, v.vehicle_type
            FROM vehicle_monthly_costs vmc
            JOIN vehicles v ON vmc.vehicle_id = v.id
            WHERE vmc.company_id = $1
        `;
        const params: any[] = [companyId];

        if (vehicleId) {
            params.push(vehicleId);
            query += ` AND vmc.vehicle_id = $${params.length}`;
        }

        if (month) {
            params.push(month);
            query += ` AND vmc.cost_month = $${params.length}::date`;
        }

        query += ` ORDER BY vmc.cost_month DESC, v.vehicle_number`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Failed to get vehicle costs:', error);
        res.status(500).json({ error: '車両コストの取得に失敗しました' });
    }
};

/**
 * 車両コスト登録・更新
 */
export const upsertVehicleCost = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.body.companyId;

        const {
            vehicleId, costMonth,
            fuelCost, fuelVolumeLiters, fuelUnitPrice,
            tollCost, maintenanceCost, tireCost,
            insuranceCost, taxCost, inspectionCost,
            depreciationCost, leaseCost, parkingCost, otherCost,
            operatingDays, totalDistanceKm, totalOperatingHours,
            notes
        } = req.body;

        const result = await pool.query(`
            INSERT INTO vehicle_monthly_costs (
                company_id, vehicle_id, cost_month,
                fuel_cost, fuel_volume_liters, fuel_unit_price,
                toll_cost, maintenance_cost, tire_cost,
                insurance_cost, tax_cost, inspection_cost,
                depreciation_cost, lease_cost, parking_cost, other_cost,
                operating_days, total_distance_km, total_operating_hours,
                notes
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20)
            ON CONFLICT (vehicle_id, cost_month)
            DO UPDATE SET
                fuel_cost = EXCLUDED.fuel_cost,
                fuel_volume_liters = EXCLUDED.fuel_volume_liters,
                fuel_unit_price = EXCLUDED.fuel_unit_price,
                toll_cost = EXCLUDED.toll_cost,
                maintenance_cost = EXCLUDED.maintenance_cost,
                tire_cost = EXCLUDED.tire_cost,
                insurance_cost = EXCLUDED.insurance_cost,
                tax_cost = EXCLUDED.tax_cost,
                inspection_cost = EXCLUDED.inspection_cost,
                depreciation_cost = EXCLUDED.depreciation_cost,
                lease_cost = EXCLUDED.lease_cost,
                parking_cost = EXCLUDED.parking_cost,
                other_cost = EXCLUDED.other_cost,
                operating_days = EXCLUDED.operating_days,
                total_distance_km = EXCLUDED.total_distance_km,
                total_operating_hours = EXCLUDED.total_operating_hours,
                notes = EXCLUDED.notes,
                updated_at = NOW()
            RETURNING *
        `, [
            companyId, vehicleId, costMonth,
            fuelCost || 0, fuelVolumeLiters || 0, fuelUnitPrice || 0,
            tollCost || 0, maintenanceCost || 0, tireCost || 0,
            insuranceCost || 0, taxCost || 0, inspectionCost || 0,
            depreciationCost || 0, leaseCost || 0, parkingCost || 0, otherCost || 0,
            operatingDays || 0, totalDistanceKm || 0, totalOperatingHours || 0,
            notes
        ]);

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Failed to upsert vehicle cost:', error);
        res.status(500).json({ error: '車両コストの保存に失敗しました' });
    }
};

/**
 * ドライバーコスト一覧取得
 */
export const getDriverCosts = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.query.companyId;
        const { driverId, month } = req.query;

        let query = `
            SELECT dmc.*, u.name AS driver_name
            FROM driver_monthly_costs dmc
            JOIN users u ON dmc.driver_id = u.id
            WHERE dmc.company_id = $1
        `;
        const params: any[] = [companyId];

        if (driverId) {
            params.push(driverId);
            query += ` AND dmc.driver_id = $${params.length}`;
        }

        if (month) {
            params.push(month);
            query += ` AND dmc.cost_month = $${params.length}::date`;
        }

        query += ` ORDER BY dmc.cost_month DESC, u.name`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Failed to get driver costs:', error);
        res.status(500).json({ error: 'ドライバーコストの取得に失敗しました' });
    }
};

/**
 * ドライバーコスト登録・更新
 */
export const upsertDriverCost = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.body.companyId;

        const {
            driverId, costMonth,
            baseSalary, overtimePay, allowances, bonus,
            healthInsurance, pension, employmentInsurance, workersComp,
            uniformCost, trainingCost, otherCost,
            workingDays, totalWorkingHours, overtimeHours, totalDistanceKm,
            notes
        } = req.body;

        const result = await pool.query(`
            INSERT INTO driver_monthly_costs (
                company_id, driver_id, cost_month,
                base_salary, overtime_pay, allowances, bonus,
                health_insurance, pension, employment_insurance, workers_comp,
                uniform_cost, training_cost, other_cost,
                working_days, total_working_hours, overtime_hours, total_distance_km,
                notes
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19)
            ON CONFLICT (driver_id, cost_month)
            DO UPDATE SET
                base_salary = EXCLUDED.base_salary,
                overtime_pay = EXCLUDED.overtime_pay,
                allowances = EXCLUDED.allowances,
                bonus = EXCLUDED.bonus,
                health_insurance = EXCLUDED.health_insurance,
                pension = EXCLUDED.pension,
                employment_insurance = EXCLUDED.employment_insurance,
                workers_comp = EXCLUDED.workers_comp,
                uniform_cost = EXCLUDED.uniform_cost,
                training_cost = EXCLUDED.training_cost,
                other_cost = EXCLUDED.other_cost,
                working_days = EXCLUDED.working_days,
                total_working_hours = EXCLUDED.total_working_hours,
                overtime_hours = EXCLUDED.overtime_hours,
                total_distance_km = EXCLUDED.total_distance_km,
                notes = EXCLUDED.notes,
                updated_at = NOW()
            RETURNING *
        `, [
            companyId, driverId, costMonth,
            baseSalary || 0, overtimePay || 0, allowances || 0, bonus || 0,
            healthInsurance || 0, pension || 0, employmentInsurance || 0, workersComp || 0,
            uniformCost || 0, trainingCost || 0, otherCost || 0,
            workingDays || 0, totalWorkingHours || 0, overtimeHours || 0, totalDistanceKm || 0,
            notes
        ]);

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Failed to upsert driver cost:', error);
        res.status(500).json({ error: 'ドライバーコストの保存に失敗しました' });
    }
};

/**
 * 会社固定費取得
 */
export const getFixedCosts = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.query.companyId;
        const { month } = req.query;

        let query = `
            SELECT * FROM company_monthly_fixed_costs
            WHERE company_id = $1
        `;
        const params: any[] = [companyId];

        if (month) {
            params.push(month);
            query += ` AND cost_month = $${params.length}::date`;
        }

        query += ` ORDER BY cost_month DESC`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Failed to get fixed costs:', error);
        res.status(500).json({ error: '固定費の取得に失敗しました' });
    }
};

/**
 * 会社固定費登録・更新
 */
export const upsertFixedCost = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.body.companyId;

        const {
            costMonth,
            rentCost, utilitiesCost, communicationCost,
            adminSalary, officeSupplies, systemCost,
            liabilityInsurance, corporateTax,
            professionalFees, otherFixedCost,
            notes
        } = req.body;

        const result = await pool.query(`
            INSERT INTO company_monthly_fixed_costs (
                company_id, cost_month,
                rent_cost, utilities_cost, communication_cost,
                admin_salary, office_supplies, system_cost,
                liability_insurance, corporate_tax,
                professional_fees, other_fixed_cost,
                notes
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
            ON CONFLICT (company_id, cost_month)
            DO UPDATE SET
                rent_cost = EXCLUDED.rent_cost,
                utilities_cost = EXCLUDED.utilities_cost,
                communication_cost = EXCLUDED.communication_cost,
                admin_salary = EXCLUDED.admin_salary,
                office_supplies = EXCLUDED.office_supplies,
                system_cost = EXCLUDED.system_cost,
                liability_insurance = EXCLUDED.liability_insurance,
                corporate_tax = EXCLUDED.corporate_tax,
                professional_fees = EXCLUDED.professional_fees,
                other_fixed_cost = EXCLUDED.other_fixed_cost,
                notes = EXCLUDED.notes,
                updated_at = NOW()
            RETURNING *
        `, [
            companyId, costMonth,
            rentCost || 0, utilitiesCost || 0, communicationCost || 0,
            adminSalary || 0, officeSupplies || 0, systemCost || 0,
            liabilityInsurance || 0, corporateTax || 0,
            professionalFees || 0, otherFixedCost || 0,
            notes
        ]);

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Failed to upsert fixed cost:', error);
        res.status(500).json({ error: '固定費の保存に失敗しました' });
    }
};

/**
 * 経営ダッシュボードデータ取得
 */
export const getDashboardData = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.user?.companyId || req.query.companyId;
        const currentMonth = new Date().toISOString().slice(0, 7) + '-01';
        const lastMonth = new Date(new Date().setMonth(new Date().getMonth() - 1)).toISOString().slice(0, 7) + '-01';

        // 今月のサマリー
        const currentSummaryResult = await pool.query(`
            SELECT * FROM monthly_profit_summary
            WHERE company_id = $1 AND summary_month = $2::date
        `, [companyId, currentMonth]);

        // 先月のサマリー（比較用）
        const lastSummaryResult = await pool.query(`
            SELECT * FROM monthly_profit_summary
            WHERE company_id = $1 AND summary_month = $2::date
        `, [companyId, lastMonth]);

        // 年間推移（12ヶ月分）
        const yearlyTrendResult = await pool.query(`
            SELECT * FROM monthly_profit_summary
            WHERE company_id = $1
              AND summary_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '11 months')
            ORDER BY summary_month ASC
        `, [companyId]);

        // 車両別ランキング（TOP5）
        const vehicleRanking = await getVehicleProfitRanking(companyId as number, currentMonth, 5);

        // ドライバー別ランキング（TOP5）
        const driverRanking = await getDriverProfitRanking(companyId as number, currentMonth, 5);

        // 損益分岐点分析
        const breakevenAnalysis = await calculateBreakevenAnalysis(companyId as number, currentMonth);

        const current = currentSummaryResult.rows[0] || {};
        const last = lastSummaryResult.rows[0] || {};

        res.json({
            currentMonth: {
                revenue: parseFloat(current.total_revenue) || 0,
                cost: (parseFloat(current.total_variable_cost) || 0) + (parseFloat(current.total_fixed_cost) || 0),
                profit: parseFloat(current.operating_profit) || 0,
                profitRate: parseFloat(current.operating_profit_rate) || 0,
                dispatchCount: parseInt(current.dispatch_count) || 0,
                distanceKm: parseFloat(current.total_distance_km) || 0
            },
            comparison: {
                revenueChange: last.total_revenue ?
                    ((parseFloat(current.total_revenue) - parseFloat(last.total_revenue)) / parseFloat(last.total_revenue)) * 100 : 0,
                profitChange: last.operating_profit ?
                    ((parseFloat(current.operating_profit) - parseFloat(last.operating_profit)) / parseFloat(last.operating_profit)) * 100 : 0
            },
            yearlyTrend: yearlyTrendResult.rows,
            vehicleRanking,
            driverRanking,
            breakevenAnalysis
        });
    } catch (error) {
        console.error('Failed to get dashboard data:', error);
        res.status(500).json({ error: 'ダッシュボードデータの取得に失敗しました' });
    }
};
