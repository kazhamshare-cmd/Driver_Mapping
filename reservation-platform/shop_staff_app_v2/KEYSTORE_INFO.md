# Android Keystore 情報

## 重要: このファイルを安全に保管してください

Google Play Storeへのアップロード時に必要な署名キー情報です。
**このキーを紛失すると、同じアプリとしてアップデートできなくなります。**

---

## Keystore 情報

| 項目 | 値 |
|------|------|
| ファイル名 | `shop-staff-app-release.keystore` |
| ファイル場所 | `android/shop-staff-app-release.keystore` |
| Key Alias | `shop-staff-app` |
| Store Password | `ShopStaff2024Secure` |
| Key Password | `ShopStaff2024Secure` |
| 有効期限 | 10,000日（約27年） |
| アルゴリズム | RSA 2048bit |
| 署名アルゴリズム | SHA256withRSA |

---

## 証明書情報

```
CN=EASYMENU
OU=Development
O=EASYMENU-Reservation
L=Tokyo
ST=Tokyo
C=JP
```

---

## ファイル構成

```
shop_staff_app/
├── android/
│   ├── shop-staff-app-release.keystore  ← 署名キー（重要！）
│   ├── key.properties                   ← キー設定ファイル
│   └── app/
│       ├── build.gradle.kts             ← ビルド設定
│       └── proguard-rules.pro           ← ProGuard設定
```

---

## key.properties の内容

```properties
storePassword=ShopStaff2024Secure
keyPassword=ShopStaff2024Secure
keyAlias=shop-staff-app
storeFile=../shop-staff-app-release.keystore
```

---

## ビルドコマンド

### リリース用AAB（Google Play用）
```bash
flutter build appbundle --release
```
出力: `build/app/outputs/bundle/release/app-release.aab`

### リリース用APK
```bash
flutter build apk --release
```

---

## Google Play Console 設定

### アプリ情報
- **パッケージ名**: `com.reservation.platform.shop_staff_app`
- **アプリ名**: 予約スタッフ（EASYMENU）
- **最小Android**: 9.0 (API 28)

### アップロード鍵の SHA-1 フィンガープリント確認
```bash
keytool -list -v -keystore android/shop-staff-app-release.keystore -alias shop-staff-app
```

---

## バックアップ推奨

以下のファイルを必ずバックアップしてください：
1. `android/shop-staff-app-release.keystore`
2. `android/key.properties`
3. この `KEYSTORE_INFO.md` ファイル

---

## 更新履歴

| 日付 | バージョン | 内容 |
|------|-----------|------|
| 2024-12-09 | 1.1.2+2 | 初回リリースキー作成 |

---

## 注意事項

1. **キーの紛失**: keystoreファイルを紛失すると、同じパッケージ名でアプリを更新できなくなります
2. **パスワード変更**: Google Playにアップロード後は、このキーのパスワードを変更しないでください
3. **Git管理**: `key.properties` と `.keystore` ファイルは `.gitignore` に追加することを推奨します

---

*作成日: 2024年12月9日*
*作成者: Claude Code*
