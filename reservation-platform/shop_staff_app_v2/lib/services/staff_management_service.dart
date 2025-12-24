import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// スタッフ管理サービス
/// Cloud Functionsを使用してスタッフの作成・更新・削除を行う
class StaffManagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast1');

  /// スタッフを新規作成
  /// Cloud Functionを使用してFirebase Authユーザーを作成し、employeesドキュメントを追加
  Future<Map<String, dynamic>> createEmployee({
    required String shopId,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role, // 'staff' または 'manager'
    double hourlyWage = 1000,
    String? phone,
  }) async {
    try {
      final callable = _functions.httpsCallable('createEmployee');
      final result = await callable.call({
        'shopId': shopId,
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        'role': role,
        'hourlyWage': hourlyWage,
        'phone': phone,
      });

      return {
        'success': true,
        'uid': result.data['uid'],
        'message': 'スタッフを作成しました',
      };
    } on FirebaseFunctionsException catch (e) {
      debugPrint('createEmployee error: ${e.code} - ${e.message}');
      return {
        'success': false,
        'error': e.message ?? 'スタッフの作成に失敗しました',
      };
    } catch (e) {
      debugPrint('createEmployee error: $e');
      return {
        'success': false,
        'error': 'スタッフの作成に失敗しました: $e',
      };
    }
  }

  /// スタッフ情報を更新
  Future<Map<String, dynamic>> updateEmployee({
    required String employeeId,
    String? firstName,
    String? lastName,
    String? role,
    double? hourlyWage,
    String? phone,
    bool? isActive,
  }) async {
    try {
      final callable = _functions.httpsCallable('updateEmployee');
      final Map<String, dynamic> data = {
        'employeeId': employeeId,
      };

      if (firstName != null) data['firstName'] = firstName;
      if (lastName != null) data['lastName'] = lastName;
      if (role != null) data['role'] = role;
      if (hourlyWage != null) data['hourlyWage'] = hourlyWage;
      if (phone != null) data['phone'] = phone;
      if (isActive != null) data['isActive'] = isActive;

      await callable.call(data);

      return {
        'success': true,
        'message': 'スタッフ情報を更新しました',
      };
    } on FirebaseFunctionsException catch (e) {
      debugPrint('updateEmployee error: ${e.code} - ${e.message}');
      return {
        'success': false,
        'error': e.message ?? 'スタッフ情報の更新に失敗しました',
      };
    } catch (e) {
      debugPrint('updateEmployee error: $e');
      return {
        'success': false,
        'error': 'スタッフ情報の更新に失敗しました: $e',
      };
    }
  }

  /// スタッフのパスワードを変更
  Future<Map<String, dynamic>> changeEmployeePassword({
    required String employeeId,
    required String newPassword,
  }) async {
    try {
      final callable = _functions.httpsCallable('changeEmployeePassword');
      await callable.call({
        'employeeId': employeeId,
        'newPassword': newPassword,
      });

      return {
        'success': true,
        'message': 'パスワードを変更しました',
      };
    } on FirebaseFunctionsException catch (e) {
      debugPrint('changeEmployeePassword error: ${e.code} - ${e.message}');
      return {
        'success': false,
        'error': e.message ?? 'パスワードの変更に失敗しました',
      };
    } catch (e) {
      debugPrint('changeEmployeePassword error: $e');
      return {
        'success': false,
        'error': 'パスワードの変更に失敗しました: $e',
      };
    }
  }

  /// スタッフを無効化（論理削除）
  Future<Map<String, dynamic>> deactivateEmployee(String employeeId) async {
    try {
      await _firestore.collection('employees').doc(employeeId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'スタッフを無効化しました',
      };
    } catch (e) {
      debugPrint('deactivateEmployee error: $e');
      return {
        'success': false,
        'error': 'スタッフの無効化に失敗しました: $e',
      };
    }
  }

  /// スタッフを有効化
  Future<Map<String, dynamic>> activateEmployee(String employeeId) async {
    try {
      await _firestore.collection('employees').doc(employeeId).update({
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'スタッフを有効化しました',
      };
    } catch (e) {
      debugPrint('activateEmployee error: $e');
      return {
        'success': false,
        'error': 'スタッフの有効化に失敗しました: $e',
      };
    }
  }

  /// スタッフ一覧を取得（ストリーム）
  Stream<List<Map<String, dynamic>>> watchEmployees(String shopId) {
    return _firestore
        .collection('employees')
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// 特定のスタッフを取得
  Future<Map<String, dynamic>?> getEmployee(String employeeId) async {
    try {
      final doc =
          await _firestore.collection('employees').doc(employeeId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('getEmployee error: $e');
      return null;
    }
  }
}
