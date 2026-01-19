-- =====================================================
-- Phase 5: デジタコ連携強化 (Tachograph Integration)
-- 富士通ITP-WebService V3、パイオニアVehicleAssist、
-- 矢崎・デンソー強化対応
-- =====================================================

-- デジタコ連携設定マスタ
CREATE TABLE IF NOT EXISTS tachograph_integrations (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,

    -- 連携タイプ
    provider VARCHAR(50) NOT NULL,  -- 'fujitsu_itp', 'pioneer_vehicle_assist', 'yazaki', 'denso', 'custom'
    integration_name VARCHAR(100),  -- 表示名

    -- 接続設定（暗号化して保存推奨）
    api_endpoint TEXT,
    api_key TEXT,
    api_secret TEXT,
    username TEXT,
    password TEXT,

    -- 富士通ITP-WebService固有設定
    itp_company_code VARCHAR(50),
    itp_terminal_id VARCHAR(50),

    -- パイオニアVehicleAssist固有設定
    pioneer_customer_code VARCHAR(50),
    pioneer_contract_id VARCHAR(50),

    -- 同期設定
    sync_enabled BOOLEAN DEFAULT false,
    sync_interval_minutes INTEGER DEFAULT 60,  -- 同期間隔（分）
    last_sync_at TIMESTAMP,
    next_sync_at TIMESTAMP,

    -- 同期オプション
    auto_import_records BOOLEAN DEFAULT true,  -- 運行データ自動取込
    auto_send_instructions BOOLEAN DEFAULT false,  -- 運行指示自動送信
    sync_master_data BOOLEAN DEFAULT false,  -- マスタデータ同期

    -- ドライバー/車両マッピング方式
    driver_mapping_method VARCHAR(20) DEFAULT 'employee_number',  -- 'employee_number', 'card_id', 'custom'
    vehicle_mapping_method VARCHAR(20) DEFAULT 'vehicle_number',  -- 'vehicle_number', 'device_id', 'custom'

    -- ステータス
    status VARCHAR(20) DEFAULT 'inactive',  -- 'active', 'inactive', 'error'
    error_message TEXT,

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    UNIQUE(company_id, provider)
);

-- デジタコドライバーマッピング
CREATE TABLE IF NOT EXISTS tachograph_driver_mappings (
    id SERIAL PRIMARY KEY,
    integration_id INTEGER REFERENCES tachograph_integrations(id) ON DELETE CASCADE,

    -- 外部システムの識別子
    external_driver_id VARCHAR(100) NOT NULL,
    external_driver_code VARCHAR(50),
    external_driver_name VARCHAR(100),

    -- LogiTraceのドライバー
    driver_id INTEGER REFERENCES users(id) ON DELETE SET NULL,

    -- マッピングステータス
    is_active BOOLEAN DEFAULT true,
    mapped_at TIMESTAMP DEFAULT NOW(),

    UNIQUE(integration_id, external_driver_id)
);

-- デジタコ車両マッピング
CREATE TABLE IF NOT EXISTS tachograph_vehicle_mappings (
    id SERIAL PRIMARY KEY,
    integration_id INTEGER REFERENCES tachograph_integrations(id) ON DELETE CASCADE,

    -- 外部システムの識別子
    external_vehicle_id VARCHAR(100) NOT NULL,
    external_vehicle_number VARCHAR(50),
    external_device_id VARCHAR(100),

    -- LogiTraceの車両
    vehicle_id INTEGER REFERENCES vehicles(id) ON DELETE SET NULL,

    -- マッピングステータス
    is_active BOOLEAN DEFAULT true,
    mapped_at TIMESTAMP DEFAULT NOW(),

    UNIQUE(integration_id, external_vehicle_id)
);

-- デジタコ同期ログ
CREATE TABLE IF NOT EXISTS tachograph_sync_logs (
    id SERIAL PRIMARY KEY,
    integration_id INTEGER REFERENCES tachograph_integrations(id) ON DELETE CASCADE,

    sync_type VARCHAR(50) NOT NULL,  -- 'import_records', 'send_instruction', 'sync_master', 'full_sync'
    sync_direction VARCHAR(10) NOT NULL,  -- 'inbound', 'outbound'

    started_at TIMESTAMP NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP,

    -- 結果
    status VARCHAR(20) DEFAULT 'running',  -- 'running', 'completed', 'failed', 'partial'
    records_processed INTEGER DEFAULT 0,
    records_success INTEGER DEFAULT 0,
    records_failed INTEGER DEFAULT 0,

    -- エラー詳細
    error_message TEXT,
    error_details JSONB,

    -- リクエスト/レスポンス（デバッグ用）
    request_summary JSONB,
    response_summary JSONB
);

-- 運行指示送信履歴
CREATE TABLE IF NOT EXISTS tachograph_instruction_sends (
    id SERIAL PRIMARY KEY,
    integration_id INTEGER REFERENCES tachograph_integrations(id) ON DELETE CASCADE,
    dispatch_id INTEGER REFERENCES dispatch_assignments(id) ON DELETE SET NULL,

    -- 送信内容
    instruction_type VARCHAR(50),  -- 'new', 'update', 'cancel'
    external_instruction_id VARCHAR(100),  -- 外部システムでの指示ID

    -- 送信情報
    sent_at TIMESTAMP DEFAULT NOW(),
    sent_by INTEGER REFERENCES users(id),

    -- 結果
    status VARCHAR(20) DEFAULT 'pending',  -- 'pending', 'sent', 'acknowledged', 'failed'
    acknowledged_at TIMESTAMP,
    error_message TEXT,

    -- リクエスト/レスポンス
    request_data JSONB,
    response_data JSONB
);

