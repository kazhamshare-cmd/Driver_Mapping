-- Companies table
CREATE TABLE companies (
  id SERIAL PRIMARY KEY,
  company_code VARCHAR(8) UNIQUE NOT NULL, -- 8文字のユニークコード（ドライバー登録用）
  name VARCHAR(200) NOT NULL,
  email VARCHAR(255),
  phone VARCHAR(20),
  address TEXT,
  stripe_customer_id VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Users table
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id),
  user_type VARCHAR(20) NOT NULL CHECK (user_type IN ('driver', 'admin')),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255),
  name VARCHAR(100) NOT NULL,
  employee_number VARCHAR(50),
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'pending')),
  invite_token VARCHAR(255),
  invite_expires_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_company_id ON users(company_id);
CREATE INDEX idx_users_invite_token ON users(invite_token);

-- Vehicles table
CREATE TABLE vehicles (
  id SERIAL PRIMARY KEY,
  vehicle_number VARCHAR(50) UNIQUE NOT NULL,
  vehicle_type VARCHAR(50), -- '4t', '10t' etc.
  max_capacity DECIMAL(10,2), -- Maximum capacity in tons
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Work Records table
CREATE TABLE work_records (
  id SERIAL PRIMARY KEY,
  driver_id INTEGER REFERENCES users(id),
  vehicle_id INTEGER REFERENCES vehicles(id),
  work_date DATE NOT NULL,
  start_time TIMESTAMP NOT NULL,
  end_time TIMESTAMP,
  record_method VARCHAR(20) NOT NULL CHECK (record_method IN ('gps', 'manual')),
  
  -- Location info (only for GPS records)
  start_latitude DECIMAL(10,8),
  start_longitude DECIMAL(11,8),
  start_address TEXT,
  end_latitude DECIMAL(10,8),
  end_longitude DECIMAL(11,8),
  end_address TEXT,
  
  -- Achievement data
  distance DECIMAL(10,2) NOT NULL DEFAULT 0, -- Distance in km
  actual_distance DECIMAL(10,2) DEFAULT 0, -- Loaded Distance in km (Jissha)
  cargo_weight DECIMAL(10,2) DEFAULT 0, -- Cargo weight in tons
  revenue DECIMAL(12,2) DEFAULT 0, -- Operating Revenue for this record (optional)
  
  -- Other info
  has_incident BOOLEAN DEFAULT FALSE,
  incident_detail TEXT,
  status VARCHAR(20) DEFAULT 'confirmed', -- confirmed/pending...
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_work_records_work_date ON work_records(work_date);
CREATE INDEX idx_work_records_driver_id ON work_records(driver_id);

-- GPS Tracks table
CREATE TABLE gps_tracks (
  id SERIAL PRIMARY KEY,
  work_record_id INTEGER REFERENCES work_records(id),
  timestamp TIMESTAMP NOT NULL,
  latitude DECIMAL(10,8) NOT NULL,
  longitude DECIMAL(11,8) NOT NULL,
  speed DECIMAL(5,2), -- Speed in km/h
  accuracy DECIMAL(6,2), -- Accuracy in meters
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_gps_tracks_work_record_id ON gps_tracks(work_record_id);
CREATE INDEX idx_gps_tracks_timestamp ON gps_tracks(timestamp);

-- Reports table (Administrative reports)
CREATE TABLE reports (
  id SERIAL PRIMARY KEY,
  report_type VARCHAR(50) NOT NULL, -- 'annual_business', etc.
  fiscal_year INTEGER NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  
  -- Aggregated data stored as JSON
  summary_data JSONB,
  
  -- Generated PDF URL
  pdf_url TEXT,
  
  status VARCHAR(20) DEFAULT 'draft', -- draft/completed
  created_by INTEGER REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Subscriptions table
CREATE TABLE subscriptions (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id),
  plan_id VARCHAR(50) NOT NULL, -- 'small', 'standard', 'pro', 'enterprise'
  stripe_subscription_id VARCHAR(255) UNIQUE,
  stripe_customer_id VARCHAR(255),
  status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'canceled', 'past_due', 'trialing')),
  current_driver_count INTEGER DEFAULT 0,
  max_driver_count INTEGER NOT NULL,
  trial_end TIMESTAMP,
  current_period_start TIMESTAMP,
  current_period_end TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_subscriptions_company_id ON subscriptions(company_id);
CREATE INDEX idx_subscriptions_stripe_subscription_id ON subscriptions(stripe_subscription_id);

-- Vehicles - add company_id
ALTER TABLE vehicles ADD COLUMN company_id INTEGER REFERENCES companies(id);
CREATE INDEX idx_vehicles_company_id ON vehicles(company_id);

-- ============================================
-- コンプライアンス機能用テーブル
-- ============================================

-- 点呼記録簿 (Tenko Records)
CREATE TABLE tenko_records (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id) NOT NULL,
  driver_id INTEGER REFERENCES users(id) NOT NULL,
  work_record_id INTEGER REFERENCES work_records(id),

  -- 点呼種別: 乗務前(pre) / 乗務後(post)
  tenko_type VARCHAR(20) NOT NULL CHECK (tenko_type IN ('pre', 'post')),

  -- 日時
  tenko_date DATE NOT NULL,
  tenko_time TIMESTAMP NOT NULL,

  -- 点呼方法: 対面(face_to_face) / IT点呼(it_tenko) / 電話(phone)
  method VARCHAR(20) NOT NULL CHECK (method IN ('face_to_face', 'it_tenko', 'phone')),

  -- 健康状態
  health_status VARCHAR(20) NOT NULL CHECK (health_status IN ('good', 'fair', 'poor')),
  health_notes TEXT,

  -- アルコールチェック (mg/L)
  alcohol_level DECIMAL(4,3) NOT NULL DEFAULT 0.000,
  alcohol_check_passed BOOLEAN NOT NULL DEFAULT TRUE,
  alcohol_device_id VARCHAR(100),

  -- 疲労度 (1-5: 1=元気, 5=疲労)
  fatigue_level INTEGER NOT NULL CHECK (fatigue_level BETWEEN 1 AND 5),

  -- 睡眠時間（乗務前点呼用）
  sleep_hours DECIMAL(3,1),
  sleep_sufficient BOOLEAN,

  -- 点呼執行者・運転者情報
  inspector_id INTEGER REFERENCES users(id) NOT NULL,
  inspector_name VARCHAR(100) NOT NULL,
  driver_name VARCHAR(100) NOT NULL,

  -- 電子署名（Base64）
  driver_signature TEXT,
  inspector_signature TEXT,

  -- 備考
  notes TEXT,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_tenko_company_date ON tenko_records(company_id, tenko_date);
CREATE INDEX idx_tenko_driver_date ON tenko_records(driver_id, tenko_date);
CREATE INDEX idx_tenko_work_record ON tenko_records(work_record_id);

-- 日常点検記録簿 (Vehicle Inspection Records)
CREATE TABLE vehicle_inspection_records (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id) NOT NULL,
  vehicle_id INTEGER REFERENCES vehicles(id) NOT NULL,
  driver_id INTEGER REFERENCES users(id) NOT NULL,
  work_record_id INTEGER REFERENCES work_records(id),

  -- 日時
  inspection_date DATE NOT NULL,
  inspection_time TIMESTAMP NOT NULL,

  -- 総合判定: 合格(pass) / 不合格(fail) / 条件付き(conditional)
  overall_result VARCHAR(20) NOT NULL CHECK (overall_result IN ('pass', 'fail', 'conditional')),

  -- 点検項目（JSONB形式）
  -- 例: { "tires": { "result": "pass", "notes": "" }, "brakes": { "result": "pass", "notes": "" } }
  inspection_items JSONB NOT NULL,

  -- 走行距離計の読み
  odometer_reading INTEGER,

  -- 電子署名
  inspector_signature TEXT,

  -- 備考・問題点
  notes TEXT,
  issues_found TEXT,
  follow_up_required BOOLEAN DEFAULT FALSE,
  follow_up_notes TEXT,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_inspection_company_date ON vehicle_inspection_records(company_id, inspection_date);
CREATE INDEX idx_inspection_vehicle_date ON vehicle_inspection_records(vehicle_id, inspection_date);
CREATE INDEX idx_inspection_driver ON vehicle_inspection_records(driver_id);
CREATE INDEX idx_inspection_work_record ON vehicle_inspection_records(work_record_id);

-- 点検項目マスタ (Inspection Item Master)
CREATE TABLE inspection_item_master (
  id SERIAL PRIMARY KEY,
  item_key VARCHAR(50) UNIQUE NOT NULL,
  item_name_ja VARCHAR(100) NOT NULL,
  item_name_en VARCHAR(100),
  category VARCHAR(50) NOT NULL, -- exterior, engine, cabin, lights, safety
  is_required BOOLEAN DEFAULT TRUE,
  display_order INTEGER DEFAULT 0,
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 法定点検項目の初期データ
INSERT INTO inspection_item_master (item_key, item_name_ja, item_name_en, category, is_required, display_order) VALUES
('tires', 'タイヤ', 'Tires', 'exterior', TRUE, 1),
('tires_air_pressure', 'タイヤ空気圧', 'Tire Air Pressure', 'exterior', TRUE, 2),
('brakes', 'ブレーキ', 'Brakes', 'safety', TRUE, 3),
('parking_brake', 'パーキングブレーキ', 'Parking Brake', 'safety', TRUE, 4),
('lights_headlights', 'ヘッドライト', 'Headlights', 'lights', TRUE, 5),
('lights_tail', 'テールランプ', 'Tail Lights', 'lights', TRUE, 6),
('lights_turn_signals', 'ウインカー', 'Turn Signals', 'lights', TRUE, 7),
('lights_brake', 'ブレーキランプ', 'Brake Lights', 'lights', TRUE, 8),
('mirrors', 'ミラー', 'Mirrors', 'exterior', TRUE, 9),
('wipers', 'ワイパー', 'Wipers', 'cabin', TRUE, 10),
('washer_fluid', 'ウォッシャー液', 'Washer Fluid', 'cabin', TRUE, 11),
('horn', 'ホーン', 'Horn', 'safety', TRUE, 12),
('fuel', '燃料', 'Fuel', 'engine', TRUE, 13),
('engine_oil', 'エンジンオイル', 'Engine Oil', 'engine', TRUE, 14),
('cooling_water', '冷却水', 'Cooling Water', 'engine', TRUE, 15),
('battery', 'バッテリー', 'Battery', 'engine', TRUE, 16),
('fan_belt', 'ファンベルト', 'Fan Belt', 'engine', FALSE, 17),
('steering', 'ステアリング', 'Steering', 'safety', TRUE, 18),
('doors_locks', 'ドア・ロック', 'Doors & Locks', 'cabin', TRUE, 19),
('emergency_equipment', '非常用機材', 'Emergency Equipment', 'safety', TRUE, 20),
('fire_extinguisher', '消火器', 'Fire Extinguisher', 'safety', TRUE, 21),
('first_aid_kit', '救急箱', 'First Aid Kit', 'safety', FALSE, 22);

-- デジタコインポート履歴 (Tachograph Import History)
CREATE TABLE tachograph_imports (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id) NOT NULL,

  -- ファイル情報
  file_name VARCHAR(255) NOT NULL,
  file_type VARCHAR(50) NOT NULL, -- 'yazaki', 'denso', 'manual'
  file_size INTEGER,

  -- インポートステータス
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),

  -- インポート結果
  records_imported INTEGER DEFAULT 0,
  records_failed INTEGER DEFAULT 0,
  error_log JSONB, -- エラー詳細: [{ row: N, error: "..." }]

  -- アップロード者
  uploaded_by INTEGER REFERENCES users(id) NOT NULL,

  -- 処理時間
  started_at TIMESTAMP,
  completed_at TIMESTAMP,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_tachograph_company ON tachograph_imports(company_id);
CREATE INDEX idx_tachograph_status ON tachograph_imports(status);

-- 監査用出力履歴 (Audit Export History)
CREATE TABLE audit_exports (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id) NOT NULL,

  -- 出力パラメータ
  export_type VARCHAR(50) NOT NULL, -- 'three_point_set', 'nippo_only', 'tenko_only', 'tenken_only'
  date_from DATE NOT NULL,
  date_to DATE NOT NULL,
  driver_ids INTEGER[], -- 対象ドライバー（NULLは全員）
  vehicle_ids INTEGER[], -- 対象車両（NULLは全て）

  -- 生成ファイル
  pdf_url TEXT,
  file_size INTEGER,
  page_count INTEGER,

  -- ステータス
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'generating', 'completed', 'failed')),
  error_message TEXT,

  -- 生成者
  generated_by INTEGER REFERENCES users(id) NOT NULL,

  -- タイムスタンプ
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  expires_at TIMESTAMP, -- 自動削除期限

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_exports_company ON audit_exports(company_id);
CREATE INDEX idx_audit_exports_status ON audit_exports(status);

