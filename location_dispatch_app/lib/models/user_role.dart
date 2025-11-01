import 'package:flutter/material.dart';

enum UserRole {
  systemAdmin, // システム全体管理者（全組織横断管理）
  admin,       // 組織管理者（ユーザー管理、組織設定）
  operator,    // オペレーター（依頼受付、配車手配）
  driver,      // ドライバー（送迎担当）
  worker;      // 接客対応者（実際の接客対応担当）

  String toJson() => name;

  static UserRole fromJson(String json) {
    return UserRole.values.firstWhere((role) => role.name == json);
  }

  // 日本語表示名
  String get displayName {
    switch (this) {
      case UserRole.systemAdmin:
        return 'システム管理者';
      case UserRole.admin:
        return '組織管理者';
      case UserRole.operator:
        return 'オペレーター';
      case UserRole.driver:
        return 'ドライバー';
      case UserRole.worker:
        return '接客対応者';
    }
  }

  // ロール別の色
  Color get color {
    switch (this) {
      case UserRole.systemAdmin:
        return Colors.red;
      case UserRole.admin:
        return Colors.purple;
      case UserRole.operator:
        return Colors.blue;
      case UserRole.driver:
        return Colors.orange;
      case UserRole.worker:
        return Colors.green;
    }
  }
}
