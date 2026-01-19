-- Migration: 006_labor_compliance.sql
-- 改善基準告示対応：拘束時間・運転時間・休息期間の管理

-- work_recordsに拘束時間・運転時間・休息期間カラム追加
ALTER TABLE work_records ADD COLUMN IF NOT EXISTS binding_time_minutes INTEGER;      -- 拘束時間（分）
ALTER TABLE work_records ADD COLUMN IF NOT EXISTS driving_time_minutes INTEGER;      -- 運転時間（分）
ALTER TABLE work_records ADD COLUMN IF NOT EXISTS rest_time_minutes INTEGER;         -- 休息期間（分）

-- 労務アラートテーブル
CREATE TABLE IF NOT EXISTS labor_alerts (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id),
    driver_id INTEGER REFERENCES users(id),
    alert_type VARCHAR(50) NOT NULL,  -- 'binding_time_daily', 'binding_time_monthly', 'driving_time_daily', 'driving_time_2day_avg', 'driving_time_2week_avg', 'rest_period', 'continuous_driving'
    alert_level VARCHAR(20) DEFAULT 'warning' CHECK (alert_level IN ('warning', 'violation', 'critical')),
    alert_date DATE NOT NULL,
    threshold_value INTEGER NOT NULL,  -- 閾値（分）
    actual_value INTEGER NOT NULL,     -- 実際の値（分）
    threshold_label VARCHAR(100),      -- 閾値の説明（例：'1日の拘束時間上限13時間'）
    description TEXT,                  -- アラート詳細説明
    work_record_ids INTEGER[],         -- 関連する運行記録ID（複数日にまたがる場合）
    acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_by INTEGER REFERENCES users(id),
    acknowledged_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_labor_alerts_company ON labor_alerts(company_id);
CREATE INDEX IF NOT EXISTS idx_labor_alerts_driver ON labor_alerts(driver_id);
CREATE INDEX IF NOT EXISTS idx_labor_alerts_date ON labor_alerts(alert_date);
CREATE INDEX IF NOT EXISTS idx_labor_alerts_type ON labor_alerts(alert_type);
CREATE INDEX IF NOT EXISTS idx_labor_alerts_unacknowledged ON labor_alerts(company_id, acknowledged) WHERE acknowledged = FALSE;

-- 労務コンプライアンス設定テーブル（会社・業種別の閾値設定）
CREATE TABLE IF NOT EXISTS labor_compliance_settings (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) UNIQUE,
    industry_type VARCHAR(50) DEFAULT 'trucking', -- 'trucking', 'taxi', 'bus'

    -- 拘束時間設定
    daily_binding_time_limit INTEGER DEFAULT 780,           -- 1日の拘束時間上限（分）デフォルト13時間
    daily_binding_time_extended INTEGER DEFAULT 960,        -- 延長時（分）デフォルト16時間
    extended_days_per_week INTEGER DEFAULT 2,               -- 週あたりの延長可能日数
    monthly_binding_time_limit INTEGER DEFAULT 17040,       -- 月間拘束時間上限（分）デフォルト284時間
    monthly_binding_time_agreement INTEGER DEFAULT 18600,   -- 労使協定ありの場合（分）デフォルト310時間
    has_labor_agreement BOOLEAN DEFAULT FALSE,              -- 労使協定有無

    -- 運転時間設定
    daily_driving_time_limit INTEGER DEFAULT 540,           -- 1日の運転時間上限（分）デフォルト9時間
    daily_driving_time_extended INTEGER DEFAULT 600,        -- 延長時（分）デフォルト10時間
    driving_extended_days_per_week INTEGER DEFAULT 2,       -- 週あたりの運転延長可能日数
    two_day_avg_driving_limit INTEGER DEFAULT 540,          -- 2日平均運転時間上限（分）9時間
    two_week_avg_driving_limit INTEGER DEFAULT 2640,        -- 2週平均運転時間上限（分）44時間

    -- 休息期間設定
    rest_period_minimum INTEGER DEFAULT 480,                -- 継続休息期間の最低時間（分）8時間
    rest_period_split_allowed BOOLEAN DEFAULT TRUE,         -- 分割休息可能か
    rest_period_split_minimum INTEGER DEFAULT 240,          -- 分割時の最低時間（分）4時間

    -- 連続運転設定
    continuous_driving_limit INTEGER DEFAULT 240,           -- 連続運転時間上限（分）4時間
    break_time_minimum INTEGER DEFAULT 30,                  -- 休憩時間の最低（分）30分

    -- 警告閾値（実際の上限に対する%）
    warning_threshold_percent INTEGER DEFAULT 90,           -- 90%で警告

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 労務日次集計テーブル（計算済みデータのキャッシュ）
CREATE TABLE IF NOT EXISTS labor_daily_summary (
    id SERIAL PRIMARY KEY,
    driver_id INTEGER REFERENCES users(id),
    summary_date DATE NOT NULL,

    -- 集計値
    total_binding_minutes INTEGER DEFAULT 0,       -- 拘束時間合計
    total_driving_minutes INTEGER DEFAULT 0,       -- 運転時間合計
    total_rest_minutes INTEGER DEFAULT 0,          -- 休息時間
    total_break_minutes INTEGER DEFAULT 0,         -- 休憩時間
    max_continuous_driving INTEGER DEFAULT 0,      -- 最長連続運転時間

    -- フラグ
    is_extended_day BOOLEAN DEFAULT FALSE,         -- 延長日として計上
    has_violation BOOLEAN DEFAULT FALSE,           -- 違反あり

    -- メタデータ
    work_record_ids INTEGER[],                     -- 対象の運行記録ID
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(driver_id, summary_date)
);

