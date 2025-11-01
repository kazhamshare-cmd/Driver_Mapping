import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/user_role.dart';
import '../../../models/user_status.dart';
import '../../../models/app_user.dart';

/// スタッフ追加ダイアログ
class AddStaffDialog extends StatefulWidget {
  final String organizationId;

  const AddStaffDialog({
    super.key,
    required this.organizationId,
  });

  @override
  State<AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<AddStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _selectedRole = UserRole.worker;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _addStaff() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Firebase Authenticationにユーザーを作成
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Firestoreにユーザー情報を保存
      final appUser = AppUser(
        id: userCredential.user!.uid,
        organizationId: widget.organizationId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        role: _selectedRole,
        status: UserStatus.offline,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(appUser.toFirestore());

      // 組織のアクティブユーザー数を更新
      await _firestore.collection('organizations').doc(widget.organizationId).update({
        'activeUserCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_nameController.text.trim()} を追加しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'スタッフの追加に失敗しました';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'このメールアドレスは既に使用されています';
      } else if (e.code == 'weak-password') {
        errorMessage = 'パスワードは6文字以上にしてください';
      } else if (e.code == 'invalid-email') {
        errorMessage = '無効なメールアドレスです';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            title: const Text('スタッフ追加'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '名前',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '名前を入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'メールアドレスを入力してください';
                    }
                    if (!value.contains('@')) {
                      return '有効なメールアドレスを入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: '電話番号',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '電話番号を入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'パスワード',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                    helperText: '6文字以上',
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'パスワードを入力してください';
                    }
                    if (value.length < 6) {
                      return 'パスワードは6文字以上にしてください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<UserRole>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: '役職',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                  items: [
                    UserRole.admin,
                    UserRole.operator,
                    UserRole.driver,
                    UserRole.worker,
                  ].map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Row(
                        children: [
                          Icon(
                            _getRoleIcon(role),
                            size: 20,
                            color: role.color,
                          ),
                          const SizedBox(width: 8),
                          Text(role.displayName),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedRole = value);
                    }
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _addStaff,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '追加',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.systemAdmin:
        return Icons.shield;
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.operator:
        return Icons.support_agent;
      case UserRole.driver:
        return Icons.local_shipping;
      case UserRole.worker:
        return Icons.construction;
    }
  }
}
