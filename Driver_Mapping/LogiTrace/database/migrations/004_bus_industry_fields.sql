-- ============================================
-- Migration: 004_bus_industry_fields.sql
-- Description: Bus industry features and dynamic industry-specific UI support
-- Date: 2026-01-17
-- ============================================

-- ============================================
-- 1. work_recordsテーブル拡張（バス・タクシー対応）
-- ============================================

-- 乗客数（タクシー・バス共通）
ALTER TABLE work_records ADD COLUMN IF NOT EXISTS num_passengers INTEGER DEFAULT 0;

-- 運行種別（バス用）
ALTER TABLE work_records ADD COLUMN IF NOT EXISTS operation_type VARCHAR(50);

-- 交替運転者ID（バス用：長距離運行時）
ALTER TABLE work_records ADD COLUMN IF NOT EXISTS co_driver_id INTEGER REFERENCES users(id);

-- 休憩記録（バス用：JSONBで複数の休憩を記録）
-- 例: [{"start_time": "10:30", "end_time": "10:45", "location": "SA名", "reason": "休憩"}]
ALTER TABLE work_records ADD COLUMN IF NOT EXISTS break_records JSONB DEFAULT '[]';

-- 運行指示書ID（バス用）
ALTER TABLE work_records ADD COLUMN IF NOT EXISTS operation_instruction_id INTEGER;

-- インデックス追加
CREATE INDEX IF NOT EXISTS idx_work_records_co_driver ON work_records(co_driver_id);
CREATE INDEX IF NOT EXISTS idx_work_records_operation_type ON work_records(operation_type);

-- ============================================
-- 2. 運行種別マスタ（Operation Type Master）
-- ============================================

CREATE TABLE IF NOT EXISTS operation_type_master (
  id SERIAL PRIMARY KEY,
  code VARCHAR(50) UNIQUE NOT NULL,
  name_ja VARCHAR(100) NOT NULL,
  name_en VARCHAR(100),
  industry_type_id INTEGER REFERENCES industry_types(id),
  description TEXT,
  display_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_operation_type_industry ON operation_type_master(industry_type_id);
CREATE INDEX IF NOT EXISTS idx_operation_type_active ON operation_type_master(is_active);

-- 初期データ: バス用運行種別
INSERT INTO operation_type_master (code, name_ja, name_en, industry_type_id, description, display_order) VALUES
('regular', '定期運行', 'Regular Service', (SELECT id FROM industry_types WHERE code='bus'), '路線バスなどの定期運行', 1),
('charter', '貸切運行', 'Charter Service', (SELECT id FROM industry_types WHERE code='bus'), '団体・観光等の貸切運行', 2),
('school', 'スクールバス', 'School Bus', (SELECT id FROM industry_types WHERE code='bus'), '通学バス', 3),
('shuttle', 'シャトルバス', 'Shuttle Bus', (SELECT id FROM industry_types WHERE code='bus'), '施設間送迎', 4),
('tour', '観光バス', 'Sightseeing Bus', (SELECT id FROM industry_types WHERE code='bus'), '観光ツアー', 5),
('highway', '高速バス', 'Highway Bus', (SELECT id FROM industry_types WHERE code='bus'), '高速道路利用の長距離運行', 6)
ON CONFLICT (code) DO NOTHING;

-- ============================================
-- 3. 運行指示書テーブル（Operation Instructions）
-- ============================================

CREATE TABLE IF NOT EXISTS operation_instructions (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id) NOT NULL,

  -- 指示書番号・日付
  instruction_number VARCHAR(50) NOT NULL,
  instruction_date DATE NOT NULL,

  -- 運行情報
  route_name VARCHAR(200),
  departure_location TEXT NOT NULL,
  arrival_location TEXT NOT NULL,
  via_points JSONB, -- 経由地: [{"name": "XX", "scheduled_time": "HH:MM"}]

  -- 予定時刻
  scheduled_departure_time TIME NOT NULL,
  scheduled_arrival_time TIME NOT NULL,

  -- 配車情報
  primary_driver_id INTEGER REFERENCES users(id),
  secondary_driver_id INTEGER REFERENCES users(id),
  vehicle_id INTEGER REFERENCES vehicles(id),

  -- 乗客情報
  expected_passengers INTEGER,
  group_name VARCHAR(200), -- 団体名（貸切の場合）
  contact_person VARCHAR(100), -- 担当者名
  contact_phone VARCHAR(20), -- 連絡先

  -- 休憩計画
  planned_breaks JSONB, -- [{"location": "XX SA", "scheduled_time": "HH:MM", "duration_minutes": 15}]

  -- 特記事項
  special_instructions TEXT,

  -- ステータス: draft(下書き), issued(発行済), in_progress(運行中), completed(完了), cancelled(中止)
  status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'issued', 'in_progress', 'completed', 'cancelled')),

  -- 実績（運行完了後に記録）
  actual_departure_time TIME,
  actual_arrival_time TIME,
  actual_passengers INTEGER,
  completion_notes TEXT,

  -- 作成者
  created_by INTEGER REFERENCES users(id),
  issued_by INTEGER REFERENCES users(id),
  issued_at TIMESTAMP,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  -- ユニーク制約
  UNIQUE(company_id, instruction_number)
);

