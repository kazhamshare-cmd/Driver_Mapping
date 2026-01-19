-- ============================================
-- Phase 7: 取適法対応・実運送体制管理簿・AI連携
-- ============================================

-- ============================================
-- 7.1 取適法対応（トラック運送業における下請取引適正化）
-- ============================================

-- 取引条件書（書面交付義務対応）
CREATE TABLE IF NOT EXISTS transaction_terms (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id),
    shipper_id INTEGER REFERENCES shippers(id),

    -- 取引条件
    terms_number VARCHAR(50) NOT NULL,           -- 取引条件書番号
    effective_date DATE NOT NULL,                -- 適用開始日
    expiry_date DATE,                            -- 適用終了日

    -- 運送条件
    cargo_type VARCHAR(100),                     -- 貨物の種類
    transport_mode VARCHAR(50),                  -- 輸送形態（貸切/積合等）
    route_description TEXT,                      -- 運送区間

    -- 料金条件
    base_fare_type VARCHAR(20),                  -- 運賃種別（距離制/時間制/個建等）
    base_fare_amount DECIMAL(12,2),              -- 基本運賃
    fuel_surcharge_type VARCHAR(20),             -- 燃料サーチャージ方式
    fuel_surcharge_rate DECIMAL(5,2),            -- 燃料サーチャージ率

    -- 附帯作業料金
    loading_fee DECIMAL(10,2) DEFAULT 0,         -- 積込料
    unloading_fee DECIMAL(10,2) DEFAULT 0,       -- 取卸料
    waiting_fee_per_hour DECIMAL(10,2) DEFAULT 0, -- 待機料（時間単価）
    detention_fee_per_hour DECIMAL(10,2) DEFAULT 0, -- 留置料（時間単価）

    -- 支払条件
    payment_terms VARCHAR(100),                  -- 支払条件（月末締め翌月末払い等）
    payment_method VARCHAR(50),                  -- 支払方法

    -- 書面交付
    document_issued_date DATE,                   -- 書面交付日
    document_received_confirmed BOOLEAN DEFAULT FALSE, -- 受領確認
    document_pdf_url TEXT,                       -- PDF保存URL

    status VARCHAR(20) DEFAULT 'active',         -- active/expired/terminated
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 取引条件の変更履歴
CREATE TABLE IF NOT EXISTS transaction_terms_history (
    id SERIAL PRIMARY KEY,
    terms_id INTEGER REFERENCES transaction_terms(id),
    changed_by INTEGER REFERENCES users(id),
    change_type VARCHAR(50),                     -- created/modified/terminated
    change_reason TEXT,
    previous_values JSONB,                       -- 変更前の値
    new_values JSONB,                            -- 変更後の値
    changed_at TIMESTAMP DEFAULT NOW()
);

-- 不当な取引行為の記録（取適法違反リスク管理）
CREATE TABLE IF NOT EXISTS unfair_practice_records (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id),
    shipper_id INTEGER REFERENCES shippers(id),

    incident_date DATE NOT NULL,
    practice_type VARCHAR(50) NOT NULL,          -- price_cut/payment_delay/forced_discount等
    description TEXT NOT NULL,

    -- 詳細
    original_amount DECIMAL(12,2),               -- 本来の金額
    actual_amount DECIMAL(12,2),                 -- 実際の金額
    difference_amount DECIMAL(12,2),             -- 差額

    -- 対応状況
    reported_to_authority BOOLEAN DEFAULT FALSE, -- 行政への報告
    reported_date DATE,
    resolution_status VARCHAR(20) DEFAULT 'pending', -- pending/resolved/escalated
    resolution_notes TEXT,

    evidence_files JSONB,                        -- 証拠ファイルURL
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 7.2 実運送体制管理簿（2024年法改正対応）
-- ============================================

