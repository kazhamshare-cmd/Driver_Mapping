import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../models/staff_user.dart';
import '../models/shop.dart';

// FirebaseServiceのプロバイダー
final firebaseServiceProvider = Provider((ref) => FirebaseService());

// 認証状態のプロバイダー
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseServiceProvider).authStateChanges;
});

// スタッフユーザー情報のプロバイダー
final staffUserProvider = FutureProvider<StaffUser?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;

  final firebaseService = ref.watch(firebaseServiceProvider);
  return await firebaseService.getStaffUser(user.uid);
});

// 店舗情報のプロバイダー
final shopProvider = FutureProvider<Shop?>((ref) async {
  final staffUser = await ref.watch(staffUserProvider.future);
  if (staffUser == null) return null;

  final firebaseService = ref.watch(firebaseServiceProvider);
  return await firebaseService.getShop(staffUser.shopId);
});

// ============ アプリモード管理 ============

/// アプリのモード（営業中 / 管理）
enum AppMode {
  operation, // 営業中モード
  management, // 管理モード
}

/// 現在のアプリモードを管理するプロバイダー
final appModeProvider = StateProvider<AppMode>((ref) => AppMode.operation);

/// 管理モードにアクセスできるかどうか（オーナーまたは店長のみ）
final canAccessManagementModeProvider = Provider<bool>((ref) {
  final staffUser = ref.watch(staffUserProvider).value;
  final role = staffUser?.role;
  return role == 'owner' || role == 'manager';
});

// ============ 基本権限チェックプロバイダー ============

/// 現在のユーザーがオーナーかどうか
final isOwnerProvider = Provider<bool>((ref) {
  final staffUser = ref.watch(staffUserProvider).value;
  return staffUser?.role == 'owner';
});

/// 現在のユーザーがマネージャー（店長）かどうか
final isManagerProvider = Provider<bool>((ref) {
  final staffUser = ref.watch(staffUserProvider).value;
  return staffUser?.role == 'manager';
});

/// 現在のユーザーがスタッフかどうか
final isStaffProvider = Provider<bool>((ref) {
  final staffUser = ref.watch(staffUserProvider).value;
  return staffUser?.role == 'staff';
});

/// 現在のユーザーが管理者（オーナーまたはマネージャー）かどうか
final isAdminProvider = Provider<bool>((ref) {
  final staffUser = ref.watch(staffUserProvider).value;
  final role = staffUser?.role;
  return role == 'owner' || role == 'manager';
});

// ============ 機能別権限プロバイダー ============

// ─────────────────────────────────────────────
// オーナー専用権限
// ─────────────────────────────────────────────

/// スタッフ登録・管理権限（オーナーのみ）
final canManageStaffProvider = Provider<bool>((ref) {
  return ref.watch(isOwnerProvider);
});

/// 店長登録・管理権限（オーナーのみ）
final canManageManagersProvider = Provider<bool>((ref) {
  return ref.watch(isOwnerProvider);
});

/// オーダー削除権限（オーナーのみ）
final canDeleteOrdersProvider = Provider<bool>((ref) {
  return ref.watch(isOwnerProvider);
});

/// キャンセル内容閲覧権限（オーナーのみ）
final canViewCancellationsProvider = Provider<bool>((ref) {
  return ref.watch(isOwnerProvider);
});

/// ブラックリスト管理権限（オーナーのみ）
final canManageBlacklistProvider = Provider<bool>((ref) {
  return ref.watch(isOwnerProvider);
});

/// LINE設定権限（オーナーのみ）
final canManageLineSettingsProvider = Provider<bool>((ref) {
  return ref.watch(isOwnerProvider);
});

/// 店舗設定権限（オーナーのみ）
final canManageShopSettingsProvider = Provider<bool>((ref) {
  return ref.watch(isOwnerProvider);
});

/// 分析・レポート編集権限（オーナーのみ）
final canEditAnalyticsProvider = Provider<bool>((ref) {
  return ref.watch(isOwnerProvider);
});