CREATE INDEX IF NOT EXISTS idx_operation_instructions_company ON operation_instructions(company_id);
CREATE INDEX IF NOT EXISTS idx_operation_instructions_date ON operation_instructions(instruction_date);
CREATE INDEX IF NOT EXISTS idx_operation_instructions_status ON operation_instructions(status);
CREATE INDEX IF NOT EXISTS idx_operation_instructions_primary_driver ON operation_instructions(primary_driver_id);
CREATE INDEX IF NOT EXISTS idx_operation_instructions_secondary_driver ON operation_instructions(secondary_driver_id);
CREATE INDEX IF NOT EXISTS idx_operation_instructions_vehicle ON operation_instructions(vehicle_id);

-- work_recordsの外部キー追加（テーブル作成後）
ALTER TABLE work_records
ADD CONSTRAINT fk_work_records_operation_instruction
FOREIGN KEY (operation_instruction_id)
REFERENCES operation_instructions(id)
ON DELETE SET NULL;

-- ============================================
-- 4. 業種別フィールド表示設定マスタ
-- ============================================

CREATE TABLE IF NOT EXISTS industry_field_config (
  id SERIAL PRIMARY KEY,
  industry_type_id INTEGER REFERENCES industry_types(id) NOT NULL,
  field_name VARCHAR(50) NOT NULL,
  field_label_ja VARCHAR(100) NOT NULL,
  field_label_en VARCHAR(100),
  is_visible BOOLEAN DEFAULT TRUE,
  is_required BOOLEAN DEFAULT FALSE,
  display_order INTEGER DEFAULT 0,
  field_type VARCHAR(20) DEFAULT 'text', -- text, number, select, json
  default_value TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  UNIQUE(industry_type_id, field_name)
);

-- トラック用フィールド設定
INSERT INTO industry_field_config (industry_type_id, field_name, field_label_ja, field_label_en, is_visible, is_required, display_order, field_type) VALUES
((SELECT id FROM industry_types WHERE code='trucking'), 'distance', '走行距離', 'Distance', TRUE, TRUE, 1, 'number'),
((SELECT id FROM industry_types WHERE code='trucking'), 'cargo_weight', '積載量', 'Cargo Weight', TRUE, FALSE, 2, 'number'),
((SELECT id FROM industry_types WHERE code='trucking'), 'actual_distance', '実車距離', 'Loaded Distance', TRUE, FALSE, 3, 'number'),
((SELECT id FROM industry_types WHERE code='trucking'), 'num_passengers', '乗客数', 'Passengers', FALSE, FALSE, 10, 'number'),
((SELECT id FROM industry_types WHERE code='trucking'), 'revenue', '営業収入', 'Revenue', FALSE, FALSE, 11, 'number'),
((SELECT id FROM industry_types WHERE code='trucking'), 'operation_type', '運行種別', 'Operation Type', FALSE, FALSE, 12, 'select'),
((SELECT id FROM industry_types WHERE code='trucking'), 'co_driver_id', '交替運転者', 'Co-Driver', FALSE, FALSE, 13, 'select'),
((SELECT id FROM industry_types WHERE code='trucking'), 'break_records', '休憩記録', 'Break Records', FALSE, FALSE, 14, 'json')
ON CONFLICT (industry_type_id, field_name) DO NOTHING;

