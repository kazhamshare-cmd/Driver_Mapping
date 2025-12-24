# Xcodeでのビルド手順

## 必要な環境
- macOS
- Xcode 14.0以上
- Flutter SDK
- CocoaPods

## セットアップ

### 1. Flutterの依存関係をインストール

```bash
cd /Users/ikushimakazuyuki/Documents/reservation-platform/shop_staff_app
flutter pub get
```

### 2. CocoaPodsの依存関係をインストール

```bash
cd ios
pod install
```

## Xcodeでプロジェクトを開く

### 方法1: コマンドラインから開く

```bash
open ios/Runner.xcworkspace
```

**重要**: `Runner.xcodeproj`ではなく、**`Runner.xcworkspace`**を開いてください。

### 方法2: Xcodeアプリから開く

1. Xcodeを起動
2. File > Open...
3. `shop_staff_app/ios/Runner.xcworkspace`を選択

## ビルドとデバッグ

### シミュレーターでの実行

1. Xcodeで`Runner.xcworkspace`を開く
2. 上部のスキームメニューでターゲットデバイス（例：iPhone 15 Pro）を選択
3. `Cmd + R`またはプレイボタンをクリックして実行

### 実機での実行

1. iPhoneをMacに接続
2. Xcodeで`Runner.xcworkspace`を開く
3. 上部のスキームメニューで接続したデバイスを選択
4. **Signing & Capabilities**タブで以下を設定：
   - Team: あなたのApple Developer Team
   - Bundle Identifier: 必要に応じて変更（例：`com.yourcompany.shopStaffApp`）
5. `Cmd + R`で実行

## ビルド設定

### Debug（開発用）

```bash
flutter build ios --debug
```

### Release（本番用）

```bash
flutter build ios --release
```

### Archive（App Store配布用）

1. Xcodeで`Product > Archive`を選択
2. Organizerウィンドウが開く
3. アーカイブを選択して`Distribute App`をクリック
4. 配布方法を選択（App Store Connect、Ad Hoc、Enterpriseなど）

## トラブルシューティング

### Pod installでエラーが出る場合

```bash
cd ios
pod repo update
pod install --repo-update
```

### ビルドエラーが出る場合

```bash
# Flutterのキャッシュをクリア
flutter clean

# 再度依存関係をインストール
flutter pub get
cd ios
pod install
```

### Xcodeのキャッシュをクリア

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
```

## 設定済みの項目

✅ Firebase設定ファイル (`GoogleService-Info.plist`)
✅ CocoaPods依存関係
✅ ローカルネットワーク権限（Wi-Fiプリンター用）
✅ iOSプラットフォーム: iOS 13.0以上

## 権限設定

`Info.plist`に以下の権限が設定されています：

- **NSLocalNetworkUsageDescription**: Wi-Fiプリンターへの接続
- **NSBonjourServices**: プリンター検索

## ビルド構成

- **Debug**: 開発時のデバッグ用
- **Profile**: パフォーマンス測定用
- **Release**: 本番リリース用

## 注意事項

1. **常に`Runner.xcworkspace`を開く**：`Runner.xcodeproj`を直接開くとCocoaPodsの依存関係が認識されません
2. **Code Signing**: 実機でテストする場合は、有効なApple Developer アカウントが必要です
3. **Bundle Identifier**: App Storeにアップロードする場合は、一意のBundle Identifierを設定してください

## 便利なコマンド

```bash
# iOSシミュレーター一覧を表示
flutter devices

# 特定のシミュレーターで実行
flutter run -d "iPhone 15 Pro"

# ビルド情報を確認
flutter doctor -v

# Xcodeバージョンを確認
xcodebuild -version
```
