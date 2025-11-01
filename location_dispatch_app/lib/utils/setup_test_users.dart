import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_role.dart';
import '../models/user_status.dart';
import '../models/app_user.dart';

/// テストユーザーのセットアップ
/// 開発環境でのみ実行し、テストアカウントを自動作成します
class SetupTestUsers {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String defaultOrganizationId = 'test-org-001';

  static final List<Map<String, dynamic>> testUsers = [
    {
      'email': 'sysadmin@example.com',
      'password': 'sysadmin123',
      'name': 'システム管理者テスト',
      'phone': '090-0000-0000',
      'role': UserRole.systemAdmin,
      'organizationId': '', // システム管理者は組織に属さない
    },
    {
      'email': 'admin@example.com',
      'password': 'admin123',
      'name': '組織管理者テスト',
      'phone': '090-0000-0001',
      'role': UserRole.admin,
    },
    {
      'email': 'operator@example.com',
      'password': 'operator123',
      'name': 'オペレーターテスト',
      'phone': '090-0000-0002',
      'role': UserRole.operator,
    },
    {
      'email': 'driver@example.com',
      'password': 'driver123',
      'name': 'ドライバーテスト',
      'phone': '090-0000-0003',
      'role': UserRole.driver,
    },
    {
      'email': 'worker@example.com',
      'password': 'worker123',
      'name': '作業者テスト',
      'phone': '090-0000-0004',
      'role': UserRole.worker,
    },
  ];

  /// すべてのテストユーザーをセットアップ
  static Future<void> setupAllTestUsers() async {
    print('テストユーザーのセットアップを開始します...');

    for (final userData in testUsers) {
      try {
        await _createTestUser(userData);
        print('✓ ${userData['name']} (${userData['email']}) を作成しました');
      } catch (e) {
        if (e.toString().contains('email-already-in-use')) {
          print('- ${userData['name']} (${userData['email']}) は既に存在します');
        } else {
          print('✗ ${userData['name']} の作成に失敗: $e');
        }
      }
    }

    print('テストユーザーのセットアップが完了しました');
  }

  /// 個別のテストユーザーを作成
  static Future<void> _createTestUser(Map<String, dynamic> userData) async {
    // Firebase Authenticationにユーザーを作成
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: userData['email'] as String,
      password: userData['password'] as String,
    );

    // 組織IDを取得（systemAdminの場合は空文字、それ以外はデフォルト組織）
    final organizationId = userData['organizationId'] as String? ?? defaultOrganizationId;

    // Firestoreにユーザー情報を保存
    final appUser = AppUser(
      id: userCredential.user!.uid,
      organizationId: organizationId,
      name: userData['name'] as String,
      phone: userData['phone'] as String,
      role: userData['role'] as UserRole,
      status: UserStatus.offline,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestore
        .collection('users')
        .doc(userCredential.user!.uid)
        .set(appUser.toFirestore());
  }

  /// テスト組織を作成
  static Future<void> setupTestOrganization() async {
    try {
      final orgRef = _firestore.collection('organizations').doc(defaultOrganizationId);
      final orgDoc = await orgRef.get();

      if (!orgDoc.exists) {
        await orgRef.set({
          'name': 'テスト組織',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✓ テスト組織を作成しました');
      } else {
        print('- テスト組織は既に存在します');
      }
    } catch (e) {
      print('✗ テスト組織の作成に失敗: $e');
    }
  }

  /// 全セットアップを実行（組織 + ユーザー）
  static Future<void> setupAll() async {
    await setupTestOrganization();
    await setupAllTestUsers();
  }
}
