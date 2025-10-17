# 広告統合ガイド

## ✅ 完了項目

1. **AdService作成** - `lib/services/ad_service.dart`
2. **BannerAdWidget作成** - `lib/widgets/banner_ad_widget.dart`
3. **AdMob初期化** - `lib/main.dart`に追加済み
4. **iOS設定** - `ios/Runner/Info.plist`に AdMob ID設定済み
5. **Android設定** - `android/app/src/main/AndroidManifest.xml`に AdMob ID設定済み

## 📝 手動で追加が必要な箇所

### settings_screen.dartにバナー広告を追加

`lib/screens/settings_screen.dart`の以下の構造に広告を追加：

```dart
return Scaffold(
  backgroundColor: const Color(0xFF1a1a2e),
  body: SafeArea(
    child: Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            // ... 既存のコンテンツ
          ),
        ),
        // ⬇️ ここに追加
        _buildBottomBannerAd(),
      ],
    ),
  ),
);
```

**具体的な手順：**
1. 115行目の`children: [`を見つける
2. `Expanded(...),`の後（閉じ括弧の後）に`_buildBottomBannerAd(),`を追加
3. メソッドは既に761行目に定義済み

### 他の画面にも同様に追加

以下の画面にも同じパターンで追加可能：
- `lib/screens/online_lobby_screen.dart`
- `lib/screens/game_screen.dart`
- `lib/screens/online_game_screen.dart`

## 🎯 インタースティシャル広告の表示

ゲーム終了時に自動表示されるよう設定済み：

```dart
// ゲーム終了時に呼び出す
AdService().onGameEnd();
```

- 3回ゲームプレイごとに1回表示
- Googleの判断で適時表示頻度が調整されます

## 🔑 広告ユニットID（現在はテストID使用中）

### 本番環境用IDに置き換える

`lib/services/ad_service.dart`の以下の箇所を本番IDに置き換えてください：

```dart
// iOS
static const String _bannerAdUnitIdIOS = 'YOUR_IOS_BANNER_ID';
static const String _interstitialAdUnitIdIOS = 'YOUR_IOS_INTERSTITIAL_ID';

// Android
static const String _bannerAdUnitIdAndroid = 'YOUR_ANDROID_BANNER_ID';
static const String _interstitialAdUnitIdAndroid = 'YOUR_ANDROID_INTERSTITIAL_ID';
```

### App ID（既に設定済み）

- **iOS**: `ca-app-pub-1116360810482665~1859056041`
- **Android**: `ca-app-pub-1116360810482665~6599808327`

## ✨ 完成！

上記の手動追加を完了すれば、iOS/Androidで以下が動作します：
- 画面下部に常時バナー広告表示
- ゲーム終了時にインタースティシャル広告表示（3回に1回）