-- 運送委託契約
CREATE TABLE IF NOT EXISTS subcontract_agreements (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id),

    -- 元請情報
    prime_contractor_name VARCHAR(200) NOT NULL,
    prime_contractor_permit_number VARCHAR(50),  -- 許可番号
    prime_contractor_address TEXT,

    -- 下請情報（自社が下請の場合）
    subcontractor_tier INTEGER DEFAULT 1,        -- 何次下請か（1=直接受託, 2=2次下請...）

    -- 契約情報
    agreement_number VARCHAR(50),
    agreement_date DATE,
    agreement_start_date DATE,
    agreement_end_date DATE,

    -- 取引条件
    commission_rate DECIMAL(5,2),                -- 手数料率
    payment_terms TEXT,

    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 実運送体制管理簿
CREATE TABLE IF NOT EXISTS actual_transport_records (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id),
    order_id INTEGER REFERENCES orders(id),

    -- 管理簿番号・日付
    record_number VARCHAR(50) NOT NULL,
    transport_date DATE NOT NULL,

    -- 荷主情報
    shipper_name VARCHAR(200) NOT NULL,
    shipper_address TEXT,

    -- 運送委託チェーン（多重下請構造）
    transport_chain JSONB NOT NULL,              -- [{tier: 1, company: "A社", permit: "xxx"}, ...]

    -- 実運送事業者情報（実際に運送を行う事業者）
    actual_carrier_name VARCHAR(200) NOT NULL,
    actual_carrier_permit_number VARCHAR(50),
    actual_carrier_address TEXT,
    actual_carrier_tier INTEGER NOT NULL,        -- 何次下請か

    -- 運送内容
    cargo_description TEXT,
    pickup_location TEXT NOT NULL,
    delivery_location TEXT NOT NULL,
    pickup_datetime TIMESTAMP,
    delivery_datetime TIMESTAMP,

    -- 使用車両・運転者
    vehicle_number VARCHAR(20),
    vehicle_type VARCHAR(50),
    driver_name VARCHAR(100),

    -- 運賃情報
    shipper_fare DECIMAL(12,2),                  -- 荷主からの運賃
    actual_carrier_fare DECIMAL(12,2),           -- 実運送者への支払
    intermediate_margins JSONB,                  -- 中間マージン [{tier: 1, margin: 10000}, ...]

    -- 確認・承認
    confirmed_by INTEGER REFERENCES users(id),
    confirmed_at TIMESTAMP,

    -- ステータス
    status VARCHAR(20) DEFAULT 'draft',          -- draft/confirmed/submitted
    submitted_to_authority BOOLEAN DEFAULT FALSE,
    submission_date DATE,

    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 実運送体制管理簿の監査証跡
CREATE TABLE IF NOT EXISTS transport_record_audit_log (
    id SERIAL PRIMARY KEY,
    record_id INTEGER REFERENCES actual_transport_records(id),
    action VARCHAR(50) NOT NULL,                 -- created/updated/confirmed/submitted
    performed_by INTEGER REFERENCES users(id),
    details JSONB,
    performed_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 7.3 AI連携機能
-- ============================================

-- AI分析リクエスト履歴
CREATE TABLE IF NOT EXISTS ai_analysis_requests (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id),
    user_id INTEGER REFERENCES users(id),

    -- リクエスト内容
    request_type VARCHAR(50) NOT NULL,           -- query/analysis/suggestion/report
    request_text TEXT NOT NULL,                  -- ユーザーの質問・リクエスト
    context_data JSONB,                          -- 分析に使用したコンテキストデータ

    -- AIレスポンス
    response_text TEXT,
    response_data JSONB,                         -- 構造化されたレスポンス

    -- メタデータ
    model_used VARCHAR(50),                      -- gpt-4, gpt-3.5-turbo, etc.
    tokens_used INTEGER,
    processing_time_ms INTEGER,

    -- フィードバック
    user_rating INTEGER,                         -- 1-5
    user_feedback TEXT,

    status VARCHAR(20) DEFAULT 'completed',      -- pending/processing/completed/failed
    error_message TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- AI生成レポート
CREATE TABLE IF NOT EXISTS ai_generated_reports (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id),

    report_type VARCHAR(50) NOT NULL,            -- daily_summary/weekly_analysis/cost_optimization等
    report_title VARCHAR(200),
    report_period_start DATE,
    report_period_end DATE,

    -- レポート内容
    summary TEXT,                                -- 要約
    key_findings JSONB,                          -- 主要な発見事項
    recommendations JSONB,                       -- 推奨アクション
    full_content TEXT,                           -- 全文

    -- 関連データ
    source_data JSONB,                           -- 分析元データの参照

    generated_at TIMESTAMP DEFAULT NOW(),
    viewed_at TIMESTAMP,
    actioned_at TIMESTAMP
);

