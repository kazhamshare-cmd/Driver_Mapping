-- Migration: 005_work_record_workflow.sql
-- 運行記録ワークフロー改善（ドラフト→承認待ち→確定/差戻し）

-- ステータスを拡張（draft, pending, confirmed, rejected）
ALTER TABLE work_records
DROP CONSTRAINT IF EXISTS work_records_status_check;

ALTER TABLE work_records
ADD CONSTRAINT work_records_status_check
CHECK (status IN ('draft', 'pending', 'confirmed', 'rejected'));

-- ワークフロー関連カラム追加
ALTER TABLE work_records ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMP;
ALTER TABLE work_records ADD COLUMN IF NOT EXISTS approved_by INTEGER REFERENCES users(id);
ALTER TABLE work_records ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP;
ALTER TABLE work_records ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- 自動計算 vs 手動修正の記録
ALTER TABLE work_records ADD COLUMN IF NOT EXISTS auto_distance DECIMAL(10,2); -- GPS自動計算の走行距離
ALTER TABLE work_records ADD COLUMN IF NOT EXISTS auto_break_minutes INTEGER DEFAULT 0; -- 自動検出の休憩時間
ALTER TABLE work_records ADD COLUMN IF NOT EXISTS manual_break_minutes INTEGER; -- 手動入力の休憩時間
ALTER TABLE work_records ADD COLUMN IF NOT EXISTS correction_note TEXT; -- 修正理由メモ

