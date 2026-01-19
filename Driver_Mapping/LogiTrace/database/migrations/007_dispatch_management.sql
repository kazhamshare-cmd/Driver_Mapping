-- Migration: 007_dispatch_management.sql
-- 配車・運行計画機能（受注管理、荷主マスタ、発着地マスタ、配車割当）

-- 荷主マスタ
CREATE TABLE IF NOT EXISTS shippers (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) NOT NULL,
    shipper_code VARCHAR(50),                           -- 荷主コード
    name VARCHAR(200) NOT NULL,                         -- 荷主名
    name_kana VARCHAR(200),                             -- 荷主名カナ
    postal_code VARCHAR(10),
    address TEXT,
    phone VARCHAR(20),
    fax VARCHAR(20),
    email VARCHAR(100),
    contact_person VARCHAR(100),                        -- 担当者名
    contact_phone VARCHAR(20),                          -- 担当者電話
    invoice_registration_number VARCHAR(20),            -- インボイス登録番号（T+13桁）
    payment_terms INTEGER DEFAULT 30,                   -- 支払サイト（日数）
    billing_closing_day INTEGER DEFAULT 31,             -- 締め日
    notes TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(company_id, shipper_code)
);

CREATE INDEX IF NOT EXISTS idx_shippers_company ON shippers(company_id);
CREATE INDEX IF NOT EXISTS idx_shippers_active ON shippers(company_id, is_active);

-- 発着地マスタ
CREATE TABLE IF NOT EXISTS locations (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) NOT NULL,
    location_code VARCHAR(50),                          -- 地点コード
    name VARCHAR(200) NOT NULL,                         -- 地点名
    name_kana VARCHAR(200),                             -- 地点名カナ
    location_type VARCHAR(20) DEFAULT 'both',           -- 'pickup', 'delivery', 'both'
    postal_code VARCHAR(10),
    address TEXT NOT NULL,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    contact_person VARCHAR(100),
    contact_phone VARCHAR(20),
    operating_hours_start TIME,                         -- 営業開始時間
    operating_hours_end TIME,                           -- 営業終了時間
    loading_time_minutes INTEGER DEFAULT 30,            -- 標準積込時間
    unloading_time_minutes INTEGER DEFAULT 30,          -- 標準荷卸時間
    notes TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(company_id, location_code)
);

CREATE INDEX IF NOT EXISTS idx_locations_company ON locations(company_id);
CREATE INDEX IF NOT EXISTS idx_locations_type ON locations(company_id, location_type);

-- 受注テーブル
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) NOT NULL,
    order_number VARCHAR(50) NOT NULL,                  -- 受注番号
    shipper_id INTEGER REFERENCES shippers(id),

    -- 集荷情報
    pickup_location_id INTEGER REFERENCES locations(id),
    pickup_address TEXT,                                -- 登録外の場合
    pickup_datetime TIMESTAMP NOT NULL,                 -- 集荷希望日時
    pickup_datetime_end TIMESTAMP,                      -- 集荷希望日時（幅指定の場合）

    -- 配達情報
    delivery_location_id INTEGER REFERENCES locations(id),
    delivery_address TEXT,                              -- 登録外の場合
    delivery_datetime TIMESTAMP,                        -- 配達希望日時
    delivery_datetime_end TIMESTAMP,                    -- 配達希望日時（幅指定の場合）

    -- 貨物情報
    cargo_type VARCHAR(100),                            -- 貨物種別
    cargo_name VARCHAR(200),                            -- 品名
    cargo_weight DECIMAL(10,2),                         -- 重量 (kg)
    cargo_volume DECIMAL(10,2),                         -- 容積 (m3)
    cargo_quantity INTEGER,                             -- 数量
    cargo_unit VARCHAR(20),                             -- 単位（パレット、ケース等）
    is_fragile BOOLEAN DEFAULT FALSE,                   -- 割れ物
    requires_temperature_control BOOLEAN DEFAULT FALSE, -- 温度管理
    temperature_min DECIMAL(5,2),                       -- 最低温度
    temperature_max DECIMAL(5,2),                       -- 最高温度

    -- 車両要件
    required_vehicle_type VARCHAR(50),                  -- 必要車両タイプ
    required_license_type VARCHAR(50),                  -- 必要免許

    -- 料金情報
    base_fare DECIMAL(12,2),                            -- 基本運賃
    additional_charges DECIMAL(12,2) DEFAULT 0,         -- 附帯料金
    toll_fee DECIMAL(10,2) DEFAULT 0,                   -- 高速代
    total_fare DECIMAL(12,2),                           -- 合計運賃

    -- ステータス
    status VARCHAR(20) DEFAULT 'pending',               -- pending, assigned, in_progress, completed, cancelled
    priority INTEGER DEFAULT 3,                         -- 1=緊急, 2=高, 3=通常, 4=低

    -- 備考
    customer_notes TEXT,                                -- 荷主からの備考
    internal_notes TEXT,                                -- 社内備考

    -- メタデータ
    received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,    -- 受注日時
    received_by INTEGER REFERENCES users(id),           -- 受注者
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(company_id, order_number)
);

