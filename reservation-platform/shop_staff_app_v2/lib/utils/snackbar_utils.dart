import 'package:flutter/material.dart';

/// SnackBar表示用ユーティリティクラス
/// アプリ全体で統一されたSnackBar表示を提供
class SnackBarUtils {
  /// 成功メッセージを表示（緑色）
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// エラーメッセージを表示（赤色）
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 情報メッセージを表示（青色）
  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 警告メッセージを表示（オレンジ色）
  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// アクション付きSnackBarを表示
  static void showWithAction(
    BuildContext context, {
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    Color backgroundColor = Colors.grey,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: actionLabel,
          textColor: Colors.white,
          onPressed: onAction,
        ),
      ),
    );
  }

  /// 現在表示中のSnackBarを閉じる
  static void hide(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }
}
