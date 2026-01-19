-- =====================================================
-- Phase 4: 経営分析・原価計算 (Cost Analysis)
-- 国土交通省「トラック運送業の標準的運賃」指針準拠
-- =====================================================

-- 車両別月次コスト
CREATE TABLE IF NOT EXISTS vehicle_monthly_costs (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    vehicle_id INTEGER REFERENCES vehicles(id) ON DELETE CASCADE,
    cost_month DATE NOT NULL,  -- 月初の日付（例: 2026-01-01）

    -- 燃料費
    fuel_cost DECIMAL(12,2) DEFAULT 0,
    fuel_volume_liters DECIMAL(10,2) DEFAULT 0,
    fuel_unit_price DECIMAL(8,2) DEFAULT 0,

    -- 高速代
    toll_cost DECIMAL(12,2) DEFAULT 0,

    -- 車両維持費
    maintenance_cost DECIMAL(12,2) DEFAULT 0,  -- 整備・修理費
    tire_cost DECIMAL(12,2) DEFAULT 0,  -- タイヤ費
    insurance_cost DECIMAL(12,2) DEFAULT 0,  -- 保険料（月割）
    tax_cost DECIMAL(12,2) DEFAULT 0,  -- 自動車税・重量税（月割）
    inspection_cost DECIMAL(12,2) DEFAULT 0,  -- 車検費用（月割）

    -- 減価償却費
    depreciation_cost DECIMAL(12,2) DEFAULT 0,

    -- リース費用
    lease_cost DECIMAL(12,2) DEFAULT 0,

    -- その他費用
    parking_cost DECIMAL(12,2) DEFAULT 0,  -- 駐車場代
    other_cost DECIMAL(12,2) DEFAULT 0,

    -- 稼働データ
    operating_days INTEGER DEFAULT 0,
    total_distance_km DECIMAL(12,2) DEFAULT 0,
    total_operating_hours DECIMAL(10,2) DEFAULT 0,

    -- 計算済み合計
    total_cost DECIMAL(12,2) GENERATED ALWAYS AS (
        fuel_cost + toll_cost + maintenance_cost + tire_cost +
        insurance_cost + tax_cost + inspection_cost +
        depreciation_cost + lease_cost + parking_cost + other_cost
    ) STORED,

    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    UNIQUE(vehicle_id, cost_month)
);

-- ドライバー別月次コスト
CREATE TABLE IF NOT EXISTS driver_monthly_costs (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    driver_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    cost_month DATE NOT NULL,

    -- 人件費
    base_salary DECIMAL(12,2) DEFAULT 0,  -- 基本給
    overtime_pay DECIMAL(12,2) DEFAULT 0,  -- 時間外手当
    allowances DECIMAL(12,2) DEFAULT 0,  -- 各種手当（運行・無事故等）
    bonus DECIMAL(12,2) DEFAULT 0,  -- 賞与（月割）

    -- 法定福利費
    health_insurance DECIMAL(12,2) DEFAULT 0,  -- 健康保険
    pension DECIMAL(12,2) DEFAULT 0,  -- 厚生年金
    employment_insurance DECIMAL(12,2) DEFAULT 0,  -- 雇用保険
    workers_comp DECIMAL(12,2) DEFAULT 0,  -- 労災保険

    -- その他経費
    uniform_cost DECIMAL(12,2) DEFAULT 0,  -- 制服・作業着
    training_cost DECIMAL(12,2) DEFAULT 0,  -- 教育・研修費
    other_cost DECIMAL(12,2) DEFAULT 0,

    -- 稼働データ
    working_days INTEGER DEFAULT 0,
    total_working_hours DECIMAL(10,2) DEFAULT 0,
    overtime_hours DECIMAL(10,2) DEFAULT 0,
    total_distance_km DECIMAL(12,2) DEFAULT 0,

    -- 計算済み合計
    total_labor_cost DECIMAL(12,2) GENERATED ALWAYS AS (
        base_salary + overtime_pay + allowances + bonus +
        health_insurance + pension + employment_insurance + workers_comp +
        uniform_cost + training_cost + other_cost
    ) STORED,

    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    UNIQUE(driver_id, cost_month)
);