CREATE INDEX IF NOT EXISTS idx_orders_company ON orders(company_id);
CREATE INDEX IF NOT EXISTS idx_orders_shipper ON orders(shipper_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(company_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_pickup_date ON orders(pickup_datetime);
CREATE INDEX IF NOT EXISTS idx_orders_delivery_date ON orders(delivery_datetime);

-- 配車割当テーブル
CREATE TABLE IF NOT EXISTS dispatch_assignments (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) NOT NULL,
    order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,

    -- 割当情報
    vehicle_id INTEGER REFERENCES vehicles(id),
    driver_id INTEGER REFERENCES users(id),

    -- スケジュール
    scheduled_start TIMESTAMP NOT NULL,                 -- 予定出発時刻
    scheduled_end TIMESTAMP,                            -- 予定終了時刻
    estimated_distance DECIMAL(10,2),                   -- 予定走行距離
    estimated_duration_minutes INTEGER,                 -- 予定所要時間

    -- 実績
    actual_start TIMESTAMP,                             -- 実際の出発時刻
    actual_end TIMESTAMP,                               -- 実際の終了時刻
    actual_distance DECIMAL(10,2),                      -- 実際の走行距離

    -- 拘束時間チェック結果
    driver_binding_before INTEGER,                      -- 割当前の当日拘束時間
    driver_binding_after INTEGER,                       -- 割当後の予想拘束時間
    binding_warning BOOLEAN DEFAULT FALSE,              -- 拘束時間警告あり

    -- ステータス
    status VARCHAR(20) DEFAULT 'assigned',              -- assigned, started, completed, cancelled

    -- 備考
    notes TEXT,

    -- メタデータ
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    assigned_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_dispatch_company ON dispatch_assignments(company_id);
CREATE INDEX IF NOT EXISTS idx_dispatch_order ON dispatch_assignments(order_id);
CREATE INDEX IF NOT EXISTS idx_dispatch_vehicle ON dispatch_assignments(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_dispatch_driver ON dispatch_assignments(driver_id);
CREATE INDEX IF NOT EXISTS idx_dispatch_schedule ON dispatch_assignments(scheduled_start, scheduled_end);
CREATE INDEX IF NOT EXISTS idx_dispatch_status ON dispatch_assignments(status);

-- 配車履歴（変更追跡用）
CREATE TABLE IF NOT EXISTS dispatch_history (
    id SERIAL PRIMARY KEY,
    dispatch_id INTEGER REFERENCES dispatch_assignments(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL,                        -- 'created', 'reassigned', 'started', 'completed', 'cancelled'
    old_vehicle_id INTEGER REFERENCES vehicles(id),
    new_vehicle_id INTEGER REFERENCES vehicles(id),
    old_driver_id INTEGER REFERENCES users(id),
    new_driver_id INTEGER REFERENCES users(id),
    reason TEXT,
    changed_by INTEGER REFERENCES users(id),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_dispatch_history_dispatch ON dispatch_history(dispatch_id);

-- ビュー: 本日の配車状況
CREATE OR REPLACE VIEW today_dispatch_summary AS
SELECT
    da.company_id,
    COUNT(DISTINCT da.id) as total_dispatches,
    COUNT(DISTINCT CASE WHEN da.status = 'assigned' THEN da.id END) as assigned_count,
    COUNT(DISTINCT CASE WHEN da.status = 'started' THEN da.id END) as in_progress_count,
    COUNT(DISTINCT CASE WHEN da.status = 'completed' THEN da.id END) as completed_count,
    COUNT(DISTINCT da.vehicle_id) as vehicles_used,
    COUNT(DISTINCT da.driver_id) as drivers_assigned,
    COUNT(DISTINCT CASE WHEN da.binding_warning = TRUE THEN da.driver_id END) as drivers_with_warning
FROM dispatch_assignments da
WHERE DATE(da.scheduled_start) = CURRENT_DATE
GROUP BY da.company_id;

-- ビュー: 未割当受注一覧
CREATE OR REPLACE VIEW unassigned_orders AS
SELECT
    o.id,
    o.company_id,
    o.order_number,
    s.name as shipper_name,
    o.pickup_datetime,
    o.delivery_datetime,
    pl.name as pickup_location_name,
    o.pickup_address,
    dl.name as delivery_location_name,
    o.delivery_address,
    o.cargo_name,
    o.cargo_weight,
    o.required_vehicle_type,
    o.priority,
    o.received_at
FROM orders o
LEFT JOIN shippers s ON o.shipper_id = s.id
LEFT JOIN locations pl ON o.pickup_location_id = pl.id
LEFT JOIN locations dl ON o.delivery_location_id = dl.id
LEFT JOIN dispatch_assignments da ON o.id = da.order_id AND da.status != 'cancelled'
WHERE o.status = 'pending' AND da.id IS NULL
ORDER BY o.priority ASC, o.pickup_datetime ASC;

-- ビュー: ドライバー別本日スケジュール
CREATE OR REPLACE VIEW driver_daily_schedule AS
SELECT
    da.driver_id,
    u.name as driver_name,
    u.company_id,
    da.id as dispatch_id,
    o.order_number,
    s.name as shipper_name,
    da.scheduled_start,
    da.scheduled_end,
    da.status,
    pl.name as pickup_location,
    dl.name as delivery_location,
    o.cargo_name,
    da.binding_warning
FROM dispatch_assignments da
JOIN users u ON da.driver_id = u.id
JOIN orders o ON da.order_id = o.id
LEFT JOIN shippers s ON o.shipper_id = s.id
LEFT JOIN locations pl ON o.pickup_location_id = pl.id
LEFT JOIN locations dl ON o.delivery_location_id = dl.id
WHERE DATE(da.scheduled_start) = CURRENT_DATE
ORDER BY da.driver_id, da.scheduled_start;

-- ビュー: 車両別本日スケジュール
CREATE OR REPLACE VIEW vehicle_daily_schedule AS
SELECT
    da.vehicle_id,
    v.vehicle_number,
    v.company_id,
    da.id as dispatch_id,
    o.order_number,
    da.driver_id,
    u.name as driver_name,
    da.scheduled_start,
    da.scheduled_end,
    da.status,
    pl.name as pickup_location,
    dl.name as delivery_location
FROM dispatch_assignments da
JOIN vehicles v ON da.vehicle_id = v.id
JOIN orders o ON da.order_id = o.id
LEFT JOIN users u ON da.driver_id = u.id
LEFT JOIN locations pl ON o.pickup_location_id = pl.id
LEFT JOIN locations dl ON o.delivery_location_id = dl.id
WHERE DATE(da.scheduled_start) = CURRENT_DATE
ORDER BY da.vehicle_id, da.scheduled_start;

-- コメント
COMMENT ON TABLE shippers IS '荷主マスタ';
COMMENT ON TABLE locations IS '発着地マスタ';
COMMENT ON TABLE orders IS '受注データ';
COMMENT ON TABLE dispatch_assignments IS '配車割当';
COMMENT ON TABLE dispatch_history IS '配車変更履歴';
COMMENT ON COLUMN orders.status IS 'pending=未割当, assigned=割当済, in_progress=運行中, completed=完了, cancelled=キャンセル';
COMMENT ON COLUMN dispatch_assignments.binding_warning IS '割当によりドライバーの拘束時間が警告レベルに達する場合TRUE';
