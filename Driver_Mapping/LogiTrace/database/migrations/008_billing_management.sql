-- =====================================================
-- Phase 3: 運賃・請求管理 (Billing Management)
-- =====================================================

-- 運賃マスタ（荷主別料金設定）
CREATE TABLE IF NOT EXISTS fare_masters (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    shipper_id INTEGER REFERENCES shippers(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    fare_type VARCHAR(20) NOT NULL CHECK (fare_type IN ('distance', 'time', 'fixed', 'mixed')),

    -- 距離制運賃
    base_distance_km DECIMAL(10,2) DEFAULT 0,
    base_rate DECIMAL(10,2) DEFAULT 0,
    rate_per_km DECIMAL(10,2) DEFAULT 0,

    -- 時間制運賃
    base_time_hours DECIMAL(10,2) DEFAULT 0,
    rate_per_hour DECIMAL(10,2) DEFAULT 0,

    -- 固定運賃（ルート別など）
    fixed_rate DECIMAL(10,2) DEFAULT 0,

    -- 割増料金率（%）
    night_surcharge_rate DECIMAL(5,2) DEFAULT 25.00,  -- 22:00-05:00
    early_morning_surcharge_rate DECIMAL(5,2) DEFAULT 25.00,  -- 05:00-07:00
    holiday_surcharge_rate DECIMAL(5,2) DEFAULT 35.00,

    -- 附帯作業費
    loading_fee DECIMAL(10,2) DEFAULT 0,
    unloading_fee DECIMAL(10,2) DEFAULT 0,
    waiting_fee_per_hour DECIMAL(10,2) DEFAULT 0,

    -- 車両タイプ別係数
    vehicle_type_coefficients JSONB DEFAULT '{}',

    -- 有効期間
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE,

    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 高速代マスタ
CREATE TABLE IF NOT EXISTS toll_masters (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    route_name VARCHAR(200) NOT NULL,
    from_location VARCHAR(200),
    to_location VARCHAR(200),

    -- 車両タイプ別料金
    normal_fee DECIMAL(10,2) DEFAULT 0,  -- 普通車
    medium_fee DECIMAL(10,2) DEFAULT 0,  -- 中型車
    large_fee DECIMAL(10,2) DEFAULT 0,   -- 大型車
    extra_large_fee DECIMAL(10,2) DEFAULT 0,  -- 特大車

    -- ETC割引
    etc_discount_rate DECIMAL(5,2) DEFAULT 0,

    notes TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 請求書
CREATE TABLE IF NOT EXISTS invoices (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    shipper_id INTEGER REFERENCES shippers(id) ON DELETE SET NULL,

    invoice_number VARCHAR(50) NOT NULL UNIQUE,
    invoice_date DATE NOT NULL,
    due_date DATE NOT NULL,

    -- 期間
    billing_period_start DATE,
    billing_period_end DATE,

    -- 金額
    subtotal DECIMAL(12,2) NOT NULL DEFAULT 0,
    tax_rate DECIMAL(5,2) NOT NULL DEFAULT 10.00,
    tax_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_amount DECIMAL(12,2) NOT NULL DEFAULT 0,

    -- インボイス制度対応
    is_qualified_invoice BOOLEAN DEFAULT TRUE,  -- 適格請求書
    registration_number VARCHAR(20),  -- 登録番号（T+13桁）

    -- ステータス
    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'issued', 'sent', 'paid', 'partial', 'overdue', 'cancelled')),

    -- 支払状況
    paid_amount DECIMAL(12,2) DEFAULT 0,

    -- PDF
    pdf_url TEXT,
    pdf_generated_at TIMESTAMP,

    -- メモ
    notes TEXT,
    internal_notes TEXT,

    -- 送付情報
    sent_at TIMESTAMP,
    sent_method VARCHAR(20),  -- 'email', 'mail', 'fax'

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by INTEGER REFERENCES users(id)
);

-- 請求明細
CREATE TABLE IF NOT EXISTS invoice_items (
    id SERIAL PRIMARY KEY,
    invoice_id INTEGER REFERENCES invoices(id) ON DELETE CASCADE,
    order_id INTEGER REFERENCES orders(id) ON DELETE SET NULL,
    dispatch_id INTEGER REFERENCES dispatch_assignments(id) ON DELETE SET NULL,

    item_type VARCHAR(30) NOT NULL CHECK (item_type IN (
        'transport',      -- 運賃
        'loading',        -- 積込作業
        'unloading',      -- 荷卸作業
        'waiting',        -- 待機料
        'toll',           -- 高速代
        'surcharge',      -- 割増料金
        'other',          -- その他
        'discount'        -- 値引き
    )),

    description TEXT NOT NULL,

    -- 数量・単価
    quantity DECIMAL(10,2) NOT NULL DEFAULT 1,
    unit VARCHAR(20) DEFAULT '式',  -- '式', 'km', '時間', '個' など
    unit_price DECIMAL(10,2) NOT NULL,

    -- 金額
    amount DECIMAL(12,2) NOT NULL,
    tax_rate DECIMAL(5,2) DEFAULT 10.00,
    tax_amount DECIMAL(12,2) DEFAULT 0,

    -- 運行情報（参考）
    work_date DATE,
    route_info TEXT,
    vehicle_number VARCHAR(20),
    driver_name VARCHAR(100),

    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 入金記録
CREATE TABLE IF NOT EXISTS payments (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    invoice_id INTEGER REFERENCES invoices(id) ON DELETE SET NULL,
    shipper_id INTEGER REFERENCES shippers(id) ON DELETE SET NULL,

    payment_date DATE NOT NULL,
    amount DECIMAL(12,2) NOT NULL,

    payment_method VARCHAR(30) CHECK (payment_method IN (
        'bank_transfer',  -- 銀行振込
        'cash',           -- 現金
        'check',          -- 小切手
        'credit_card',    -- クレジットカード
        'offset',         -- 相殺
        'other'
    )),

    -- 振込情報
    bank_name VARCHAR(100),
    branch_name VARCHAR(100),
    transfer_name VARCHAR(200),  -- 振込人名義

    notes TEXT,

    -- 消込
    is_matched BOOLEAN DEFAULT FALSE,
    matched_at TIMESTAMP,
    matched_by INTEGER REFERENCES users(id),

    created_at TIMESTAMP DEFAULT NOW(),
    created_by INTEGER REFERENCES users(id)
);

-- 下払通知書（協力会社への支払）
CREATE TABLE IF NOT EXISTS subcontract_payments (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,

    -- 協力会社情報
    subcontractor_name VARCHAR(200) NOT NULL,
    subcontractor_address TEXT,
    subcontractor_registration_number VARCHAR(20),  -- インボイス登録番号

    payment_number VARCHAR(50) NOT NULL UNIQUE,
    payment_date DATE NOT NULL,

    -- 期間
    billing_period_start DATE,
    billing_period_end DATE,

    -- 金額
    subtotal DECIMAL(12,2) NOT NULL DEFAULT 0,
    tax_rate DECIMAL(5,2) NOT NULL DEFAULT 10.00,
    tax_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_amount DECIMAL(12,2) NOT NULL DEFAULT 0,

    -- ステータス
    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'confirmed', 'paid', 'cancelled')),

    -- PDF
    pdf_url TEXT,

    notes TEXT,

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by INTEGER REFERENCES users(id)
);