// ─────────────────────────────────────────────
// オーナー・店長共通権限
// ─────────────────────────────────────────────

/// 商品管理権限（オーナーまたはマネージャー）- 追加・修正・価格変更
final canManageProductsProvider = Provider<bool>((ref) {
  return ref.watch(isAdminProvider);
});

/// カテゴリ管理権限（オーナーまたはマネージャー）
final canManageCategoriesProvider = Provider<bool>((ref) {
  return ref.watch(isAdminProvider);
});

/// シフト調整・決定権限（オーナーまたはマネージャー）
final canManageShiftsProvider = Provider<bool>((ref) {
  return ref.watch(isAdminProvider);
});

/// 出退勤時間修正権限（オーナーまたはマネージャー）
final canEditAttendanceProvider = Provider<bool>((ref) {
  return ref.watch(isAdminProvider);
});

/// テーブル管理権限（オーナーまたはマネージャー）
final canManageTablesProvider = Provider<bool>((ref) {
  return ref.watch(isAdminProvider);
});

/// レジ締め・両替権限（オーナーまたはマネージャー）
final canManageRegisterProvider = Provider<bool>((ref) {
  return ref.watch(isAdminProvider);
});

/// 分析・レポート閲覧権限（オーナーまたはマネージャー）
final canViewAnalyticsProvider = Provider<bool>((ref) {
  return ref.watch(isAdminProvider);
});

/// 顧客情報閲覧権限（オーナーまたはマネージャー）
final canViewCustomersProvider = Provider<bool>((ref) {
  return ref.watch(isAdminProvider);
});

/// 顧客情報編集権限（オーナーのみ）
final canEditCustomersProvider = Provider<bool>((ref) {
  return ref.watch(isOwnerProvider);
});

/// バック承認権限（オーナーまたはマネージャー）
final canManageVoidRequestsProvider = Provider<bool>((ref) {
  return ref.watch(isAdminProvider);
});

// ─────────────────────────────────────────────
// 全員共通権限（営業中モード）
// ─────────────────────────────────────────────

/// 代理注文権限（全員）
final canProxyOrderProvider = Provider<bool>((ref) {
  return ref.watch(staffUserProvider).value != null;
});

/// レジ・会計権限（全員）
final canUseRegisterProvider = Provider<bool>((ref) {
  return ref.watch(staffUserProvider).value != null;
});

/// 注文閲覧権限（全員）
final canViewOrdersProvider = Provider<bool>((ref) {
  return ref.watch(staffUserProvider).value != null;
});

/// 予約対応権限（全員）
final canHandleReservationsProvider = Provider<bool>((ref) {
  return ref.watch(staffUserProvider).value != null;
});

/// 出退勤権限（全員）
final canClockInOutProvider = Provider<bool>((ref) {
  return ref.watch(staffUserProvider).value != null;
});

// ============ 現在のユーザーロール取得 ============

/// 現在のユーザーロールを取得
final currentRoleProvider = Provider<String?>((ref) {
  final staffUser = ref.watch(staffUserProvider).value;
  return staffUser?.role;
});

/// ロールの日本語表示名を取得
final roleDisplayNameProvider = Provider<String>((ref) {
  final role = ref.watch(currentRoleProvider);
  switch (role) {
    case 'owner':
      return 'オーナー';
    case 'manager':
      return '店長';
    case 'staff':
      return 'スタッフ';
    default:
      return '未設定';
  }
});

// ログイン処理のプロバイダー
final loginProvider = Provider((ref) => LoginNotifier(ref));

class LoginNotifier {
  final Ref ref;
  
  LoginNotifier(this.ref);
  
  Future<void> signIn(String email, String password) async {
    final firebaseService = ref.read(firebaseServiceProvider);
    await firebaseService.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
  
  Future<void> signOut() async {
    final firebaseService = ref.read(firebaseServiceProvider);
    await firebaseService.signOut();
  }
  
  Future<void> sendPasswordResetEmail(String email) async {
    final firebaseService = ref.read(firebaseServiceProvider);
    await firebaseService.sendPasswordResetEmail(email);
  }
}