-- デジタコ実績データ拡張（既存テーブルにカラム追加）
ALTER TABLE tachograph_data ADD COLUMN IF NOT EXISTS integration_id INTEGER REFERENCES tachograph_integrations(id);
ALTER TABLE tachograph_data ADD COLUMN IF NOT EXISTS external_record_id VARCHAR(100);
ALTER TABLE tachograph_data ADD COLUMN IF NOT EXISTS sync_log_id INTEGER REFERENCES tachograph_sync_logs(id);

-- 運転評価データ（デジタコから取得）
CREATE TABLE IF NOT EXISTS driving_evaluations (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    driver_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    vehicle_id INTEGER REFERENCES vehicles(id) ON DELETE SET NULL,
    tachograph_data_id INTEGER REFERENCES tachograph_data(id) ON DELETE SET NULL,

    evaluation_date DATE NOT NULL,

    -- 安全運転スコア（100点満点）
    safety_score INTEGER,
    eco_score INTEGER,  -- エコドライブスコア
    overall_score INTEGER,

    -- 詳細項目
    harsh_braking_count INTEGER DEFAULT 0,
    harsh_acceleration_count INTEGER DEFAULT 0,
    harsh_cornering_count INTEGER DEFAULT 0,
    speeding_count INTEGER DEFAULT 0,
    speeding_duration_minutes INTEGER DEFAULT 0,

    -- アイドリング
    idle_count INTEGER DEFAULT 0,
    idle_duration_minutes INTEGER DEFAULT 0,

    -- 速度帯別走行距離
    distance_under_40 DECIMAL(10,2) DEFAULT 0,
    distance_40_60 DECIMAL(10,2) DEFAULT 0,
    distance_60_80 DECIMAL(10,2) DEFAULT 0,
    distance_over_80 DECIMAL(10,2) DEFAULT 0,

    -- 燃費データ
    fuel_consumption DECIMAL(10,2),  -- リットル
    fuel_efficiency DECIMAL(8,2),  -- km/L

    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 位置情報履歴（デジタコからリアルタイム取得）
CREATE TABLE IF NOT EXISTS vehicle_location_history (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    vehicle_id INTEGER REFERENCES vehicles(id) ON DELETE CASCADE,
    driver_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    integration_id INTEGER REFERENCES tachograph_integrations(id),

    recorded_at TIMESTAMP NOT NULL,

    -- 位置情報
    latitude DECIMAL(10, 7) NOT NULL,
    longitude DECIMAL(10, 7) NOT NULL,
    altitude DECIMAL(8, 2),
    heading DECIMAL(5, 2),  -- 進行方向（度）

    -- 走行状態
    speed DECIMAL(6, 2),  -- km/h
    engine_status VARCHAR(20),  -- 'running', 'idle', 'stopped'

    -- イベント
    event_type VARCHAR(50),  -- 'start', 'stop', 'rest', 'harsh_brake', 'speeding', etc.

    -- アドレス（ジオコーディング結果）
    address TEXT,

    created_at TIMESTAMP DEFAULT NOW()
);

-- 位置情報パーティション（日付ベース）
-- 大量データ対応のため、月ごとにパーティション推奨
CREATE INDEX IF NOT EXISTS idx_vehicle_location_history_recorded ON vehicle_location_history(recorded_at);
CREATE INDEX IF NOT EXISTS idx_vehicle_location_history_vehicle ON vehicle_location_history(vehicle_id, recorded_at);

-- インデックス
CREATE INDEX IF NOT EXISTS idx_tachograph_integrations_company ON tachograph_integrations(company_id);
CREATE INDEX IF NOT EXISTS idx_tachograph_sync_logs_integration ON tachograph_sync_logs(integration_id, started_at);
CREATE INDEX IF NOT EXISTS idx_tachograph_instruction_sends_dispatch ON tachograph_instruction_sends(dispatch_id);
CREATE INDEX IF NOT EXISTS idx_driving_evaluations_driver ON driving_evaluations(driver_id, evaluation_date);
CREATE INDEX IF NOT EXISTS idx_driving_evaluations_vehicle ON driving_evaluations(vehicle_id, evaluation_date);

-- コメント
COMMENT ON TABLE tachograph_integrations IS 'デジタコ連携設定（富士通・パイオニア・矢崎・デンソー等）';
COMMENT ON TABLE tachograph_driver_mappings IS 'デジタコドライバーマッピング（外部ID↔システムID）';
COMMENT ON TABLE tachograph_vehicle_mappings IS 'デジタコ車両マッピング（外部ID↔システムID）';
COMMENT ON TABLE tachograph_sync_logs IS 'デジタコ同期ログ';
COMMENT ON TABLE tachograph_instruction_sends IS '運行指示送信履歴';
COMMENT ON TABLE driving_evaluations IS '運転評価データ（安全運転・エコドライブスコア）';
COMMENT ON TABLE vehicle_location_history IS '車両位置情報履歴（リアルタイムトラッキング）';