-- 下払明細
CREATE TABLE IF NOT EXISTS subcontract_payment_items (
    id SERIAL PRIMARY KEY,
    subcontract_payment_id INTEGER REFERENCES subcontract_payments(id) ON DELETE CASCADE,
    order_id INTEGER REFERENCES orders(id) ON DELETE SET NULL,

    description TEXT NOT NULL,
    work_date DATE,
    route_info TEXT,

    quantity DECIMAL(10,2) NOT NULL DEFAULT 1,
    unit VARCHAR(20) DEFAULT '式',
    unit_price DECIMAL(10,2) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,

    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 売掛金残高ビュー
CREATE OR REPLACE VIEW accounts_receivable AS
SELECT
    i.company_id,
    i.shipper_id,
    s.name AS shipper_name,
    COUNT(i.id) AS invoice_count,
    SUM(CASE WHEN i.status NOT IN ('cancelled', 'paid') THEN i.total_amount ELSE 0 END) AS total_billed,
    SUM(i.paid_amount) AS total_paid,
    SUM(CASE WHEN i.status NOT IN ('cancelled', 'paid') THEN i.total_amount - i.paid_amount ELSE 0 END) AS outstanding_balance,
    SUM(CASE WHEN i.status = 'overdue' THEN i.total_amount - i.paid_amount ELSE 0 END) AS overdue_balance,
    MIN(CASE WHEN i.status NOT IN ('cancelled', 'paid') THEN i.due_date END) AS earliest_due_date
FROM invoices i
LEFT JOIN shippers s ON i.shipper_id = s.id
GROUP BY i.company_id, i.shipper_id, s.name;

-- 月別売上サマリービュー
CREATE OR REPLACE VIEW monthly_revenue_summary AS
SELECT
    i.company_id,
    DATE_TRUNC('month', i.invoice_date) AS month,
    COUNT(i.id) AS invoice_count,
    SUM(i.subtotal) AS total_subtotal,
    SUM(i.tax_amount) AS total_tax,
    SUM(i.total_amount) AS total_revenue,
    SUM(i.paid_amount) AS total_collected
FROM invoices i
WHERE i.status != 'cancelled'
GROUP BY i.company_id, DATE_TRUNC('month', i.invoice_date);

-- 請求書番号採番テーブル
CREATE TABLE IF NOT EXISTS invoice_number_sequences (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE UNIQUE,
    prefix VARCHAR(10) DEFAULT 'INV',
    current_year INTEGER NOT NULL,
    current_number INTEGER NOT NULL DEFAULT 0,
    format VARCHAR(50) DEFAULT '{prefix}-{year}-{number:05d}'
);

-- インデックス
CREATE INDEX IF NOT EXISTS idx_fare_masters_company ON fare_masters(company_id);
CREATE INDEX IF NOT EXISTS idx_fare_masters_shipper ON fare_masters(shipper_id);
CREATE INDEX IF NOT EXISTS idx_fare_masters_active ON fare_masters(is_active, effective_from, effective_to);

CREATE INDEX IF NOT EXISTS idx_invoices_company ON invoices(company_id);
CREATE INDEX IF NOT EXISTS idx_invoices_shipper ON invoices(shipper_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(status);
CREATE INDEX IF NOT EXISTS idx_invoices_date ON invoices(invoice_date);
CREATE INDEX IF NOT EXISTS idx_invoices_due_date ON invoices(due_date);

CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice ON invoice_items(invoice_id);
CREATE INDEX IF NOT EXISTS idx_invoice_items_order ON invoice_items(order_id);

CREATE INDEX IF NOT EXISTS idx_payments_company ON payments(company_id);
CREATE INDEX IF NOT EXISTS idx_payments_invoice ON payments(invoice_id);
CREATE INDEX IF NOT EXISTS idx_payments_shipper ON payments(shipper_id);
CREATE INDEX IF NOT EXISTS idx_payments_date ON payments(payment_date);

-- 請求書発行時のトリガー（請求書番号自動採番）
CREATE OR REPLACE FUNCTION generate_invoice_number()
RETURNS TRIGGER AS $$
DECLARE
    seq_record invoice_number_sequences%ROWTYPE;
    new_number INTEGER;
    formatted_number VARCHAR(50);
BEGIN
    -- シーケンス取得または作成
    SELECT * INTO seq_record FROM invoice_number_sequences
    WHERE company_id = NEW.company_id;

    IF NOT FOUND THEN
        INSERT INTO invoice_number_sequences (company_id, current_year, current_number)
        VALUES (NEW.company_id, EXTRACT(YEAR FROM CURRENT_DATE), 0)
        RETURNING * INTO seq_record;
    END IF;

    -- 年が変わったらリセット
    IF seq_record.current_year != EXTRACT(YEAR FROM NEW.invoice_date) THEN
        UPDATE invoice_number_sequences
        SET current_year = EXTRACT(YEAR FROM NEW.invoice_date), current_number = 0
        WHERE company_id = NEW.company_id;
        seq_record.current_year := EXTRACT(YEAR FROM NEW.invoice_date);
        seq_record.current_number := 0;
    END IF;

    -- 番号インクリメント
    new_number := seq_record.current_number + 1;
    UPDATE invoice_number_sequences
    SET current_number = new_number
    WHERE company_id = NEW.company_id;

    -- フォーマット適用
    IF NEW.invoice_number IS NULL OR NEW.invoice_number = '' THEN
        formatted_number := seq_record.prefix || '-' ||
                           seq_record.current_year || '-' ||
                           LPAD(new_number::TEXT, 5, '0');
        NEW.invoice_number := formatted_number;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_generate_invoice_number
BEFORE INSERT ON invoices
FOR EACH ROW
EXECUTE FUNCTION generate_invoice_number();

-- 入金時に請求書ステータス更新
CREATE OR REPLACE FUNCTION update_invoice_on_payment()
RETURNS TRIGGER AS $$
DECLARE
    invoice_total DECIMAL(12,2);
    total_paid DECIMAL(12,2);
BEGIN
    IF NEW.invoice_id IS NOT NULL THEN
        -- 請求書の合計金額と支払済金額を取得
        SELECT total_amount INTO invoice_total FROM invoices WHERE id = NEW.invoice_id;
        SELECT COALESCE(SUM(amount), 0) INTO total_paid FROM payments WHERE invoice_id = NEW.invoice_id;

        -- 請求書の支払済金額とステータスを更新
        UPDATE invoices SET
            paid_amount = total_paid,
            status = CASE
                WHEN total_paid >= invoice_total THEN 'paid'
                WHEN total_paid > 0 THEN 'partial'
                ELSE status
            END,
            updated_at = NOW()
        WHERE id = NEW.invoice_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_invoice_on_payment
AFTER INSERT OR UPDATE ON payments
FOR EACH ROW
EXECUTE FUNCTION update_invoice_on_payment();

-- 期限切れ請求書を自動でoverdue更新するための関数
CREATE OR REPLACE FUNCTION update_overdue_invoices()
RETURNS void AS $$
BEGIN
    UPDATE invoices
    SET status = 'overdue', updated_at = NOW()
    WHERE status IN ('issued', 'sent', 'partial')
      AND due_date < CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE fare_masters IS '運賃マスタ - 荷主別の料金設定';
COMMENT ON TABLE invoices IS '請求書 - インボイス制度対応';
COMMENT ON TABLE invoice_items IS '請求明細';
COMMENT ON TABLE payments IS '入金記録';
COMMENT ON TABLE subcontract_payments IS '下払通知書 - 協力会社への支払';
