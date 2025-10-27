# Firebase Remote Config 設定ガイド

## 概要
アプリのバージョンチェック機能で使用するFirebase Remote Configの設定方法を説明します。

## Firebase Console での設定

### 1. Firebase Console にアクセス
1. [Firebase Console](https://console.firebase.google.com/) にアクセス
2. プロジェクトを選択

### 2. Remote Config を有効化
1. 左メニューから「Remote Config」を選択
2. 「パラメータを追加」をクリック

### 3. 必要なパラメータを追加

#### 3.1 最小必須バージョン
- **パラメータ名**: `min_required_version`
- **デフォルト値**: `1.0.0`
- **説明**: アプリが動作するために必要な最小バージョン

#### 3.2 強制アップデートメッセージ
- **パラメータ名**: `force_update_message`
- **デフォルト値**: `アプリを最新バージョンにアップデートしてください。`
- **説明**: アップデートが必要な場合に表示するメッセージ

#### 3.3 iOS アップデートURL
- **パラメータ名**: `update_url_ios`
- **デフォルト値**: `https://apps.apple.com/app/id1234567890`
- **説明**: iOS用のApp Store URL（実際のApp IDに変更してください）

#### 3.4 Android アップデートURL
- **パラメータ名**: `update_url_android`
- **デフォルト値**: `https://play.google.com/store/apps/details?id=co.jp.b19.atamaoshiriapp`
- **説明**: Android用のGoogle Play Store URL

### 4. 条件付きパラメータ（オプション）

#### 4.1 プラットフォーム別の設定
- **条件**: `app.platform == 'ios'`
- **パラメータ**: `update_url_ios`
- **値**: iOS用のApp Store URL

- **条件**: `app.platform == 'android'`
- **パラメータ**: `update_url_android`
- **値**: Android用のGoogle Play Store URL

## 使用方法

### 1. バージョン管理
- 新しいバージョンをリリースする際は、`min_required_version`を更新
- 例: `1.0.0` → `1.1.0` → `1.2.0`

### 2. 段階的ロールアウト
- 特定のユーザーグループにのみ新しいバージョンを要求
- 条件: `app.version < '1.1.0'` など

### 3. 緊急アップデート
- セキュリティ問題などで緊急アップデートが必要な場合
- `min_required_version`を即座に更新

## 注意事項

### 1. App Store ID の取得
- iOS用のApp Store URLは実際のApp IDに変更が必要
- App Store Connect で確認可能

### 2. バージョン番号の形式
- セマンティックバージョニング（例: 1.0.0, 1.1.0, 2.0.0）
- メジャー.マイナー.パッチ の形式

### 3. テスト方法
- Firebase Console でパラメータを変更してテスト
- 開発環境では `min_required_version` を高く設定してテスト

## トラブルシューティング

### 1. Remote Config が取得できない場合
- ネットワーク接続を確認
- Firebase プロジェクトの設定を確認
- アプリのバンドルIDが正しいか確認

### 2. バージョン比較が正しく動作しない場合
- バージョン番号の形式を確認（例: 1.0.0）
- セマンティックバージョニングに従っているか確認

### 3. アップデートURLが開かない場合
- URLの形式を確認
- デバイスでApp Store/Google Play Storeが利用可能か確認