-- AIアシスタント会話履歴
CREATE TABLE IF NOT EXISTS ai_chat_history (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id),
    user_id INTEGER REFERENCES users(id),
    session_id UUID NOT NULL,

    role VARCHAR(20) NOT NULL,                   -- user/assistant/system
    content TEXT NOT NULL,

    -- 関連機能
    related_feature VARCHAR(50),                 -- dispatch/billing/compliance等
    related_entity_type VARCHAR(50),             -- order/driver/vehicle等
    related_entity_id INTEGER,

    -- アクション実行
    suggested_action JSONB,                      -- AIが提案したアクション
    action_executed BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMP DEFAULT NOW()
);

-- AIモデル設定
CREATE TABLE IF NOT EXISTS ai_settings (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id),

    -- API設定
    openai_api_key_encrypted TEXT,               -- 暗号化されたAPIキー
    preferred_model VARCHAR(50) DEFAULT 'gpt-4',

    -- 機能設定
    enable_auto_suggestions BOOLEAN DEFAULT TRUE,
    enable_daily_reports BOOLEAN DEFAULT FALSE,
    enable_cost_optimization BOOLEAN DEFAULT TRUE,
    enable_compliance_alerts BOOLEAN DEFAULT TRUE,

    -- 制限設定
    monthly_token_limit INTEGER DEFAULT 100000,
    tokens_used_this_month INTEGER DEFAULT 0,

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- インデックス
-- ============================================

CREATE INDEX idx_transaction_terms_company ON transaction_terms(company_id);
CREATE INDEX idx_transaction_terms_shipper ON transaction_terms(shipper_id);
CREATE INDEX idx_transaction_terms_status ON transaction_terms(status);

CREATE INDEX idx_unfair_practice_company ON unfair_practice_records(company_id);
CREATE INDEX idx_unfair_practice_shipper ON unfair_practice_records(shipper_id);

CREATE INDEX idx_subcontract_company ON subcontract_agreements(company_id);
CREATE INDEX idx_actual_transport_company ON actual_transport_records(company_id);
CREATE INDEX idx_actual_transport_date ON actual_transport_records(transport_date);
CREATE INDEX idx_actual_transport_order ON actual_transport_records(order_id);

CREATE INDEX idx_ai_requests_company ON ai_analysis_requests(company_id);
CREATE INDEX idx_ai_requests_user ON ai_analysis_requests(user_id);
CREATE INDEX idx_ai_chat_session ON ai_chat_history(session_id);
CREATE INDEX idx_ai_chat_user ON ai_chat_history(user_id);

-- ============================================
-- 初期データ（取適法の不当行為タイプ）
-- ============================================

COMMENT ON TABLE transaction_terms IS '取適法対応：取引条件書（書面交付義務）';
COMMENT ON TABLE unfair_practice_records IS '取適法対応：不当な取引行為の記録';
COMMENT ON TABLE actual_transport_records IS '実運送体制管理簿（2024年法改正対応）';
COMMENT ON TABLE ai_analysis_requests IS 'AI分析リクエスト履歴';
COMMENT ON TABLE ai_chat_history IS 'AIアシスタント会話履歴';
