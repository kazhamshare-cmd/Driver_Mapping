import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/user_role.dart';
import '../../utils/setup_test_users.dart';

// テストユーザーの認証情報
class TestAccount {
  final String email;
  final String password;
  final UserRole role;

  const TestAccount({
    required this.email,
    required this.password,
    required this.role,
  });
}

const List<TestAccount> testAccounts = [
  TestAccount(
    email: 'sysadmin@example.com',
    password: 'sysadmin123',
    role: UserRole.systemAdmin,
  ),
  TestAccount(
    email: 'admin@example.com',
    password: 'admin123',
    role: UserRole.admin,
  ),
  TestAccount(
    email: 'operator@example.com',
    password: 'operator123',
    role: UserRole.operator,
  ),
  TestAccount(
    email: 'driver@example.com',
    password: 'driver123',
    role: UserRole.driver,
  ),
  TestAccount(
    email: 'worker@example.com',
    password: 'worker123',
    role: UserRole.worker,
  ),
];

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isSettingUp = false;
  String? _errorMessage;
  String? _setupMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'ログインに失敗しました: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _quickLogin(TestAccount account) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _setupMessage = null;
    });

    try {
      await _authService.signInWithEmailAndPassword(
        email: account.email,
        password: account.password,
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'ログインに失敗しました: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _setupTestUsers() async {
    setState(() {
      _isSettingUp = true;
      _errorMessage = null;
      _setupMessage = null;
    });

    try {
      await SetupTestUsers.setupAll();
      if (mounted) {
        setState(() {
          _setupMessage = 'テストユーザーのセットアップが完了しました！';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'セットアップに失敗しました: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSettingUp = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Location Dispatch',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '位置情報手配システム',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'メールアドレス',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
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
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'パスワード',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'パスワードを入力してください';
                      }
                      if (value.length < 6) {
                        return 'パスワードは6文字以上である必要があります';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),
                  if (_errorMessage != null) const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('ログイン', style: TextStyle(fontSize: 16)),
                  ),
                  // デバッグモードまたはプロファイルモードの時のみ表示
                  if (kDebugMode || kProfileMode) ...[
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'クイックログイン（開発用）',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '初回はセットアップボタンを押してください',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (_setupMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _setupMessage!,
                          style: TextStyle(color: Colors.green.shade900),
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: _isSettingUp || _isLoading ? null : _setupTestUsers,
                      icon: _isSettingUp
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.settings),
                      label: const Text('テストユーザーをセットアップ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...testAccounts.map((account) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildQuickLoginButton(account),
                        )),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickLoginButton(TestAccount account) {
    return OutlinedButton(
      onPressed: _isLoading ? null : () => _quickLogin(account),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        side: BorderSide(color: account.role.color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getRoleIcon(account.role),
                color: account.role.color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                account.role.displayName,
                style: TextStyle(
                  color: account.role.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ID: ${account.email}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            'PW: ${account.password}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
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
