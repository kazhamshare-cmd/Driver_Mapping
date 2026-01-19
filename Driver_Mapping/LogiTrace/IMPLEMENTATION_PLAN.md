# LogiTrace 機能拡張実装計画

## 概要
AEGISAPP運送業の機能を分析し、LogiTraceに不足している機能を段階的に実装する計画。

**作成日**: 2026-01-18
**競合分析対象**: https://unsogyo.aegisapp.net/

---

## 現状比較サマリー

| 項目 | AEGISAPP | LogiTrace |
|------|----------|-----------|
| 年額料金 | 60万円〜 | 7〜12万円 |
| 初期費用 | 98万円〜 | 0円 |
| 対象規模 | 10〜1000台 | 1〜30台（拡張可能）|

---

## Phase 1: 改善基準告示対応強化（優先度：高）

### 1.1 拘束時間リアルタイム監視 ✅ 完了 (2026-01-18)
- [x] work_recordsに拘束時間計算ロジック追加
- [x] 1日の拘束時間上限（13時間、週2回まで16時間）チェック
- [x] 1ヶ月の拘束時間上限（284時間、労使協定で310時間）チェック
- [x] 運転時間の2日平均・2週平均チェック
- [x] ダッシュボードに警告表示

### 1.2 休息期間チェック ✅ 完了 (2026-01-18)
- [x] 継続8時間以上の休息確認
- [x] 休息期間不足時のアラート
- [x] 分割休息の管理（4時間+4時間）

### 1.3 運転時間管理 ✅ 完了 (2026-01-18)
- [x] 連続運転時間（4時間以内）チェック
- [x] 30分以上の休憩確認
- [x] 1日の運転時間上限（9時間、週2回まで10時間）

**実装ファイル**:
- `database/migrations/006_labor_compliance.sql`（新規）
- `backend/src/services/laborComplianceService.ts`（新規）
- `backend/src/controllers/laborComplianceController.ts`（新規）
- `backend/src/routes/laborComplianceRoutes.ts`（新規）
- `web-dashboard/src/pages/compliance/LaborTimeMonitor.tsx`（新規）

---

## Phase 2: 配車・運行計画機能（優先度：高） ✅ 完了 (2026-01-18)

### 2.1 ビジュアル配車ボード ✅ 完了
- [x] ドラッグ&ドロップ対応のカレンダービュー
- [x] 車両×日付のガントチャート
- [x] ドライバー×日付のガントチャート
- [x] 拘束時間超過の視覚的警告

### 2.2 受注管理 ✅ 完了
- [x] 受注データ登録画面
- [x] 荷主マスタ管理
- [x] 発着地マスタ管理
- [x] 受注一覧・検索

### 2.3 自動割当機能 ✅ 完了
- [x] 空き車両・ドライバーの自動提案
- [x] 拘束時間を考慮した割当
- [x] 資格・車両タイプのマッチング

**実装ファイル**:
- `database/migrations/007_dispatch_management.sql`（新規）
- `backend/src/controllers/shipperController.ts`（新規）
- `backend/src/controllers/locationController.ts`（新規）
- `backend/src/controllers/orderController.ts`（新規）
- `backend/src/controllers/dispatchController.ts`（新規）
- `backend/src/services/autoAssignService.ts`（新規）
- `backend/src/routes/shipperRoutes.ts`（新規）
- `backend/src/routes/locationRoutes.ts`（新規）
- `backend/src/routes/orderRoutes.ts`（新規）
- `backend/src/routes/dispatchRoutes.ts`（新規）
- `web-dashboard/src/pages/dispatch/DispatchBoard.tsx`（新規）
- `web-dashboard/src/pages/dispatch/OrderManagement.tsx`（新規）

---

## Phase 3: 運賃・請求管理（優先度：中） ✅ 完了 (2026-01-18)

### 3.1 運賃計算エンジン ✅ 完了
- [x] 距離制運賃計算
- [x] 時間制運賃計算
- [x] 附帯作業費計算
- [x] 高速代マスタ管理
- [x] 割増料金（深夜・早朝・休日）

### 3.2 請求書発行 ✅ 完了
- [x] 請求書PDF生成
- [x] 下払通知書生成
- [x] インボイス制度対応（適格請求書）
- [x] 消費税計算
- [x] 請求書番号自動採番