-- 会社全体の月次固定費
CREATE TABLE IF NOT EXISTS company_monthly_fixed_costs (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    cost_month DATE NOT NULL,

    -- 施設費
    rent_cost DECIMAL(12,2) DEFAULT 0,  -- 事務所・車庫賃料
    utilities_cost DECIMAL(12,2) DEFAULT 0,  -- 光熱費
    communication_cost DECIMAL(12,2) DEFAULT 0,  -- 通信費

    -- 管理費
    admin_salary DECIMAL(12,2) DEFAULT 0,  -- 管理部門人件費
    office_supplies DECIMAL(12,2) DEFAULT 0,  -- 事務用品費
    system_cost DECIMAL(12,2) DEFAULT 0,  -- システム費（LogiTrace等）

    -- 保険・税金
    liability_insurance DECIMAL(12,2) DEFAULT 0,  -- 賠償責任保険
    corporate_tax DECIMAL(12,2) DEFAULT 0,  -- 法人税等（月割）

    -- その他
    professional_fees DECIMAL(12,2) DEFAULT 0,  -- 顧問料（税理士等）
    other_fixed_cost DECIMAL(12,2) DEFAULT 0,

    -- 計算済み合計
    total_fixed_cost DECIMAL(12,2) GENERATED ALWAYS AS (
        rent_cost + utilities_cost + communication_cost +
        admin_salary + office_supplies + system_cost +
        liability_insurance + corporate_tax +
        professional_fees + other_fixed_cost
    ) STORED,

    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    UNIQUE(company_id, cost_month)
);

-- 案件別収支（運行ごと）
CREATE TABLE IF NOT EXISTS dispatch_profit_loss (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    dispatch_id INTEGER REFERENCES dispatch_assignments(id) ON DELETE CASCADE,
    order_id INTEGER REFERENCES orders(id) ON DELETE SET NULL,

    -- 売上
    revenue DECIMAL(12,2) DEFAULT 0,  -- 請求金額

    -- 直接費
    fuel_cost DECIMAL(12,2) DEFAULT 0,
    toll_cost DECIMAL(12,2) DEFAULT 0,
    driver_cost DECIMAL(12,2) DEFAULT 0,  -- 按分人件費
    vehicle_cost DECIMAL(12,2) DEFAULT 0,  -- 按分車両費

    -- 外注費
    subcontract_cost DECIMAL(12,2) DEFAULT 0,

    -- 計算項目
    direct_cost DECIMAL(12,2) GENERATED ALWAYS AS (
        fuel_cost + toll_cost + driver_cost + vehicle_cost + subcontract_cost
    ) STORED,
    gross_profit DECIMAL(12,2) GENERATED ALWAYS AS (
        revenue - (fuel_cost + toll_cost + driver_cost + vehicle_cost + subcontract_cost)
    ) STORED,
    gross_profit_rate DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE WHEN revenue > 0 THEN
            ((revenue - (fuel_cost + toll_cost + driver_cost + vehicle_cost + subcontract_cost)) / revenue) * 100
        ELSE 0 END
    ) STORED,

    -- 運行データ
    distance_km DECIMAL(10,2) DEFAULT 0,
    operating_hours DECIMAL(8,2) DEFAULT 0,

    calculated_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

