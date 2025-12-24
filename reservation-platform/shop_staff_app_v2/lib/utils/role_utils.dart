import 'package:flutter/material.dart';

/// ロール（権限）関連のユーティリティクラス
class RoleUtils {
  // ロール定数
  static const String roleOwner = 'owner';
  static const String roleManager = 'manager';
  static const String roleStaff = 'staff';

  /// オーナーかどうか
  static bool isOwner(String? role) => role == roleOwner;

  /// マネージャーかどうか
  static bool isManager(String? role) => role == roleManager;

  /// スタッフかどうか
  static bool isStaff(String? role) => role == roleStaff;

  /// 管理者（オーナーまたはマネージャー）かどうか
  static bool isAdmin(String? role) => role == roleOwner || role == roleManager;

  /// 指定されたロール以上の権限があるかどうか
  /// オーナー > マネージャー > スタッフ
  static bool hasRoleOrHigher(String? currentRole, String requiredRole) {
    final roleHierarchy = {
      roleOwner: 3,
      roleManager: 2,
      roleStaff: 1,
    };

    final currentLevel = roleHierarchy[currentRole] ?? 0;
    final requiredLevel = roleHierarchy[requiredRole] ?? 0;

    return currentLevel >= requiredLevel;
  }

  /// ロールの表示名を取得
  static String getRoleDisplayName(String? role, {String languageCode = 'ja'}) {
    switch (role) {
      case roleOwner:
        return languageCode == 'ja' ? 'オーナー' : 'Owner';
      case roleManager:
        return languageCode == 'ja' ? 'マネージャー' : 'Manager';
      case roleStaff:
        return languageCode == 'ja' ? 'スタッフ' : 'Staff';
      default:
        return languageCode == 'ja' ? '不明' : 'Unknown';
    }
  }

  /// 権限がない場合にSnackBarを表示
  static void showPermissionDeniedSnackBar(
    BuildContext context, {
    String? message,
    String languageCode = 'ja',
  }) {
    final defaultMessage = languageCode == 'ja'
        ? 'この操作にはマネージャー以上の権限が必要です'
        : 'Manager or higher permission is required for this action';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? defaultMessage),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 権限チェック付きで操作を実行
  /// 権限がない場合はSnackBarを表示してfalseを返す
  static bool checkPermissionAndExecute({
    required BuildContext context,
    required String? currentRole,
    required String requiredRole,
    String? deniedMessage,
    String languageCode = 'ja',
  }) {
    if (!hasRoleOrHigher(currentRole, requiredRole)) {
      showPermissionDeniedSnackBar(
        context,
        message: deniedMessage,
        languageCode: languageCode,
      );
      return false;
    }
    return true;
  }

  /// 管理者権限が必要な操作の権限チェック
  static bool requireAdmin({
    required BuildContext context,
    required String? currentRole,
    String? deniedMessage,
    String languageCode = 'ja',
  }) {
    return checkPermissionAndExecute(
      context: context,
      currentRole: currentRole,
      requiredRole: roleManager,
      deniedMessage: deniedMessage,
      languageCode: languageCode,
    );
  }

  /// オーナー権限が必要な操作の権限チェック
  static bool requireOwner({
    required BuildContext context,
    required String? currentRole,
    String? deniedMessage,
    String languageCode = 'ja',
  }) {
    final defaultMessage = languageCode == 'ja'
        ? 'この操作にはオーナー権限が必要です'
        : 'Owner permission is required for this action';

    return checkPermissionAndExecute(
      context: context,
      currentRole: currentRole,
      requiredRole: roleOwner,
      deniedMessage: deniedMessage ?? defaultMessage,
      languageCode: languageCode,
    );
  }
}

/// 権限に基づいて表示/非表示を切り替えるウィジェット
class RoleBasedWidget extends StatelessWidget {
  final String? currentRole;
  final String requiredRole;
  final Widget child;
  final Widget? fallback;

  const RoleBasedWidget({
    super.key,
    required this.currentRole,
    required this.requiredRole,
    required this.child,
    this.fallback,
  });

  /// 管理者のみ表示
  factory RoleBasedWidget.adminOnly({
    Key? key,
    required String? currentRole,
    required Widget child,
    Widget? fallback,
  }) {
    return RoleBasedWidget(
      key: key,
      currentRole: currentRole,
      requiredRole: RoleUtils.roleManager,
      child: child,
      fallback: fallback,
    );
  }

  /// オーナーのみ表示
  factory RoleBasedWidget.ownerOnly({
    Key? key,
    required String? currentRole,
    required Widget child,
    Widget? fallback,
  }) {
    return RoleBasedWidget(
      key: key,
      currentRole: currentRole,
      requiredRole: RoleUtils.roleOwner,
      child: child,
      fallback: fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (RoleUtils.hasRoleOrHigher(currentRole, requiredRole)) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}
