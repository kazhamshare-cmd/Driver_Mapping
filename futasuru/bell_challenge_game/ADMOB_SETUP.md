# AdMob設定ガイド

## ✅ 完了済み設定

### 1. App ID設定（完了）
- **iOS**: `ca-app-pub-1116360810482665~1859056041`
- **Android**: `ca-app-pub-1116360810482665~7111038210`

設定済みファイル：
- `ios/Runner/Info.plist`
- `android/app/src/main/AndroidManifest.xml`

### 2. 広告ユニットID設定（完了）

#### iOS
- **バナー広告**: `ca-app-pub-1116360810482665/4160402860`
- **インタースティシャル広告**: `ca-app-pub-1116360810482665/8373801381`

#### Android
- **バナー広告**: `ca-app-pub-1116360810482665/4844075322`
- **インタースティシャル広告**: `ca-app-pub-1116360810482665/1256184106`

設定済みファイル：`lib/services/ad_service.dart`

### 3. AdMobサービス実装（完了）
- ✅ `lib/services/ad_service.dart` - バナー広告・インタースティシャル広告管理
- ✅ `lib/widgets/banner_ad_widget.dart` - 再利用可能なバナー広告ウィジェット
- ✅ `lib/main.dart` - AdMob初期化処理追加
- ✅ 設定画面下部にバナー広告配置完了

### 4. 広告表示仕様（完了）
- ✅ バナー広告: iOS/Android画面の下部に表示
- ✅ インタースティシャル広告: 3ゲームに1回表示（Googleが最適化）

## 📱 アプリ承認後の流れ

1. App Store / Google Playにアプリを申請・承認
2. AdMob管理画面でアプリを登録
3. 広告が自動的に配信開始（本番モードへ自動切替）

## ⚠️ 注意事項

- 広告ユニットIDを設定しないと広告が表示されません
- App Store / Google Play承認前でも広告は表示されますが、収益は発生しません
- アプリ承認後、AdMob側でアプリを承認すると本番広告が配信されます
- 現在の実装では本番IDを使用（テストIDは不要）