-- 休憩記録テーブル（詳細な休憩情報）
CREATE TABLE IF NOT EXISTS break_records (
    id SERIAL PRIMARY KEY,
    work_record_id INTEGER REFERENCES work_records(id) ON DELETE CASCADE,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    duration_minutes INTEGER,
    location_name TEXT,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    detection_method VARCHAR(20) DEFAULT 'auto' CHECK (detection_method IN ('auto', 'manual')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_break_records_work_record ON break_records(work_record_id);

-- 運行管理者確認記録テーブル
CREATE TABLE IF NOT EXISTS manager_confirmations (
    id SERIAL PRIMARY KEY,
    work_record_id INTEGER REFERENCES work_records(id) ON DELETE CASCADE,
    manager_id INTEGER REFERENCES users(id) NOT NULL,
    action VARCHAR(20) NOT NULL CHECK (action IN ('approve', 'reject', 'request_correction')),
    comment TEXT,
    signature_data TEXT, -- 電子署名データ（Base64）
    confirmed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_manager_confirmations_work_record ON manager_confirmations(work_record_id);
CREATE INDEX IF NOT EXISTS idx_manager_confirmations_manager ON manager_confirmations(manager_id);

-- デジタコインポート履歴テーブル
CREATE TABLE IF NOT EXISTS tachograph_imports (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id),
    file_name VARCHAR(255) NOT NULL,
    file_type VARCHAR(50), -- 'yazaki', 'fujitsu', 'denso' etc.
    import_date DATE NOT NULL,
    records_count INTEGER DEFAULT 0,
    matched_count INTEGER DEFAULT 0, -- work_recordsとマッチした件数
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    error_message TEXT,
    uploaded_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- デジタコデータテーブル（インポートされた生データ）
CREATE TABLE IF NOT EXISTS tachograph_data (
    id SERIAL PRIMARY KEY,
    import_id INTEGER REFERENCES tachograph_imports(id) ON DELETE CASCADE,
    work_record_id INTEGER REFERENCES work_records(id), -- マッチした運行記録
    driver_code VARCHAR(50),
    vehicle_number VARCHAR(50),
    record_date DATE NOT NULL,
    start_time TIME,
    end_time TIME,
    distance DECIMAL(10,2),
    max_speed DECIMAL(5,2),
    avg_speed DECIMAL(5,2),
    idle_time_minutes INTEGER,
    driving_time_minutes INTEGER,
    rest_time_minutes INTEGER,
    harsh_braking_count INTEGER DEFAULT 0,
    harsh_acceleration_count INTEGER DEFAULT 0,
    speeding_count INTEGER DEFAULT 0,
    raw_data JSONB, -- 機種固有の詳細データ
    match_status VARCHAR(20) DEFAULT 'unmatched' CHECK (match_status IN ('unmatched', 'matched', 'conflict')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_tachograph_data_import ON tachograph_data(import_id);
CREATE INDEX IF NOT EXISTS idx_tachograph_data_work_record ON tachograph_data(work_record_id);
CREATE INDEX IF NOT EXISTS idx_tachograph_data_date ON tachograph_data(record_date);
CREATE INDEX IF NOT EXISTS idx_tachograph_data_driver ON tachograph_data(driver_code);

-- 監査帳票に署名欄追加
ALTER TABLE audit_exports ADD COLUMN IF NOT EXISTS manager_name VARCHAR(100);
ALTER TABLE audit_exports ADD COLUMN IF NOT EXISTS manager_signature TEXT;
ALTER TABLE audit_exports ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMP;

-- 既存データのステータスをconfirmedに設定（後方互換性）
UPDATE work_records SET status = 'confirmed' WHERE status IS NULL OR status = '';

-- ビュー: 承認待ち運行記録一覧（管理者用）
CREATE OR REPLACE VIEW pending_work_records AS
SELECT
    wr.id,
    wr.work_date,
    wr.start_time,
    wr.end_time,
    wr.distance,
    wr.auto_distance,
    wr.manual_break_minutes,
    wr.auto_break_minutes,
    wr.correction_note,
    wr.submitted_at,
    d.id as driver_id,
    d.name as driver_name,
    d.employee_number,
    v.vehicle_number,
    c.id as company_id,
    c.name as company_name
FROM work_records wr
JOIN users d ON wr.driver_id = d.id
LEFT JOIN vehicles v ON wr.vehicle_id = v.id
JOIN companies c ON d.company_id = c.id
WHERE wr.status = 'pending'
ORDER BY wr.submitted_at DESC;

-- ビュー: 日次運行サマリー（ダッシュボード用）
CREATE OR REPLACE VIEW daily_work_summary AS
SELECT
    wr.work_date,
    c.id as company_id,
    COUNT(DISTINCT wr.driver_id) as active_drivers,
    COUNT(wr.id) as total_records,
    SUM(CASE WHEN wr.status = 'confirmed' THEN 1 ELSE 0 END) as confirmed_count,
    SUM(CASE WHEN wr.status = 'pending' THEN 1 ELSE 0 END) as pending_count,
    SUM(CASE WHEN wr.status = 'draft' THEN 1 ELSE 0 END) as draft_count,
    SUM(wr.distance) as total_distance,
    SUM(COALESCE(wr.manual_break_minutes, wr.auto_break_minutes, 0)) as total_break_minutes
FROM work_records wr
JOIN users d ON wr.driver_id = d.id
JOIN companies c ON d.company_id = c.id
GROUP BY wr.work_date, c.id
ORDER BY wr.work_date DESC;

COMMENT ON TABLE break_records IS '休憩記録（GPS自動検出または手動入力）';
COMMENT ON TABLE manager_confirmations IS '運行管理者の確認・承認履歴';
COMMENT ON TABLE tachograph_imports IS 'デジタコファイルインポート履歴';
COMMENT ON TABLE tachograph_data IS 'デジタコから取り込んだ走行データ';
COMMENT ON COLUMN work_records.auto_distance IS 'GPS自動計算の走行距離（修正前の値）';
COMMENT ON COLUMN work_records.auto_break_minutes IS 'GPS停止から自動検出した休憩時間';
COMMENT ON COLUMN work_records.manual_break_minutes IS 'ドライバーが修正した休憩時間';
COMMENT ON COLUMN work_records.correction_note IS '距離・時間を修正した場合の理由';
