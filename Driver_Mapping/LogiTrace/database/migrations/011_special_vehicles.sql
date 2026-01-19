-- Phase 6: 特殊車両・業態対応
-- トレーラー管理、海上輸送連携、通運事業対応

-- ============================================
-- 6.1 トレーラー管理
-- ============================================

-- トラクタヘッド（牽引車）マスタ
CREATE TABLE tractor_heads (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    vehicle_id INTEGER REFERENCES vehicles(id), -- 既存の車両テーブルと連携
    tractor_number VARCHAR(20) NOT NULL, -- 車両番号
    chassis_type VARCHAR(50), -- 'single_axle', 'tandem_axle', 'tri_axle'
    fifth_wheel_height INTEGER, -- 第五輪高さ (mm)
    max_towing_weight INTEGER, -- 最大牽引重量 (kg)
    coupling_type VARCHAR(50), -- 連結装置タイプ
    status VARCHAR(20) DEFAULT 'available', -- 'available', 'in_use', 'maintenance', 'inactive'
    current_chassis_id INTEGER, -- 現在連結中のシャーシ
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- シャーシ（被牽引車）マスタ
CREATE TABLE chassis (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    chassis_number VARCHAR(20) NOT NULL, -- シャーシ番号
    chassis_type VARCHAR(50) NOT NULL, -- 'dry_van', 'reefer', 'flatbed', 'tank', 'container_chassis', 'lowboy'
    length_feet INTEGER, -- 長さ (フィート): 20, 40, 45, 53
    max_payload_weight INTEGER, -- 最大積載量 (kg)
    tare_weight INTEGER, -- 自重 (kg)
    axle_count INTEGER DEFAULT 2, -- 軸数
    is_owned BOOLEAN DEFAULT true, -- 自社所有 or リース
    lease_company VARCHAR(100), -- リース会社名
    lease_start_date DATE,
    lease_end_date DATE,
    inspection_expiry DATE, -- 車検満了日
    status VARCHAR(20) DEFAULT 'available', -- 'available', 'in_use', 'maintenance', 'repair', 'inactive'
    current_location VARCHAR(200), -- 現在地
    current_tractor_id INTEGER REFERENCES tractor_heads(id),
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 外部キー追加（循環参照のため後から追加）
ALTER TABLE tractor_heads ADD CONSTRAINT fk_current_chassis
    FOREIGN KEY (current_chassis_id) REFERENCES chassis(id);

-- 連結・連結解除記録
CREATE TABLE coupling_records (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    tractor_id INTEGER REFERENCES tractor_heads(id),
    chassis_id INTEGER REFERENCES chassis(id),
    driver_id INTEGER REFERENCES users(id),
    action_type VARCHAR(20) NOT NULL, -- 'couple', 'uncouple'
    action_datetime TIMESTAMP NOT NULL,
    location VARCHAR(200),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    odometer_reading INTEGER,
    seal_number VARCHAR(50), -- シール番号（連結時）
    inspection_done BOOLEAN DEFAULT false, -- 連結前点検実施
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- シャーシ予約・スケジュール
CREATE TABLE chassis_schedules (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    chassis_id INTEGER REFERENCES chassis(id),
    tractor_id INTEGER REFERENCES tractor_heads(id),
    driver_id INTEGER REFERENCES users(id),
    dispatch_id INTEGER REFERENCES dispatch_assignments(id),
    scheduled_start TIMESTAMP NOT NULL,
    scheduled_end TIMESTAMP NOT NULL,
    actual_start TIMESTAMP,
    actual_end TIMESTAMP,
    pickup_location VARCHAR(200),
    delivery_location VARCHAR(200),
    status VARCHAR(20) DEFAULT 'scheduled', -- 'scheduled', 'in_progress', 'completed', 'cancelled'
    priority INTEGER DEFAULT 5, -- 1-10（高い方が優先）
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 6.2 海上輸送連携
-- ============================================

-- 港湾マスタ
CREATE TABLE ports (
    id SERIAL PRIMARY KEY,
    port_code VARCHAR(10) NOT NULL UNIQUE, -- UN/LOCODE (例: JPTYO, JPYOK)
    port_name VARCHAR(100) NOT NULL,
    port_name_en VARCHAR(100),
    country_code CHAR(2) DEFAULT 'JP',
    prefecture VARCHAR(50),
    address TEXT,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    terminal_info JSONB, -- ターミナル情報
    operating_hours JSONB, -- 営業時間
    contact_info JSONB, -- 連絡先
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- RORO船・フェリー航路マスタ
CREATE TABLE ferry_routes (
    id SERIAL PRIMARY KEY,
    route_code VARCHAR(20) NOT NULL,
    route_name VARCHAR(100) NOT NULL,
    shipping_company VARCHAR(100), -- 船会社
    departure_port_id INTEGER REFERENCES ports(id),
    arrival_port_id INTEGER REFERENCES ports(id),
    vessel_name VARCHAR(100), -- 船名
    vessel_type VARCHAR(50), -- 'roro', 'ferry', 'cargo'
    sailing_duration_hours DECIMAL(5, 2), -- 所要時間
    frequency VARCHAR(100), -- 運航頻度（例: "毎日", "週3便"）
    vehicle_capacity INTEGER, -- 車両積載台数
    trailer_capacity INTEGER, -- トレーラー積載台数
    booking_required BOOLEAN DEFAULT true,
    advance_booking_days INTEGER DEFAULT 7, -- 何日前から予約可能
    cutoff_hours INTEGER DEFAULT 2, -- 出港何時間前が締切
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- RORO船・フェリースケジュール
CREATE TABLE ferry_schedules (
    id SERIAL PRIMARY KEY,
    route_id INTEGER REFERENCES ferry_routes(id),
    departure_date DATE NOT NULL,
    departure_time TIME NOT NULL,
    arrival_date DATE NOT NULL,
    arrival_time TIME NOT NULL,
    vessel_name VARCHAR(100),
    status VARCHAR(20) DEFAULT 'scheduled', -- 'scheduled', 'boarding', 'departed', 'arrived', 'cancelled', 'delayed'
    delay_minutes INTEGER DEFAULT 0,
    available_vehicle_slots INTEGER,
    available_trailer_slots INTEGER,
    weather_warning BOOLEAN DEFAULT false,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 乗船予約
CREATE TABLE ferry_bookings (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    schedule_id INTEGER REFERENCES ferry_schedules(id),
    booking_number VARCHAR(50), -- 予約番号
    booking_type VARCHAR(20), -- 'vehicle', 'trailer', 'driver_only'
    tractor_id INTEGER REFERENCES tractor_heads(id),
    chassis_id INTEGER REFERENCES chassis(id),
    vehicle_id INTEGER REFERENCES vehicles(id), -- 単車の場合
    driver_id INTEGER REFERENCES users(id),
    dispatch_id INTEGER REFERENCES dispatch_assignments(id),
    cabin_type VARCHAR(50), -- 客室タイプ
    boarding_status VARCHAR(20) DEFAULT 'booked', -- 'booked', 'checked_in', 'boarded', 'completed', 'cancelled', 'no_show'
    check_in_time TIMESTAMP,
    boarding_time TIMESTAMP,
    fare_amount DECIMAL(10, 2),
    additional_charges DECIMAL(10, 2),
    payment_status VARCHAR(20) DEFAULT 'unpaid',
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 港湾作業記録
CREATE TABLE port_operations (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    port_id INTEGER REFERENCES ports(id),
    operation_type VARCHAR(50), -- 'loading', 'unloading', 'customs', 'inspection', 'waiting'
    tractor_id INTEGER REFERENCES tractor_heads(id),
    chassis_id INTEGER REFERENCES chassis(id),
    vehicle_id INTEGER REFERENCES vehicles(id),
    driver_id INTEGER REFERENCES users(id),
    container_id INTEGER, -- コンテナ管理と連携
    ferry_booking_id INTEGER REFERENCES ferry_bookings(id),
    arrival_time TIMESTAMP,
    operation_start TIMESTAMP,
    operation_end TIMESTAMP,
    departure_time TIMESTAMP,
    gate_in_number VARCHAR(50), -- ゲートイン番号
    gate_out_number VARCHAR(50), -- ゲートアウト番号
    berth_number VARCHAR(20), -- バース番号
    waiting_time_minutes INTEGER, -- 待機時間
    status VARCHAR(20) DEFAULT 'pending',
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 6.3 通運事業対応（JR貨物連携）
-- ============================================

-- コンテナマスタ
CREATE TABLE containers (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    container_number VARCHAR(20) NOT NULL, -- コンテナ番号（例: ABCU1234567）
    container_type VARCHAR(20) NOT NULL, -- '12ft', '20ft', '31ft', '40ft', '40ft_hc', '45ft'
    container_category VARCHAR(50), -- 'dry', 'reefer', 'tank', 'open_top', 'flat_rack'
    is_owned BOOLEAN DEFAULT false, -- 自社所有（通常はJR貨物等から借用）
    owner_company VARCHAR(100), -- 所有会社
    max_payload_kg INTEGER,
    tare_weight_kg INTEGER,
    internal_length_mm INTEGER,
    internal_width_mm INTEGER,
    internal_height_mm INTEGER,
    cubic_capacity_m3 DECIMAL(10, 2),
    temperature_control BOOLEAN DEFAULT false, -- 温度管理機能
    min_temperature INTEGER, -- 最低設定温度
    max_temperature INTEGER, -- 最高設定温度
    status VARCHAR(20) DEFAULT 'available', -- 'available', 'loaded', 'in_transit', 'empty_return', 'maintenance'
    current_location VARCHAR(200),
    last_inspection_date DATE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 貨物駅マスタ
CREATE TABLE freight_stations (
    id SERIAL PRIMARY KEY,
    station_code VARCHAR(10) NOT NULL UNIQUE, -- 駅コード
    station_name VARCHAR(100) NOT NULL,
    station_name_kana VARCHAR(100),
    station_type VARCHAR(50), -- 'container', 'bulk', 'mixed'
    railway_company VARCHAR(50) DEFAULT 'JR貨物',
    prefecture VARCHAR(50),
    address TEXT,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    operating_hours JSONB, -- 営業時間
    container_handling BOOLEAN DEFAULT true, -- コンテナ取扱
    reefer_plug BOOLEAN DEFAULT false, -- リーファープラグ有無
    crane_capacity_tons INTEGER, -- クレーン能力
    truck_berth_count INTEGER, -- トラックバース数
    contact_info JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 鉄道輸送ルート
CREATE TABLE rail_routes (
    id SERIAL PRIMARY KEY,
    route_code VARCHAR(20) NOT NULL,
    route_name VARCHAR(100),
    departure_station_id INTEGER REFERENCES freight_stations(id),
    arrival_station_id INTEGER REFERENCES freight_stations(id),
    transit_time_hours INTEGER, -- 輸送時間
    distance_km INTEGER,
    train_type VARCHAR(50), -- '高速貨物', '専用貨物', 'コンテナ特急'
    frequency VARCHAR(100), -- 運行頻度
    cutoff_hours INTEGER DEFAULT 4, -- 何時間前締切
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 鉄道輸送予約
CREATE TABLE rail_bookings (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    route_id INTEGER REFERENCES rail_routes(id),
    booking_number VARCHAR(50), -- 予約番号
    container_id INTEGER REFERENCES containers(id),
    shipper_id INTEGER REFERENCES shippers(id),
    dispatch_id INTEGER REFERENCES dispatch_assignments(id),
    departure_date DATE NOT NULL,
    departure_time TIME,
    arrival_date DATE,
    arrival_time TIME,
    cargo_description TEXT,
    cargo_weight_kg INTEGER,
    booking_status VARCHAR(20) DEFAULT 'booked', -- 'booked', 'confirmed', 'loaded', 'in_transit', 'arrived', 'delivered', 'cancelled'
    pickup_tractor_id INTEGER REFERENCES tractor_heads(id), -- 集荷トラクタ
    pickup_driver_id INTEGER REFERENCES users(id), -- 集荷ドライバー
    delivery_tractor_id INTEGER REFERENCES tractor_heads(id), -- 配達トラクタ
    delivery_driver_id INTEGER REFERENCES users(id), -- 配達ドライバー
    rail_fare DECIMAL(10, 2), -- 鉄道運賃
    pickup_fare DECIMAL(10, 2), -- 集荷運賃
    delivery_fare DECIMAL(10, 2), -- 配達運賃
    total_fare DECIMAL(10, 2),
    payment_status VARCHAR(20) DEFAULT 'unpaid',
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- コンテナ追跡履歴
CREATE TABLE container_tracking (
    id SERIAL PRIMARY KEY,
    container_id INTEGER REFERENCES containers(id),
    rail_booking_id INTEGER REFERENCES rail_bookings(id),
    tracked_at TIMESTAMP NOT NULL,
    location_type VARCHAR(50), -- 'station', 'port', 'yard', 'customer', 'in_transit'
    location_name VARCHAR(200),
    station_id INTEGER REFERENCES freight_stations(id),
    port_id INTEGER REFERENCES ports(id),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    status VARCHAR(50), -- 'empty', 'loading', 'loaded', 'in_transit', 'unloading', 'delivered'
    temperature DECIMAL(5, 2), -- リーファーコンテナの温度
    humidity INTEGER, -- 湿度
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- インデックス
-- ============================================

CREATE INDEX idx_tractor_heads_company ON tractor_heads(company_id);
CREATE INDEX idx_tractor_heads_status ON tractor_heads(status);
CREATE INDEX idx_chassis_company ON chassis(company_id);
CREATE INDEX idx_chassis_status ON chassis(status);
CREATE INDEX idx_chassis_type ON chassis(chassis_type);
CREATE INDEX idx_coupling_records_tractor ON coupling_records(tractor_id);
CREATE INDEX idx_coupling_records_chassis ON coupling_records(chassis_id);
CREATE INDEX idx_coupling_records_datetime ON coupling_records(action_datetime);
CREATE INDEX idx_chassis_schedules_dates ON chassis_schedules(scheduled_start, scheduled_end);
CREATE INDEX idx_chassis_schedules_chassis ON chassis_schedules(chassis_id);

CREATE INDEX idx_ferry_schedules_route ON ferry_schedules(route_id);
CREATE INDEX idx_ferry_schedules_departure ON ferry_schedules(departure_date);
CREATE INDEX idx_ferry_bookings_company ON ferry_bookings(company_id);
CREATE INDEX idx_ferry_bookings_schedule ON ferry_bookings(schedule_id);
CREATE INDEX idx_port_operations_port ON port_operations(port_id);
CREATE INDEX idx_port_operations_company ON port_operations(company_id);

CREATE INDEX idx_containers_company ON containers(company_id);
CREATE INDEX idx_containers_status ON containers(status);
CREATE INDEX idx_containers_number ON containers(container_number);
CREATE INDEX idx_rail_bookings_company ON rail_bookings(company_id);
CREATE INDEX idx_rail_bookings_date ON rail_bookings(departure_date);
CREATE INDEX idx_container_tracking_container ON container_tracking(container_id);
CREATE INDEX idx_container_tracking_time ON container_tracking(tracked_at);

-- ============================================
-- 初期データ
-- ============================================

-- 主要港湾
INSERT INTO ports (port_code, port_name, port_name_en, prefecture, latitude, longitude) VALUES
('JPTYO', '東京港', 'Port of Tokyo', '東京都', 35.6240, 139.7760),
('JPYOK', '横浜港', 'Port of Yokohama', '神奈川県', 35.4437, 139.6380),
('JPNGO', '名古屋港', 'Port of Nagoya', '愛知県', 35.0800, 136.8860),
('JPOSA', '大阪港', 'Port of Osaka', '大阪府', 34.6500, 135.4320),
('JPUKB', '神戸港', 'Port of Kobe', '兵庫県', 34.6700, 135.1960),
('JPHKT', '博多港', 'Port of Hakata', '福岡県', 33.6000, 130.4020),
('JPSDJ', '清水港', 'Port of Shimizu', '静岡県', 35.0167, 138.5000),
('JPNII', '新潟港', 'Port of Niigata', '新潟県', 37.9500, 139.0500),
('JPTMK', '苫小牧港', 'Port of Tomakomai', '北海道', 42.6333, 141.6167),
('JPOIT', '大分港', 'Port of Oita', '大分県', 33.2333, 131.6167);

-- 主要フェリー航路
INSERT INTO ferry_routes (route_code, route_name, shipping_company, departure_port_id, arrival_port_id, vessel_type, sailing_duration_hours) VALUES
('TKY-TMK', '東京〜苫小牧', '商船三井フェリー', 1, 9, 'roro', 19),
('NGO-SDO', '名古屋〜仙台〜苫小牧', '太平洋フェリー', 3, 9, 'ferry', 21),
('OSA-BPU', '大阪〜別府', 'フェリーさんふらわあ', 4, 10, 'ferry', 12),
('KOB-OIT', '神戸〜大分', 'フェリーさんふらわあ', 5, 10, 'ferry', 11),
('HKT-OSA', '博多〜大阪', '名門大洋フェリー', 6, 4, 'ferry', 12);

-- 主要貨物駅
INSERT INTO freight_stations (station_code, station_name, prefecture, container_handling, reefer_plug) VALUES
('TOKYO', '東京貨物ターミナル', '東京都', true, true),
('YOKOHAMA', '横浜羽沢', '神奈川県', true, true),
('NAGOYA', '名古屋貨物ターミナル', '愛知県', true, true),
('OSAKA', '大阪貨物ターミナル', '大阪府', true, true),
('KOBE', '神戸貨物ターミナル', '兵庫県', true, true),
('FUKUOKA', '福岡貨物ターミナル', '福岡県', true, true),
('SAPPORO', '札幌貨物ターミナル', '北海道', true, true),
('SENDAI', '仙台貨物ターミナル', '宮城県', true, false),
('HIROSHIMA', '広島貨物ターミナル', '広島県', true, false),
('NIIGATA', '新潟貨物ターミナル', '新潟県', true, false);

-- 主要鉄道輸送ルート
INSERT INTO rail_routes (route_code, route_name, departure_station_id, arrival_station_id, transit_time_hours, distance_km) VALUES
('TYO-SPR', '東京〜札幌', 1, 7, 18, 1150),
('TYO-FKO', '東京〜福岡', 1, 6, 14, 1180),
('OSA-SPR', '大阪〜札幌', 4, 7, 21, 1500),
('NGO-SPR', '名古屋〜札幌', 3, 7, 20, 1350),
('TYO-OSA', '東京〜大阪', 1, 4, 6, 550);