-- タクシー用フィールド設定
INSERT INTO industry_field_config (industry_type_id, field_name, field_label_ja, field_label_en, is_visible, is_required, display_order, field_type) VALUES
((SELECT id FROM industry_types WHERE code='taxi'), 'distance', '走行距離', 'Distance', TRUE, TRUE, 1, 'number'),
((SELECT id FROM industry_types WHERE code='taxi'), 'num_passengers', '乗客数', 'Passengers', TRUE, FALSE, 2, 'number'),
((SELECT id FROM industry_types WHERE code='taxi'), 'revenue', '営業収入', 'Revenue', TRUE, FALSE, 3, 'number'),
((SELECT id FROM industry_types WHERE code='taxi'), 'cargo_weight', '積載量', 'Cargo Weight', FALSE, FALSE, 10, 'number'),
((SELECT id FROM industry_types WHERE code='taxi'), 'actual_distance', '実車距離', 'Loaded Distance', FALSE, FALSE, 11, 'number'),
((SELECT id FROM industry_types WHERE code='taxi'), 'operation_type', '運行種別', 'Operation Type', FALSE, FALSE, 12, 'select'),
((SELECT id FROM industry_types WHERE code='taxi'), 'co_driver_id', '交替運転者', 'Co-Driver', FALSE, FALSE, 13, 'select'),
((SELECT id FROM industry_types WHERE code='taxi'), 'break_records', '休憩記録', 'Break Records', FALSE, FALSE, 14, 'json')
ON CONFLICT (industry_type_id, field_name) DO NOTHING;

-- バス用フィールド設定
INSERT INTO industry_field_config (industry_type_id, field_name, field_label_ja, field_label_en, is_visible, is_required, display_order, field_type) VALUES
((SELECT id FROM industry_types WHERE code='bus'), 'distance', '走行距離', 'Distance', TRUE, TRUE, 1, 'number'),
((SELECT id FROM industry_types WHERE code='bus'), 'num_passengers', '乗客数', 'Passengers', TRUE, FALSE, 2, 'number'),
((SELECT id FROM industry_types WHERE code='bus'), 'operation_type', '運行種別', 'Operation Type', TRUE, TRUE, 3, 'select'),
((SELECT id FROM industry_types WHERE code='bus'), 'co_driver_id', '交替運転者', 'Co-Driver', TRUE, FALSE, 4, 'select'),
((SELECT id FROM industry_types WHERE code='bus'), 'break_records', '休憩記録', 'Break Records', TRUE, FALSE, 5, 'json'),
((SELECT id FROM industry_types WHERE code='bus'), 'cargo_weight', '積載量', 'Cargo Weight', FALSE, FALSE, 10, 'number'),
((SELECT id FROM industry_types WHERE code='bus'), 'actual_distance', '実車距離', 'Loaded Distance', FALSE, FALSE, 11, 'number'),
((SELECT id FROM industry_types WHERE code='bus'), 'revenue', '営業収入', 'Revenue', FALSE, FALSE, 12, 'number')
ON CONFLICT (industry_type_id, field_name) DO NOTHING;

-- ============================================
-- 完了
-- ============================================
