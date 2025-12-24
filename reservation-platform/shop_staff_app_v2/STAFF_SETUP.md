# スタッフアプリ - 初期セットアップガイド

## スタッフユーザーの登録方法（自動）

### ✨ 簡単な方法（推奨）

メールアドレスに`@staff`を含むユーザーでログインすると、自動的に`employees`コレクションにドキュメントが作成されます！

#### 手順：

1. **Firebase Consoleで新しいユーザーを作成**
   - [Firebase Authentication](https://console.firebase.google.com/project/reservation-platform-prod/authentication/users)
   - メールアドレス: 例 `tanaka@staff.example.com` （`@staff`を含める）
   - パスワードを設定

2. **アプリでログイン**
   - 作成したメールアドレスとパスワードでログイン
   - 自動的に`employees`コレクションにドキュメントが作成されます

3. **店舗IDを設定**
   - Firebaseコンソール → Firestore Database → `employees` → 自分のUID
   - `shopId`フィールドを編集して、所属する店舗のIDを設定

これで完了です！

---

## スタッフユーザーの登録方法（手動）

手動で詳細な設定をしたい場合：

### 前提条件

店舗が既にFirestoreの`shops`コレクションに登録されていること。

### 方法1: Firebaseコンソールで手動登録（推奨）

#### ステップ1: Firebase Authenticationにユーザーを作成

1. [Firebase Console](https://console.firebase.google.com/)を開く
2. プロジェクト`reservation-platform-prod`を選択
3. 左メニューから「Authentication」を選択
4. 「Users」タブを開く
5. 「Add user」をクリック
6. メールアドレスとパスワードを入力して作成
7. 作成されたユーザーの**UID**をコピー（例: `abc123def456...`）

#### ステップ2: Firestoreにemployeesドキュメントを作成

1. Firebase Consoleの左メニューから「Firestore Database」を選択
2. `employees`コレクションを開く（存在しない場合は作成）
3. 「Add document」をクリック
4. **Document ID**に、ステップ1でコピーした**UID**を貼り付け
5. 以下のフィールドを追加：

| フィールド名 | 型 | 値 |
|------------|---|---|
| `uid` | string | ユーザーのUID（Document IDと同じ） |
| `email` | string | ユーザーのメールアドレス |
| `name` | string | スタッフの名前（例: 田中太郎） |
| `shopId` | string | 所属店舗のID（shopsコレクションのドキュメントID） |
| `role` | string | `staff`, `manager`, または `owner` |
| `isActive` | boolean | `true` |
| `createdAt` | timestamp | 現在時刻 |
| `updatedAt` | timestamp | 現在時刻 |

6. 「Save」をクリック

#### ステップ3: アプリでログイン

作成したメールアドレスとパスワードでログインできます。

---

### 方法2: Firebase Admin SDKを使用（開発者向け）

#### 前提条件

- Node.jsがインストールされていること
- Firebase Admin SDKの認証情報（serviceAccountKey.json）

#### スタッフユーザー作成スクリプト

```bash
cd /Users/ikushimakazuyuki/Documents/reservation-platform
node scripts/create_staff_user.js <email> <password> <name> <shopId> <role>
```

**例:**
```bash
node scripts/create_staff_user.js staff@example.com password123 "田中太郎" "shop123abc" "staff"
```

#### 店舗一覧の確認

```bash
node scripts/list_shops.js
```

---

## shopIdの確認方法

### Firebaseコンソールで確認

1. Firebase Console → Firestore Database
2. `shops`コレクションを開く
3. 店舗のドキュメントを選択
4. ドキュメントIDが`shopId`です

### shop-dashboardで確認

1. ブラウザで`https://reservation-shop-dashboard.web.app/`にアクセス
2. 管理者でログイン
3. URLまたはFirestoreコンソールでshopIdを確認

---

## トラブルシューティング

### 「ユーザー情報が取得できません」と表示される

**原因**: ログインしたユーザーのUIDに対応する`employees`ドキュメントが存在しない

**解決策**:
1. Firebase Console → AuthenticationでユーザーのUIDを確認
2. Firestore Database → `employees`コレクションに該当UIDのドキュメントが存在するか確認
3. 存在しない場合は、上記の手順で作成

### 「店舗情報が取得できません」と表示される

**原因**: employeesドキュメントの`shopId`が間違っているか、該当する店舗が存在しない

**解決策**:
1. Firestore Database → `employees`コレクションでユーザーのドキュメントを開く
2. `shopId`の値を確認
3. `shops`コレクションに該当するドキュメントが存在するか確認
4. 存在しない場合は、正しい`shopId`に修正

### ログインできない

**原因**: Firebase Authenticationにユーザーが登録されていない、またはパスワードが間違っている

**解決策**:
1. Firebase Console → Authenticationでユーザーが存在するか確認
2. パスワードをリセットするか、新しいユーザーを作成

---

## テスト用アカウント例

開発/テスト環境用のサンプルデータ:

```
Email: staff@test.com
Password: test1234
Name: テストスタッフ
Role: staff
```

これらの情報でFirebase AuthenticationとFirestoreに登録してください。

---

## 権限レベル

- **owner**: 店舗オーナー - 全ての機能にアクセス可能
- **manager**: マネージャー - スタッフ管理以外の機能にアクセス可能
- **staff**: スタッフ - 注文管理、レジ、代理注文機能にアクセス可能

現在のバージョンでは、全ての役割で同じ機能にアクセスできますが、将来的に権限による制限を追加予定です。
