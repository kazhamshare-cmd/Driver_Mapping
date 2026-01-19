# LogiTrace - 運送業務DXプラットフォーム

運送業（トラック・タクシー・バス）向けの法定帳票管理・動態管理・労務管理を一元化するクラウドシステム

## 概要

LogiTraceは、運送会社の業務効率化を実現する次世代クラウドプラットフォームです。

- **リアルタイム動態管理**: GPS技術による全ドライバーの位置追跡
- **法定帳票のデジタル化**: 点呼記録簿、運転日報、運転者台帳など
- **労務管理**: 勤怠管理、健康診断管理、適性診断管理

## 対応業種

- トラック運送（一般貨物・特積み）
- タクシー（法人・個人）
- バス（貸切・路線）

## 主な機能

### 法定帳票管理
| 機能 | 説明 |
|------|------|
| 点呼記録簿 | 乗務前・乗務後点呼のデジタル化、アルコールチェック記録、IT点呼対応 |
| 日常点検記録 | 車両の日常点検チェックリスト、不良箇所の即時通知 |
| 運転日報 | GPS連動の走行記録自動作成、手書き不要 |
| 運転者台帳 | 法定様式準拠、免許期限・健診期限の自動アラート |
| 健康診断管理 | 定期健診・特殊健診の受診履歴と次回予定管理 |
| 適性診断管理 | 初任・適齢・特定診断の記録、65歳以上の自動適齢判定 |

### 動態管理
- リアルタイム位置追跡（GPS）
- 配車状況の可視化
- 運行実績レポート（日次・月次）

### その他機能
- スマートフォン対応（iOS/Android）
- PDFエクスポート
- デジタル署名
- タコグラフ連携
- API連携

## 技術スタック

### フロントエンド
- React 18 + TypeScript
- Vite
- React Router
- MUI (Material-UI)
- Lucide React Icons
- Stripe Elements（決済）

### バックエンド
- Node.js + Express
- TypeScript
- PostgreSQL
- Stripe API（サブスクリプション管理）
- PM2（プロセス管理）

### インフラ
- AWS Lightsail
- Nginx（リバースプロキシ）
- Let's Encrypt（SSL証明書）

## 料金プラン

| プラン | 月額 | ドライバー数 | 特徴 |
|--------|------|-------------|------|
| スターター | ¥5,800 | 1〜10名 | 小規模事業者向け |
| プロフェッショナル | ¥9,800 | 1〜50名 | 中規模事業者向け（推奨） |
| エンタープライズ | お問い合わせ | 51名以上 | 大規模事業者向けカスタマイズ |

### トライアル
- **14日間の無料トライアル**付き
- 15日目から自動課金開始
- いつでもキャンセル可能

## プロジェクト構成

```
LogiTrace/
├── backend/                    # バックエンドAPI
│   ├── src/
│   │   ├── config/            # 設定ファイル
│   │   │   └── pricing-plans.ts
│   │   ├── controllers/       # APIコントローラー
│   │   │   ├── authController.ts
│   │   │   ├── subscriptionController.ts
│   │   │   ├── driverController.ts
│   │   │   ├── workRecordController.ts
│   │   │   └── ...
│   │   ├── routes/            # APIルート
│   │   ├── services/          # ビジネスロジック
│   │   │   ├── stripeService.ts
│   │   │   ├── pdfGenerator.ts
│   │   │   └── ...
│   │   ├── middleware/        # ミドルウェア
│   │   └── utils/             # ユーティリティ
│   └── package.json
│
├── web-dashboard/              # フロントエンド
│   ├── src/
│   │   ├── pages/             # ページコンポーネント
│   │   │   ├── Home.tsx       # ランディングページ
│   │   │   ├── Register.tsx   # 登録ページ
│   │   │   ├── Login.tsx
│   │   │   ├── Dashboard.tsx
│   │   │   └── ...
│   │   ├── components/        # 共通コンポーネント
│   │   ├── config/            # フロントエンド設定
│   │   │   └── pricing-plans.ts
│   │   └── App.tsx
│   ├── public/
│   │   └── images/            # 静的画像
│   └── package.json
│
└── database/
    └── migrations/            # DBマイグレーション
```

## API エンドポイント

### 認証
- `POST /auth/register` - ユーザー登録
- `POST /auth/login` - ログイン

### サブスクリプション
- `POST /billing/create-setup-intent` - Stripe SetupIntent作成（認証不要）
- `POST /billing/create-subscription` - サブスクリプション作成

### ドライバー管理
- `GET /api/drivers` - ドライバー一覧
- `POST /api/drivers` - ドライバー登録
- `PUT /api/drivers/:id` - ドライバー更新

### 運行記録
- `GET /api/work-records` - 運行記録一覧
- `POST /api/work-records` - 運行記録作成
- `GET /api/work-records/:id/pdf` - PDF出力

## 開発環境セットアップ

### 必要要件
- Node.js 18以上
- PostgreSQL 14以上
- npm または yarn

### フロントエンド
```bash
cd web-dashboard
npm install
npm run dev
```

### バックエンド
```bash
cd backend
npm install
npm run dev
```

### 環境変数（.env）
```
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/logitrace

# Stripe
STRIPE_SECRET_KEY=sk_test_xxx
STRIPE_PUBLISHABLE_KEY=pk_test_xxx

# JWT
JWT_SECRET=your-secret-key
```

## デプロイ

### ビルド
```bash
cd web-dashboard
npm run build
```

### サーバーへデプロイ
```bash
# フロントエンド
rsync -avz dist/ ubuntu@server:/var/www/logitrace/frontend/

# バックエンド
rsync -avz --exclude node_modules backend/ ubuntu@server:/var/www/logitrace/backend/
ssh ubuntu@server "cd /var/www/logitrace/backend && npm install && pm2 restart logitrace-api"
```

## Stripe設定

### 価格ID（本番環境で設定が必要）
- `price_PLACEHOLDER_STARTER` - スタータープラン
- `price_PLACEHOLDER_PROFESSIONAL` - プロフェッショナルプラン
- `price_PLACEHOLDER_ENTERPRISE` - エンタープライズプラン

### トライアル設定
- `trial_period_days: 14` - 14日間の無料トライアル

## ライセンス

Copyright 2026 B19 Inc. All rights reserved.

## お問い合わせ

- メール: info@b19.co.jp
- Web: https://b19.co.jp