-- 月次損益サマリー
CREATE TABLE IF NOT EXISTS monthly_profit_summary (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    summary_month DATE NOT NULL,

    -- 売上
    total_revenue DECIMAL(14,2) DEFAULT 0,
    transport_revenue DECIMAL(14,2) DEFAULT 0,  -- 運送収入
    other_revenue DECIMAL(14,2) DEFAULT 0,  -- その他収入

    -- 変動費
    total_variable_cost DECIMAL(14,2) DEFAULT 0,
    fuel_cost DECIMAL(14,2) DEFAULT 0,
    toll_cost DECIMAL(14,2) DEFAULT 0,
    driver_variable_cost DECIMAL(14,2) DEFAULT 0,  -- 時間外・手当

    -- 固定費
    total_fixed_cost DECIMAL(14,2) DEFAULT 0,
    vehicle_fixed_cost DECIMAL(14,2) DEFAULT 0,
    driver_fixed_cost DECIMAL(14,2) DEFAULT 0,
    admin_fixed_cost DECIMAL(14,2) DEFAULT 0,

    -- 利益
    gross_profit DECIMAL(14,2) GENERATED ALWAYS AS (
        total_revenue - total_variable_cost
    ) STORED,
    operating_profit DECIMAL(14,2) GENERATED ALWAYS AS (
        total_revenue - total_variable_cost - total_fixed_cost
    ) STORED,
    operating_profit_rate DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE WHEN total_revenue > 0 THEN
            ((total_revenue - total_variable_cost - total_fixed_cost) / total_revenue) * 100
        ELSE 0 END
    ) STORED,

    -- KPI
    vehicle_count INTEGER DEFAULT 0,
    driver_count INTEGER DEFAULT 0,
    dispatch_count INTEGER DEFAULT 0,
    total_distance_km DECIMAL(14,2) DEFAULT 0,
    average_revenue_per_vehicle DECIMAL(12,2) DEFAULT 0,
    average_revenue_per_km DECIMAL(8,2) DEFAULT 0,

    -- 損益分岐点
    breakeven_revenue DECIMAL(14,2) DEFAULT 0,
    safety_margin_rate DECIMAL(5,2) DEFAULT 0,

    calculated_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW(),

    UNIQUE(company_id, summary_month)
);

-- 車両別月次損益ビュー
CREATE OR REPLACE VIEW vehicle_monthly_profit AS
SELECT
    vmc.company_id,
    vmc.vehicle_id,
    v.vehicle_number,
    v.vehicle_type,
    vmc.cost_month,
    -- 売上（この車両による運行の請求額合計）
    COALESCE(rev.total_revenue, 0) AS revenue,
    -- コスト
    vmc.total_cost AS cost,
    -- 利益
    COALESCE(rev.total_revenue, 0) - vmc.total_cost AS profit,
    -- 利益率
    CASE WHEN COALESCE(rev.total_revenue, 0) > 0 THEN
        ((COALESCE(rev.total_revenue, 0) - vmc.total_cost) / COALESCE(rev.total_revenue, 0)) * 100
    ELSE 0 END AS profit_rate,
    -- 稼働データ
    vmc.operating_days,
    vmc.total_distance_km,
    -- KPI
    CASE WHEN vmc.total_distance_km > 0 THEN
        vmc.total_cost / vmc.total_distance_km
    ELSE 0 END AS cost_per_km
FROM vehicle_monthly_costs vmc
JOIN vehicles v ON vmc.vehicle_id = v.id
LEFT JOIN (
    SELECT
        da.vehicle_id,
        DATE_TRUNC('month', da.scheduled_start) AS month,
        SUM(dpl.revenue) AS total_revenue
    FROM dispatch_assignments da
    LEFT JOIN dispatch_profit_loss dpl ON da.id = dpl.dispatch_id
    WHERE da.status = 'completed'
    GROUP BY da.vehicle_id, DATE_TRUNC('month', da.scheduled_start)
) rev ON vmc.vehicle_id = rev.vehicle_id AND vmc.cost_month = rev.month;

-- ドライバー別月次損益ビュー
CREATE OR REPLACE VIEW driver_monthly_profit AS
SELECT
    dmc.company_id,
    dmc.driver_id,
    u.name AS driver_name,
    dmc.cost_month,
    -- 売上（このドライバーによる運行の請求額合計）
    COALESCE(rev.total_revenue, 0) AS revenue,
    -- コスト
    dmc.total_labor_cost AS cost,
    -- 利益
    COALESCE(rev.total_revenue, 0) - dmc.total_labor_cost AS profit,
    -- 利益率
    CASE WHEN COALESCE(rev.total_revenue, 0) > 0 THEN
        ((COALESCE(rev.total_revenue, 0) - dmc.total_labor_cost) / COALESCE(rev.total_revenue, 0)) * 100
    ELSE 0 END AS profit_rate,
    -- 稼働データ
    dmc.working_days,
    dmc.total_working_hours,
    dmc.total_distance_km,
    -- KPI
    CASE WHEN dmc.working_days > 0 THEN
        COALESCE(rev.total_revenue, 0) / dmc.working_days
    ELSE 0 END AS revenue_per_day
