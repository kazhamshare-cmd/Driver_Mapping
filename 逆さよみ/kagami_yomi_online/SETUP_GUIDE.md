# 鏡文字の逆読みONLINE - セットアップガイド

## プロジェクト概要

**タイトル**: 鏡文字の逆読みONLINE
**開発会社**: 株式会社ビーク
**開発者**: KAZUYUKI IKUSHIMA

### ゲームモード

1. **ソロモード**
   - リラックスモード（時間制限なし）
   - タイムアタックモード（1問10秒）

2. **オンラインモード**
   - 最大4人で対戦
   - 正解: +1点、不正解: -2点
   - LINE通話などで会話しながら楽しむ

### 主要機能

- ドラッグ&ドロップで文字を並び替え
- 鏡文字の表示
- Firebase によるオンラインマルチプレイ
- AdMob 広告統合（バナー・インタースティシャル）
- ハイスコア保存機能
- 効果音システム

## セットアップ手順

### 1. Firebase プロジェクトの設定

#### 1.1 Firebase Console でプロジェクトを作成

1. https://console.firebase.google.com/ にアクセス
2. 新しいプロジェクトを作成
3. プロジェクト名を入力（例: kagami-yomi-online）

#### 1.2 FlutterFire CLI でFirebase設定

```bash
# FlutterFire CLI をインストール
dart pub global activate flutterfire_cli

# プロジェクトディレクトリで実行
cd kagami_yomi_online
flutterfire configure --project=your-project-id
```

これにより `lib/firebase_options.dart` が自動生成されます。

#### 1.3 Cloud Firestore の有効化

1. Firebase Console で「Firestore Database」を選択
2. 「データベースを作成」をクリック
3. テストモードで開始（後で本番用のセキュリティルールに変更）

#### 1.4 セキュリティルール設定

Firestore のセキュリティルールを設定:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /rooms/{roomId} {
      // 誰でも読み取り可能
      allow read: if true;

      // 認証なしで作成・更新可能（匿名認証の場合）
      allow create, update: if true;

      // 作成から24時間後に自動削除
      allow delete: if request.time > resource.data.createdAt + duration.value(24, 'h');
    }
  }
}
```

### 2. AdMob の設定

#### 2.1 Android の設定

`android/app/src/main/AndroidManifest.xml` に以下を追加:

```xml
<manifest>
    <application>
        <!-- AdMob App ID -->
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-1116360810482665~ANDROID_APP_ID"/>
    </application>
</manifest>
```

**注意**: Android用のAdMob IDを取得して置き換える必要があります。
`lib/services/ad_service.dart` 内の Android ID も更新してください。

#### 2.2 iOS の設定

`ios/Runner/Info.plist` に以下を追加:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-1116360810482665~5332934959</string>

<!-- App Tracking Transparency -->
<key>NSUserTrackingUsageDescription</key>
<string>広告をパーソナライズするために使用されます</string>
```

### 3. アプリアイコンとスプラッシュスクリーンの設定

#### 3.1 アプリアイコンの準備

1. 1024x1024ピクセルのPNG画像を用意
2. `assets/icon/app_icon.png` として保存
3. 以下のコマンドを実行:

