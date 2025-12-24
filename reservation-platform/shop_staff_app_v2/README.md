# 店舗スタッフアプリ (Shop Staff App)

予約管理プラットフォーム - 店舗スタッフ用モバイルアプリ

## ✅ 実装済み機能

### 1. ログイン機能 🔐
- Firebase Authentication によるメールアドレス・パスワード認証
- パスワードリセット機能
- 自動ログイン維持
- **自動スタッフ登録**: `@staff`を含むメールアドレスでログインすると自動的に`employees`コレクションに登録

### 2. ホーム画面 🏠
- ユーザー情報・店舗情報表示
- 各機能へのナビゲーション

### 3. 注文管理 📋
- **リアルタイム注文一覧**: Firestore onSnapshotで即座に更新
- **ステータス別タブ**: 新規注文/調理中/提供準備完了/提供済み
- **注文詳細表示**: 商品、オプション、金額、注文者情報
- **ステータス更新**: タップで注文のステータスを更新
- **注文者トラッキング**: 誰が何を注文したか表示（スタッフ代理注文も識別）
- **経過時間表示**: 注文からの経過時間を色分け表示

## 🚧 開発中の機能

- レジ・会計
- 代理注文（口頭注文受付）
- 予約管理
- **Wi-Fi IPプリンター設定と自動印刷**

## 🖨️ プリンター仕様

### Wi-Fi/ネットワークプリンター
- **接続方式**: TCP/IP (Wi-Fi経由)
- **プロトコル**: ESC/POS
- **設定項目**:
  - IPアドレス (例: 192.168.1.100)
  - ポート番号 (デフォルト: 9100)
- **対応プリンター**:
  - エプソン TM シリーズ (TM-m30, TM-T88など)
  - スター精密 mC-Print3
  - その他 ESC/POS対応サーマルプリンター

### プリンター種別
- **キッチンプリンター**: 新規注文時に自動印刷
- **レシートプリンター**: 会計完了時に自動印刷

## 📦 セットアップ

### 1. 依存関係のインストール

```bash
cd shop_staff_app
flutter pub get
```

### 2. Firebase設定済み

- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`

すでに設定済みです（FlutterFire CLIで自動生成）

### 3. 実行

```bash
flutter run
```

## 🔑 スタッフアカウントの作成

### 簡単な方法（自動登録）

1. **Firebase Consoleでユーザーを作成**
   - [Firebase Authentication](https://console.firebase.google.com/project/reservation-platform-prod/authentication/users)
   - メールアドレス: `tanaka@staff.example.com` （`@staff`を含める）
   - パスワードを設定

2. **アプリでログイン**
   - 自動的に`employees`コレクションにドキュメントが作成されます

3. **店舗IDを設定**
   - Firestore Database → `employees` → 自分のUID
   - `shopId`フィールドを編集

詳細は [STAFF_SETUP.md](./STAFF_SETUP.md) を参照してください。

### employeesコレクションのデータ構造

```
employees/{uid}/
  - uid: "ユーザーUID"
  - email: "staff@example.com"
  - name: "スタッフ名"
  - role: "staff" | "manager" | "owner"
  - shopId: "店舗ID"  # 必須
  - isActive: true
  - createdAt: Timestamp
  - updatedAt: Timestamp
```

## 📂 ディレクトリ構成

```
lib/
├── models/                      # データモデル
│   ├── staff_user.dart         # スタッフユーザー
│   ├── shop.dart               # 店舗情報
│   └── printer_config.dart     # Wi-Fiプリンター設定
├── providers/                   # Riverpod プロバイダー
│   └── auth_provider.dart      # 認証プロバイダー
├── screens/                     # 画面
│   ├── login/                  # ログイン ✅
│   │   └── login_screen.dart
│   ├── home/                   # ホーム ✅
│   │   └── home_screen.dart
│   ├── orders/                 # 注文管理 🚧
│   ├── pos/                    # レジ・会計 🚧
│   ├── proxy_order/            # 代理注文 🚧
│   ├── reservations/           # 予約管理 🚧
│   └── settings/               # プリンター設定 🚧
├── services/                    # サービス
│   └── firebase_service.dart   # Firebase操作
└── main.dart                    # エントリーポイント
```

## 🎯 次の実装予定

1. **注文管理画面**
   - リアルタイム注文一覧
   - ステータス更新
   - 注文詳細表示

2. **Wi-Fiプリンター機能**
   - プリンター検索（同一ネットワーク内）
   - IP設定画面
   - テスト印刷
   - 自動印刷設定

3. **レジ・会計画面**
   - テーブル別未会計一覧
   - 会計処理
   - レシート自動印刷

4. **代理注文画面**
   - テーブル選択
   - メニュー選択
   - 注文確定

5. **予約管理画面**
   - 予約一覧
   - 予約承認/拒否

## 💡 特徴

- **Raspberry Pi不要**: スマホのみで完結
- **Wi-Fi接続**: 複数スタッフから同じプリンターを使用可能
- **リアルタイム**: Firestore onSnapshotで注文を即座に反映
- **バックグラウンド動作**: アプリがバックグラウンドでも新規注文を通知

## 🔧 トラブルシューティング

### ログインできない

1. employeesコレクションにユーザーが登録されているか確認
2. Firebase Authenticationでユーザーが有効か確認

### プリンターに接続できない（開発中）

1. プリンターとスマホが同じWi-Fiネットワークに接続されているか確認
2. プリンターのIPアドレスとポート番号が正しいか確認
3. ファイアウォールでポート9100がブロックされていないか確認