CREATE INDEX IF NOT EXISTS idx_labor_daily_summary_driver ON labor_daily_summary(driver_id);
CREATE INDEX IF NOT EXISTS idx_labor_daily_summary_date ON labor_daily_summary(summary_date);

-- ビュー: ドライバー別当月拘束時間サマリー
CREATE OR REPLACE VIEW driver_monthly_binding_time AS
SELECT
    lds.driver_id,
    u.name as driver_name,
    u.company_id,
    DATE_TRUNC('month', lds.summary_date) as month,
    SUM(lds.total_binding_minutes) as total_binding_minutes,
    SUM(lds.total_driving_minutes) as total_driving_minutes,
    COUNT(CASE WHEN lds.is_extended_day THEN 1 END) as extended_days_count,
    COUNT(CASE WHEN lds.has_violation THEN 1 END) as violation_days_count,
    COUNT(*) as work_days
FROM labor_daily_summary lds
JOIN users u ON lds.driver_id = u.id
GROUP BY lds.driver_id, u.name, u.company_id, DATE_TRUNC('month', lds.summary_date);

-- ビュー: 未確認アラート一覧
CREATE OR REPLACE VIEW unacknowledged_labor_alerts AS
SELECT
    la.id,
    la.company_id,
    la.driver_id,
    u.name as driver_name,
    u.employee_number,
    la.alert_type,
    la.alert_level,
    la.alert_date,
    la.threshold_value,
    la.actual_value,
    la.threshold_label,
    la.description,
    la.created_at
FROM labor_alerts la
JOIN users u ON la.driver_id = u.id
WHERE la.acknowledged = FALSE
ORDER BY
    CASE la.alert_level
        WHEN 'critical' THEN 1
        WHEN 'violation' THEN 2
        WHEN 'warning' THEN 3
    END,
    la.created_at DESC;

-- コメント
COMMENT ON TABLE labor_alerts IS '改善基準告示に基づく労務アラート';
COMMENT ON TABLE labor_compliance_settings IS '会社別の労務コンプライアンス設定（業種別デフォルト値対応）';
COMMENT ON TABLE labor_daily_summary IS 'ドライバー別日次労務時間集計（キャッシュ）';
COMMENT ON COLUMN work_records.binding_time_minutes IS '拘束時間（始業から終業まで、休息除く）';
COMMENT ON COLUMN work_records.driving_time_minutes IS '運転時間（実際に車両を運転した時間）';
COMMENT ON COLUMN work_records.rest_time_minutes IS '休息期間（勤務と勤務の間の完全な休み）';
COMMENT ON COLUMN labor_alerts.alert_type IS 'binding_time_daily/binding_time_monthly/driving_time_daily/driving_time_2day_avg/driving_time_2week_avg/rest_period/continuous_driving';
COMMENT ON COLUMN labor_alerts.alert_level IS 'warning:閾値の90%超過, violation:閾値超過, critical:重大な違反';