FROM driver_monthly_costs dmc
JOIN users u ON dmc.driver_id = u.id
LEFT JOIN (
    SELECT
        da.driver_id,
        DATE_TRUNC('month', da.scheduled_start) AS month,
        SUM(dpl.revenue) AS total_revenue
    FROM dispatch_assignments da
    LEFT JOIN dispatch_profit_loss dpl ON da.id = dpl.dispatch_id
    WHERE da.status = 'completed'
    GROUP BY da.driver_id, DATE_TRUNC('month', da.scheduled_start)
) rev ON dmc.driver_id = rev.driver_id AND dmc.cost_month = rev.month;

-- 荷主別月次損益ビュー
CREATE OR REPLACE VIEW shipper_monthly_profit AS
SELECT
    o.company_id,
    o.shipper_id,
    s.name AS shipper_name,
    DATE_TRUNC('month', da.scheduled_start) AS month,
    COUNT(DISTINCT da.id) AS dispatch_count,
    SUM(dpl.revenue) AS total_revenue,
    SUM(dpl.direct_cost) AS total_cost,
    SUM(dpl.gross_profit) AS total_profit,
    CASE WHEN SUM(dpl.revenue) > 0 THEN
        (SUM(dpl.gross_profit) / SUM(dpl.revenue)) * 100
    ELSE 0 END AS profit_rate,
    SUM(dpl.distance_km) AS total_distance_km
FROM dispatch_assignments da
JOIN orders o ON da.order_id = o.id
JOIN shippers s ON o.shipper_id = s.id
LEFT JOIN dispatch_profit_loss dpl ON da.id = dpl.dispatch_id
WHERE da.status = 'completed'
GROUP BY o.company_id, o.shipper_id, s.name, DATE_TRUNC('month', da.scheduled_start);

-- 稼働率ビュー
CREATE OR REPLACE VIEW vehicle_utilization AS
SELECT
    v.company_id,
    v.id AS vehicle_id,
    v.vehicle_number,
    DATE_TRUNC('month', da.scheduled_start) AS month,
    COUNT(DISTINCT DATE(da.scheduled_start)) AS operating_days,
    -- 月の営業日数（土日除く簡易計算、実際は祝日考慮必要）
    21 AS business_days,
    -- 稼働率
    (COUNT(DISTINCT DATE(da.scheduled_start))::DECIMAL / 21) * 100 AS utilization_rate,
    -- 運行回数
    COUNT(da.id) AS dispatch_count,
    -- 総走行距離
    COALESCE(SUM(da.actual_distance), 0) AS total_distance_km,
    -- 総稼働時間
    COALESCE(SUM(EXTRACT(EPOCH FROM (da.actual_end - da.actual_start)) / 3600), 0) AS total_hours
FROM vehicles v
LEFT JOIN dispatch_assignments da ON v.id = da.vehicle_id AND da.status = 'completed'
GROUP BY v.company_id, v.id, v.vehicle_number, DATE_TRUNC('month', da.scheduled_start);

-- インデックス
CREATE INDEX IF NOT EXISTS idx_vehicle_monthly_costs_vehicle ON vehicle_monthly_costs(vehicle_id, cost_month);
CREATE INDEX IF NOT EXISTS idx_vehicle_monthly_costs_company ON vehicle_monthly_costs(company_id, cost_month);
CREATE INDEX IF NOT EXISTS idx_driver_monthly_costs_driver ON driver_monthly_costs(driver_id, cost_month);
CREATE INDEX IF NOT EXISTS idx_driver_monthly_costs_company ON driver_monthly_costs(company_id, cost_month);
CREATE INDEX IF NOT EXISTS idx_dispatch_profit_loss_dispatch ON dispatch_profit_loss(dispatch_id);
CREATE INDEX IF NOT EXISTS idx_dispatch_profit_loss_company ON dispatch_profit_loss(company_id);
CREATE INDEX IF NOT EXISTS idx_monthly_profit_summary_company ON monthly_profit_summary(company_id, summary_month);

COMMENT ON TABLE vehicle_monthly_costs IS '車両別月次コスト - 国交省指針準拠';
COMMENT ON TABLE driver_monthly_costs IS 'ドライバー別月次コスト';
COMMENT ON TABLE company_monthly_fixed_costs IS '会社固定費';
COMMENT ON TABLE dispatch_profit_loss IS '案件別収支';
COMMENT ON TABLE monthly_profit_summary IS '月次損益サマリー';