```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

これにより、iOS/Android用のアイコンが自動生成されます。

#### 3.2 スプラッシュスクリーンの生成

```bash
flutter pub run flutter_native_splash:create
```

スプラッシュスクリーンは白背景に「株式会社ビーク」の文字が表示されます。

### 4. サポートOS バージョン

**iOS**: iOS 15.0以上
**Android**: Android 7.0 (API Level 24) 以上

古いOSバージョンはサポート対象外となっています。

### 5. 依存関係のインストール

```bash
flutter pub get
```

### 6. ビルドと実行

#### iOS

```bash
cd ios
pod install
cd ..
flutter run
```

#### Android

```bash
flutter run
```

## プロジェクト構造

```
lib/
├── main.dart                      # アプリエントリーポイント
├── firebase_options.dart          # Firebase設定
├── constants/                     # 定数
├── models/                        # データモデル
│   ├── player.dart
│   ├── game_room.dart
│   └── question.dart
├── services/                      # ビジネスロジック
│   ├── firebase_service.dart     # Firebase操作
│   ├── ad_service.dart           # AdMob広告
│   ├── question_service.dart     # 問題管理
│   ├── score_service.dart        # スコア管理
│   └── sound_service.dart        # 効果音
├── screens/                       # 画面
│   ├── splash_screen.dart         # スプラッシュ画面
│   ├── home_screen.dart
│   ├── solo_mode_select_screen.dart
│   ├── solo_game_screen.dart
│   ├── online_mode_menu_screen.dart
│   ├── create_room_screen.dart
│   └── join_room_screen.dart
└── widgets/                       # 再利用可能なUI部品
    ├── draggable_character.dart
    └── answer_area.dart
```

## 実装済み機能

✅ プロジェクト構造とセットアップ
✅ Firebase 統合（基礎）
✅ AdMob 統合
✅ データモデル（Player, GameRoom, Question）
✅ Firebase サービス（ルーム管理）
✅ スコア管理とハイスコア保存
✅ 効果音サービス
✅ メインメニュー画面
✅ ソロモード選択画面
✅ ソロゲーム画面（時間制限あり/なし）
✅ ドラッグ&ドロップUI
✅ オンラインモードメニュー
✅ ルーム作成画面
✅ ルーム参加画面
✅ カスタムスプラッシュスクリーン（株式会社ビーク表示）
✅ 段階的な難易度システム（3文字ひらがな→漢字3文字）
✅ iOS 15.0+ / Android 7.0+ サポート

## 未実装機能（要追加）

⚠️ **オンラインゲーム画面**
- ルーム内でのゲームプレイ
- リアルタイム同期
- プレイヤー状態表示
- スコアボード

⚠️ **効果音ファイル**
- assets/sounds/ ディレクトリに音声ファイルを追加
- sound_service.dart のコメントアウトを解除

⚠️ **Firebase Authentication（オプション）**
- 匿名認証またはメールログインの追加
- セキュリティ強化

⚠️ **追加の問題データ**
- より多くの単語を question_service.dart に追加

## 次のステップ

### 1. オンラインゲーム画面の実装

`lib/screens/online_game_screen.dart` を作成し、以下を実装:

- Firestore のリアルタイムリスナー
- 各プレイヤーの状態表示
- ホストのゲーム開始制御
- 問題の同期
- スコア更新

### 2. 効果音の追加

1. 効果音ファイルを準備（MP3またはWAV形式）:
   - game_start.mp3
   - correct.mp3
   - incorrect.mp3
   - click.mp3
   - time_up.mp3
   - game_over.mp3
   - clear.mp3

2. `assets/sounds/` ディレクトリに配置

3. `lib/services/sound_service.dart` のコメントを解除

### 3. テストとデバッグ

```bash
# 分析実行
flutter analyze

# テスト実行
flutter test
```

### 4. リリースビルド

#### Android

```bash
flutter build appbundle --release
```

#### iOS

```bash
flutter build ipa --release
```

## トラブルシューティング

### Firebase接続エラー

- `flutterfire configure` を再実行
- google-services.json (Android) と GoogleService-Info.plist (iOS) が正しく配置されているか確認

### AdMob広告が表示されない

- AdMob アプリIDが正しく設定されているか確認
- テストデバイスIDを設定（開発中）
- 本番環境では実際の広告IDに置き換える

### ビルドエラー

```bash
flutter clean
flutter pub get
flutter pub upgrade
```

## サポート

問題が発生した場合は、以下を確認してください:

1. Flutter SDKが最新版か
2. 全ての依存関係が正しくインストールされているか
3. Firebase プロジェクト設定が正しいか
4. AdMob IDが正しく設定されているか

## ライセンス

このプロジェクトは株式会社ビークが所有しています。