-- ============================================
-- マルチ業界対応機能用テーブル
-- ============================================

-- 業種マスタ (Industry Types)
CREATE TABLE industry_types (
  id SERIAL PRIMARY KEY,
  code VARCHAR(20) UNIQUE NOT NULL,
  name_ja VARCHAR(100) NOT NULL,
  name_en VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO industry_types (code, name_ja, name_en) VALUES
('trucking', 'トラック運送', 'Trucking'),
('taxi', 'タクシー', 'Taxi'),
('bus', 'バス', 'Bus');

-- 会社テーブル拡張
ALTER TABLE companies ADD COLUMN IF NOT EXISTS industry_type_id INTEGER REFERENCES industry_types(id);
ALTER TABLE companies ADD COLUMN IF NOT EXISTS business_license_number VARCHAR(100);
ALTER TABLE companies ADD COLUMN IF NOT EXISTS safety_manager_name VARCHAR(100);
ALTER TABLE companies ADD COLUMN IF NOT EXISTS operation_manager_name VARCHAR(100);

-- 車両タイプマスタ (Vehicle Type Master)
CREATE TABLE vehicle_type_master (
  id SERIAL PRIMARY KEY,
  industry_type_id INTEGER REFERENCES industry_types(id),
  code VARCHAR(50) NOT NULL,
  name_ja VARCHAR(100) NOT NULL,
  name_en VARCHAR(100),
  capacity_unit VARCHAR(20),
  max_capacity DECIMAL(10,2),
  is_active BOOLEAN DEFAULT TRUE,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(industry_type_id, code)
);

INSERT INTO vehicle_type_master (industry_type_id, code, name_ja, name_en, capacity_unit, max_capacity, display_order) VALUES
((SELECT id FROM industry_types WHERE code='trucking'), '2t', '2トン車', '2-ton Truck', 'tons', 2, 1),
((SELECT id FROM industry_types WHERE code='trucking'), '4t', '4トン車', '4-ton Truck', 'tons', 4, 2),
((SELECT id FROM industry_types WHERE code='trucking'), '10t', '10トン車', '10-ton Truck', 'tons', 10, 3),
((SELECT id FROM industry_types WHERE code='trucking'), 'trailer', 'トレーラー', 'Trailer', 'tons', 25, 4),
((SELECT id FROM industry_types WHERE code='taxi'), 'sedan', 'セダン', 'Sedan', 'passengers', 4, 1),
((SELECT id FROM industry_types WHERE code='taxi'), 'wagon', 'ワゴン', 'Wagon', 'passengers', 6, 2),
((SELECT id FROM industry_types WHERE code='taxi'), 'jumbo', 'ジャンボ', 'Jumbo Taxi', 'passengers', 9, 3),
((SELECT id FROM industry_types WHERE code='bus'), 'micro', 'マイクロバス', 'Microbus', 'passengers', 20, 1),
((SELECT id FROM industry_types WHERE code='bus'), 'medium', '中型バス', 'Medium Bus', 'passengers', 40, 2),
((SELECT id FROM industry_types WHERE code='bus'), 'large', '大型バス', 'Large Bus', 'passengers', 60, 3);

-- 運転者台帳 (Driver Registry)
CREATE TABLE driver_registries (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id) NOT NULL,
  driver_id INTEGER REFERENCES users(id) NOT NULL UNIQUE,

  -- 基本情報
  full_name VARCHAR(100) NOT NULL,
  full_name_kana VARCHAR(100),
  birth_date DATE,
  address TEXT,
  phone VARCHAR(20),
  emergency_contact VARCHAR(100),
  emergency_phone VARCHAR(20),
  hire_date DATE NOT NULL,
  termination_date DATE,

  -- 免許情報
  license_number VARCHAR(50) NOT NULL,
  license_type VARCHAR(50) NOT NULL,
  license_expiry_date DATE NOT NULL,
  license_conditions TEXT,
  license_image_url TEXT,

  -- 資格
  hazmat_license BOOLEAN DEFAULT FALSE,
  hazmat_expiry_date DATE,
  forklift_license BOOLEAN DEFAULT FALSE,
  second_class_license BOOLEAN DEFAULT FALSE,
  other_qualifications JSONB,

  -- ステータス
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
  notes TEXT,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_driver_registries_company ON driver_registries(company_id);
CREATE INDEX idx_driver_registries_driver ON driver_registries(driver_id);
CREATE INDEX idx_driver_registries_license_expiry ON driver_registries(license_expiry_date);
CREATE INDEX idx_driver_registries_status ON driver_registries(status);

-- 健康診断記録 (Health Checkup Records)
CREATE TABLE health_checkup_records (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id) NOT NULL,
  driver_id INTEGER REFERENCES users(id) NOT NULL,

  -- 診断種別: 定期(regular) / 特殊(special) / 雇入時(pre_employment)
  checkup_type VARCHAR(50) NOT NULL CHECK (checkup_type IN ('regular', 'special', 'pre_employment')),
  checkup_date DATE NOT NULL,
  next_checkup_date DATE,
  facility_name VARCHAR(200),

  -- 結果: 異常なし(normal) / 要経過観察(observation) / 要治療(treatment) / 就業制限(work_restriction)
  overall_result VARCHAR(20) NOT NULL CHECK (overall_result IN ('normal', 'observation', 'treatment', 'work_restriction')),
  result_details JSONB,
  work_restriction_notes TEXT,

  -- 書類
  certificate_url TEXT,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_health_checkup_company ON health_checkup_records(company_id);
CREATE INDEX idx_health_checkup_driver ON health_checkup_records(driver_id);
CREATE INDEX idx_health_checkup_date ON health_checkup_records(checkup_date);
CREATE INDEX idx_health_checkup_next_date ON health_checkup_records(next_checkup_date);

-- 適性診断記録 (Aptitude Test Records)
CREATE TABLE aptitude_test_records (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id) NOT NULL,
  driver_id INTEGER REFERENCES users(id) NOT NULL,

  -- 診断種別: 初任(initial) / 適齢(age_based) / 特定(specific) / 一般(voluntary)
  test_type VARCHAR(50) NOT NULL CHECK (test_type IN ('initial', 'age_based', 'specific', 'voluntary')),
  test_date DATE NOT NULL,
  next_test_date DATE,
  facility_name VARCHAR(200),

  -- 結果
  overall_score INTEGER,
  result_summary TEXT,
  recommendations TEXT,

  -- 書類
  certificate_url TEXT,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_aptitude_test_company ON aptitude_test_records(company_id);
CREATE INDEX idx_aptitude_test_driver ON aptitude_test_records(driver_id);
CREATE INDEX idx_aptitude_test_date ON aptitude_test_records(test_date);
CREATE INDEX idx_aptitude_test_next_date ON aptitude_test_records(next_test_date);

-- 教育・研修記録 (Training Records)
CREATE TABLE training_records (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id) NOT NULL,
  driver_id INTEGER REFERENCES users(id) NOT NULL,

  -- 研修情報
  training_type VARCHAR(50) NOT NULL,
  training_name VARCHAR(200) NOT NULL,
  training_date DATE NOT NULL,
  duration_hours DECIMAL(4,1),
  instructor_name VARCHAR(100),
  location VARCHAR(200),

  -- 内容
  content_summary TEXT,
  materials_used TEXT,

  -- 結果: 完了(completed) / 未完了(incomplete) / 予定(scheduled)
  completion_status VARCHAR(20) DEFAULT 'completed' CHECK (completion_status IN ('completed', 'incomplete', 'scheduled')),
  test_score INTEGER,
  certificate_url TEXT,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_training_company ON training_records(company_id);
CREATE INDEX idx_training_driver ON training_records(driver_id);
CREATE INDEX idx_training_date ON training_records(training_date);
CREATE INDEX idx_training_type ON training_records(training_type);

-- 研修種別マスタ (Training Type Master)
CREATE TABLE training_type_master (
  id SERIAL PRIMARY KEY,
  code VARCHAR(50) UNIQUE NOT NULL,
  name_ja VARCHAR(100) NOT NULL,
  name_en VARCHAR(100),
  description TEXT,
  is_mandatory BOOLEAN DEFAULT FALSE,
  frequency_months INTEGER,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO training_type_master (code, name_ja, name_en, is_mandatory, frequency_months, display_order) VALUES
('initial', '初任運転者教育', 'Initial Driver Training', TRUE, NULL, 1),
('safety_basic', '安全運転基礎', 'Basic Safety Driving', TRUE, 12, 2),
('cargo_handling', '貨物取扱い', 'Cargo Handling', FALSE, NULL, 3),
('passenger_service', '接客・サービス', 'Passenger Service', FALSE, NULL, 4),
('emergency_response', '緊急時対応', 'Emergency Response', TRUE, 12, 5),
('eco_driving', 'エコドライブ', 'Eco Driving', FALSE, NULL, 6),
('health_management', '健康管理', 'Health Management', FALSE, 12, 7),
('law_regulation', '法令・規則', 'Laws & Regulations', TRUE, 12, 8);

-- 事故・違反履歴 (Accident/Violation Records)
CREATE TABLE accident_violation_records (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id) NOT NULL,
  driver_id INTEGER REFERENCES users(id) NOT NULL,
  vehicle_id INTEGER REFERENCES vehicles(id),

  -- 種別: 事故(accident) / 違反(violation)
  record_type VARCHAR(20) NOT NULL CHECK (record_type IN ('accident', 'violation')),
  incident_date DATE NOT NULL,
  incident_time TIME,
  location TEXT,

  -- 詳細
  description TEXT NOT NULL,
  severity VARCHAR(20) CHECK (severity IN ('minor', 'moderate', 'severe', 'fatal')),
  is_at_fault BOOLEAN,

  -- 違反の場合
  violation_type VARCHAR(100),
  violation_code VARCHAR(50),
  points_deducted INTEGER,
  fine_amount INTEGER,

  -- 事故の場合
  accident_type VARCHAR(100),
  damage_amount INTEGER,
  injury_count INTEGER,
  fatality_count INTEGER DEFAULT 0,
  police_report_number VARCHAR(100),
  insurance_claim_number VARCHAR(100),

  -- 対応
  corrective_action TEXT,
  follow_up_training_required BOOLEAN DEFAULT FALSE,
  follow_up_training_completed BOOLEAN DEFAULT FALSE,
  follow_up_training_date DATE,

  -- 書類
  documents JSONB,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_accident_company ON accident_violation_records(company_id);
CREATE INDEX idx_accident_driver ON accident_violation_records(driver_id);
CREATE INDEX idx_accident_date ON accident_violation_records(incident_date);
CREATE INDEX idx_accident_type ON accident_violation_records(record_type);
CREATE INDEX idx_accident_severity ON accident_violation_records(severity);

-- ============================================
-- REST API連携機能用テーブル（プロプラン以上）
-- ============================================

-- APIキー管理 (API Keys)
CREATE TABLE api_keys (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id) NOT NULL,

  -- キー情報
  key_name VARCHAR(100) NOT NULL,
  api_key VARCHAR(64) UNIQUE NOT NULL, -- SHA256ハッシュ形式
  key_prefix VARCHAR(8) NOT NULL, -- 表示用プレフィックス (lt_live_xxxx)

  -- 権限スコープ
  scopes JSONB NOT NULL DEFAULT '["read"]', -- ["read", "write", "delete"]

  -- 制限
  rate_limit_per_minute INTEGER DEFAULT 60,
  allowed_ips TEXT[], -- NULLは全IP許可

  -- ステータス
  is_active BOOLEAN DEFAULT TRUE,
  last_used_at TIMESTAMP,
  usage_count INTEGER DEFAULT 0,

  -- 有効期限
  expires_at TIMESTAMP,

  -- 作成者
  created_by INTEGER REFERENCES users(id) NOT NULL,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_api_keys_company ON api_keys(company_id);
CREATE INDEX idx_api_keys_api_key ON api_keys(api_key);
CREATE INDEX idx_api_keys_active ON api_keys(is_active);

-- APIリクエストログ (API Request Logs)
CREATE TABLE api_request_logs (
  id SERIAL PRIMARY KEY,
  api_key_id INTEGER REFERENCES api_keys(id),
  company_id INTEGER REFERENCES companies(id) NOT NULL,

  -- リクエスト情報
  endpoint VARCHAR(255) NOT NULL,
  method VARCHAR(10) NOT NULL,
  request_ip VARCHAR(45),
  user_agent TEXT,

  -- レスポンス情報
  status_code INTEGER NOT NULL,
  response_time_ms INTEGER,

  -- エラー情報
  error_message TEXT,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_api_logs_key ON api_request_logs(api_key_id);
CREATE INDEX idx_api_logs_company ON api_request_logs(company_id);
CREATE INDEX idx_api_logs_created ON api_request_logs(created_at);

-- Webhook設定 (Webhook Configurations)
CREATE TABLE webhook_configs (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id) NOT NULL,

  -- Webhook情報
  webhook_name VARCHAR(100) NOT NULL,
  webhook_url TEXT NOT NULL,
  secret_key VARCHAR(64) NOT NULL, -- HMAC署名用

  -- イベント設定
  events JSONB NOT NULL DEFAULT '[]',
  -- ["license_expiring", "health_checkup_due", "tenko_completed", "inspection_failed"]

  -- ステータス
  is_active BOOLEAN DEFAULT TRUE,
  last_triggered_at TIMESTAMP,
  failure_count INTEGER DEFAULT 0,

  created_by INTEGER REFERENCES users(id) NOT NULL,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_webhook_company ON webhook_configs(company_id);
CREATE INDEX idx_webhook_active ON webhook_configs(is_active);
