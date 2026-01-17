# LogiTrace Android Keystore Information

## Important: Keep this file secure and never commit to public repositories!

---

## Keystore Details

| Property | Value |
|----------|-------|
| **Keystore File** | `keystore/logitrace-release.keystore` |
| **Keystore Password** | `LogiTrace2025!` |
| **Key Alias** | `logitrace` |
| **Key Password** | `LogiTrace2025!` |
| **Validity** | 10,000 days (approximately 27 years) |
| **Algorithm** | RSA 2048-bit |
| **Signature** | SHA256withRSA |

---

## Certificate Information

| Field | Value |
|-------|-------|
| **CN (Common Name)** | B19 Inc |
| **OU (Organization Unit)** | Mobile Development |
| **O (Organization)** | B19 Inc |
| **L (Locality)** | Sapporo |
| **ST (State)** | Hokkaido |
| **C (Country)** | JP |

---

## Android Package Information

| Property | Value |
|----------|-------|
| **Package Name** | `jp.co.b19.logitrace` |
| **App Name** | LogiTrace |
| **Version** | 1.0.0 |
| **Minimum SDK** | Android 9.0 (API Level 28) |

---

## Build Commands

### Local AAB Build (EAS)
```bash
cd mobile-app
npx eas build --platform android --profile production --local
```

### Gradle Build (after ejecting)
```bash
cd android
./gradlew bundleRelease
```

---

## Environment Variables (for CI/CD)

```bash
export ANDROID_KEYSTORE_PATH="./keystore/logitrace-release.keystore"
export ANDROID_KEYSTORE_PASSWORD="LogiTrace2025!"
export ANDROID_KEY_ALIAS="logitrace"
export ANDROID_KEY_PASSWORD="LogiTrace2025!"
```

---

## EAS Credentials Setup

When using EAS Build, you can configure credentials via:

```bash
# Upload existing keystore to EAS
npx eas credentials
# Select: Android > Production > Keystore > Upload existing keystore
```

---

## Important Notes

1. **Backup**: Always keep multiple secure backups of the keystore file
2. **Security**: Never share keystore passwords in public channels
3. **Updates**: Use the same keystore for all future app updates
4. **Recovery**: If keystore is lost, you cannot update the existing app on Play Store

---

## Build Outputs (v1.0.0)

### Android AAB
- **File**: `build-output/logitrace-v1.0.0.aab`
- **Size**: 46.3 MB
- **Target SDK**: 36
- **Min SDK**: 28 (Android 9.0 Pie)
- **Build Date**: 2025-01-16

### iOS Xcode Project
- **Project**: `ios/LogiTrace.xcworkspace`
- **Bundle ID**: `jp.co.b19.logitrace`

To archive for App Store:
1. Open `ios/LogiTrace.xcworkspace` in Xcode
2. Select the "LogiTrace" scheme and a physical device or "Any iOS Device"
3. Go to Product > Archive
4. After archiving, use Organizer to distribute to App Store

---

## Created

- **Date**: 2025-01-16
- **Created By**: Automated build script