### 3.3 売掛・買掛管理 ✅ 完了
- [x] 荷主別売掛残高ビュー
- [x] 月別売上サマリー
- [x] 入金登録・消込
- [x] AI消込候補提案

**実装ファイル**:
- `database/migrations/008_billing_management.sql`（新規）
- `backend/src/services/fareCalculationService.ts`（新規）
- `backend/src/controllers/invoiceController.ts`（新規）
- `backend/src/controllers/paymentController.ts`（新規）
- `backend/src/services/invoicePdfGenerator.ts`（新規）
- `backend/src/routes/invoiceRoutes.ts`（新規）
- `backend/src/routes/paymentRoutes.ts`（新規）
- `web-dashboard/src/pages/billing/InvoiceList.tsx`（新規）
- `web-dashboard/src/pages/billing/FareSettings.tsx`（新規）
- `web-dashboard/src/pages/billing/PaymentManagement.tsx`（新規）

---

## Phase 4: 経営分析・原価計算（優先度：中） ✅ 完了 (2026-01-18)

### 4.1 原価計算 ✅ 完了
- [x] 車両別原価計算（国交省指針準拠）
- [x] ドライバー別原価計算
- [x] 案件別原価計算
- [x] 燃料費・高速代・人件費の按分

### 4.2 損益分析 ✅ 完了
- [x] 車両別損益
- [x] ドライバー別損益
- [x] 荷主別損益
- [x] 損益分岐点分析

### 4.3 経営ダッシュボード ✅ 完了
- [x] 稼働率グラフ
- [x] 利益率推移
- [x] 売上・原価・利益の可視化
- [x] KPI可視化

**実装ファイル**:
- `database/migrations/009_cost_analysis.sql`（新規）
- `backend/src/services/costCalculationService.ts`（新規）
- `backend/src/controllers/analyticsController.ts`（新規）
- `backend/src/routes/analyticsRoutes.ts`（新規）
- `web-dashboard/src/pages/analytics/CostManagement.tsx`（新規）
- `web-dashboard/src/pages/analytics/ProfitAnalysis.tsx`（新規）
- `web-dashboard/src/pages/analytics/AnalyticsDashboard.tsx`（新規）

---

## Phase 5: デジタコ連携強化（優先度：中） ✅ 完了 (2026-01-18)

### 5.1 富士通ITP-WebService V3連携 ✅ 完了
- [x] API双方向連携
- [x] 運行指示データ送信
- [x] 実績データ自動取込
- [x] マスタ同期

### 5.2 パイオニア VehicleAssist連携 ✅ 完了
- [x] VehicleAssist API連携
- [x] 運行データ自動取得
- [x] カーナビ連携（運行指示送信）
- [x] リアルタイム位置情報

### 5.3 その他デジタコ ✅ 完了
- [x] 矢崎連携強化
- [x] デンソー連携強化
- [x] 汎用API設計
- [x] 統合マッピング管理（ドライバー・車両）
- [x] 同期ログ管理

**実装ファイル**:
- `database/migrations/010_tachograph_integration.sql`（新規）
- `backend/src/services/itpWebServiceConnector.ts`（新規）
- `backend/src/services/vehicleAssistConnector.ts`（新規）
- `backend/src/controllers/tachographIntegrationController.ts`（新規）
- `backend/src/routes/tachographIntegrationRoutes.ts`（新規）
- `web-dashboard/src/pages/settings/TachographIntegration.tsx`（新規）

---

## Phase 6: 特殊車両・業態対応（優先度：低） ✅ 完了 (2026-01-19)

### 6.1 トレーラー管理 ✅ 完了
- [x] トラクタヘッド管理
- [x] シャーシ管理
- [x] 連結・連結解除記録
- [x] シャーシ予定チャート（ガントチャート）

### 6.2 海上輸送連携 ✅ 完了
- [x] RORO船・フェリースケジュール管理
- [x] 港湾作業管理
- [x] フェリー予約管理
- [x] 港湾マスタ（日本主要港）

### 6.3 通運事業対応 ✅ 完了
- [x] JR貨物連携（貨物駅マスタ・鉄道ルート）
- [x] コンテナ管理（12ft/20ft/31ft/40ft対応）
- [x] 鉄道輸送予約管理
- [x] コンテナ追跡（リアルタイム位置管理）

**実装ファイル**:
- `database/migrations/011_special_vehicles.sql`（新規）
- `backend/src/controllers/trailerController.ts`（新規）
- `backend/src/controllers/maritimeController.ts`（新規）
- `backend/src/controllers/railFreightController.ts`（新規）
- `backend/src/routes/trailerRoutes.ts`（新規）
- `backend/src/routes/maritimeRoutes.ts`（新規）
- `backend/src/routes/railFreightRoutes.ts`（新規）
- `web-dashboard/src/pages/special-vehicles/SpecialVehiclesDashboard.tsx`（新規）
- `web-dashboard/src/pages/special-vehicles/TrailerManagement.tsx`（新規）

---

## Phase 7: 取適法・実運送体制管理・AI連携（優先度：中） ✅ 完了 (2026-01-19)

### 7.1 取適法対応（トラック運送業における下請取引適正化法） ✅ 完了
- [x] 取引条件書管理（書面交付義務）
- [x] 取引条件の明示（料金・支払条件・燃料サーチャージ）
- [x] 不当取引行為の記録・管理
- [x] コンプライアンスダッシュボード
- [x] 取引条件書PDF生成

### 7.2 実運送体制管理簿（2024年法改正対応） ✅ 完了
- [x] 運送委託チェーン管理（多重下請構造の可視化）
- [x] 実運送事業者情報の記録
- [x] 下請契約管理
- [x] 実運送体制管理簿の作成・確認・提出
- [x] 監査証跡（audit log）管理
- [x] 受注からの自動生成機能

### 7.3 AI連携機能（ChatGPT/OpenAI連携） ✅ 完了
- [x] AIチャットアシスタント（運送業務Q&A）
- [x] 配車最適化提案
- [x] コスト分析・削減提案
- [x] コンプライアンスアラート
- [x] 日次サマリーレポート自動生成
- [x] AI設定管理（モデル選択・トークン管理）

**実装ファイル**:
- `database/migrations/012_compliance_ai_features.sql`（新規）
- `backend/src/controllers/fairTransactionController.ts`（新規）
- `backend/src/controllers/actualTransportController.ts`（新規）
- `backend/src/controllers/aiAssistantController.ts`（新規）
- `backend/src/routes/fairTransactionRoutes.ts`（新規）
- `backend/src/routes/actualTransportRoutes.ts`（新規）
- `backend/src/routes/aiAssistantRoutes.ts`（新規）
- `web-dashboard/src/pages/compliance/FairTransaction.tsx`（新規）
- `web-dashboard/src/pages/compliance/ActualTransport.tsx`（新規）
- `web-dashboard/src/pages/ai/AiAssistant.tsx`（新規）

---

## DBスキーマ追加予定

```sql
-- Phase 1: 労務管理
ALTER TABLE work_records ADD COLUMN binding_time_minutes INTEGER;
ALTER TABLE work_records ADD COLUMN driving_time_minutes INTEGER;
ALTER TABLE work_records ADD COLUMN rest_time_minutes INTEGER;

CREATE TABLE labor_alerts (
  id SERIAL PRIMARY KEY,
  driver_id INTEGER REFERENCES users(id),
  alert_type VARCHAR(50), -- 'binding_time', 'driving_time', 'rest_period'
  alert_date DATE,
  threshold_value INTEGER,
  actual_value INTEGER,
  acknowledged BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Phase 2: 受注・配車
CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id),
  order_number VARCHAR(50),
  shipper_id INTEGER REFERENCES shippers(id),
  pickup_location TEXT,
  delivery_location TEXT,
  pickup_datetime TIMESTAMP,
  delivery_datetime TIMESTAMP,
  cargo_type VARCHAR(100),
  cargo_weight DECIMAL(10,2),
  status VARCHAR(20) DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE shippers (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id),
  name VARCHAR(200),
  address TEXT,
  contact_person VARCHAR(100),
  phone VARCHAR(20),
  email VARCHAR(100),
  invoice_registration_number VARCHAR(20), -- インボイス登録番号
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE dispatch_assignments (
  id SERIAL PRIMARY KEY,
  order_id INTEGER REFERENCES orders(id),
  vehicle_id INTEGER REFERENCES vehicles(id),
  driver_id INTEGER REFERENCES users(id),
  scheduled_start TIMESTAMP,
  scheduled_end TIMESTAMP,
  status VARCHAR(20) DEFAULT 'assigned',
  created_at TIMESTAMP DEFAULT NOW()
);

-- Phase 3: 運賃・請求
CREATE TABLE fare_masters (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id),
  shipper_id INTEGER REFERENCES shippers(id),
  fare_type VARCHAR(20), -- 'distance', 'time', 'fixed'
  base_rate DECIMAL(10,2),
  rate_per_km DECIMAL(10,2),
  rate_per_hour DECIMAL(10,2),
  night_surcharge_rate DECIMAL(5,2),
  holiday_surcharge_rate DECIMAL(5,2),
  effective_from DATE,
  effective_to DATE
);

CREATE TABLE invoices (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id),
  shipper_id INTEGER REFERENCES shippers(id),
  invoice_number VARCHAR(50),
  invoice_date DATE,
  due_date DATE,
  subtotal DECIMAL(12,2),
  tax_amount DECIMAL(12,2),
  total_amount DECIMAL(12,2),
  status VARCHAR(20) DEFAULT 'draft',
  pdf_url TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE invoice_items (
  id SERIAL PRIMARY KEY,
  invoice_id INTEGER REFERENCES invoices(id),
  order_id INTEGER REFERENCES orders(id),
  description TEXT,
  quantity DECIMAL(10,2),
  unit_price DECIMAL(10,2),
  amount DECIMAL(12,2),
  tax_rate DECIMAL(5,2)
);

-- Phase 4: 経営分析
CREATE TABLE vehicle_costs (
  id SERIAL PRIMARY KEY,
  vehicle_id INTEGER REFERENCES vehicles(id),
  cost_month DATE,
  fuel_cost DECIMAL(10,2),
  toll_cost DECIMAL(10,2),
  maintenance_cost DECIMAL(10,2),
  insurance_cost DECIMAL(10,2),
  depreciation DECIMAL(10,2),
  other_cost DECIMAL(10,2),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE driver_costs (
  id SERIAL PRIMARY KEY,
  driver_id INTEGER REFERENCES users(id),
  cost_month DATE,
  salary DECIMAL(10,2),
  allowances DECIMAL(10,2),
  social_insurance DECIMAL(10,2),
  other_cost DECIMAL(10,2),
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

## 実装済み機能（2026-01-18時点）

- [x] GPS追跡・動態管理
- [x] 点呼記録（乗務前・乗務後）
- [x] 日常点検記録
- [x] 運転日報（GPS連動自動作成）
- [x] 運転者台帳
- [x] 健康診断管理
- [x] 適性診断管理
- [x] 教育記録（12項目対応）
- [x] 事故記録
- [x] 運行指示書（バス対応）
- [x] デジタコデータ取込（矢崎・富士通・デンソー）
- [x] GPS休憩自動検出（15分閾値）
- [x] 電子署名による承認
- [x] 帳票一括出力（国土交通省対応）
- [x] 多業種対応（トラック・タクシー・バス）

---

## 次のアクション

**すべての主要フェーズ（Phase 1〜7）実装完了！**

今後の拡張候補：
1. モバイルアプリ（iOS/Android）の機能強化
2. 電子帳簿保存法対応（電子取引データ保存）
3. ERPシステム連携（会計システム・給与システム）
4. 多言語対応（英語・中国語・ベトナム語）
5. AI機能の実運用化（OpenAI API本格連携）

---

## 更新履歴

| 日付 | 内容 |
|------|------|
| 2026-01-19 | Phase 7 取適法・実運送体制・AI連携 完了 |
| 2026-01-19 | Phase 6 特殊車両・業態対応 完了 |
| 2026-01-18 | Phase 5 デジタコ連携強化 完了 |
| 2026-01-18 | Phase 4 経営分析・原価計算機能 完了 |
| 2026-01-18 | Phase 3 運賃・請求管理機能 完了 |
| 2026-01-18 | Phase 2 配車・運行計画機能 完了 |
| 2026-01-18 | Phase 1 改善基準告示対応強化 完了 |
| 2026-01-18 | 初版作成、競合分析完了 |
