import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final t = ref.read(translationProvider);

    try {
      await ref.read(loginProvider).signIn(
            _emailController.text.trim(),
            _passwordController.text,
          );
      // ログイン成功後は自動的にホーム画面に遷移（GoRouterで制御）
    } catch (e) {
      if (!mounted) return;

      String errorMessage = t.text('loginFailed');
      if (e.toString().contains('user-not-found')) {
        errorMessage = t.text('userNotFound');
      } else if (e.toString().contains('wrong-password')) {
        errorMessage = t.text('wrongPassword');
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = t.text('invalidEmail');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final t = ref.read(translationProvider);
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.text('enterEmail')),
        ),
      );
      return;
    }

    try {
      await ref.read(loginProvider).sendPasswordResetEmail(email);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.text('passwordResetSent')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t.text('error')}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final formMaxWidth = isTablet ? 400.0 : double.infinity;
    final iconSize = isTablet ? 100.0 : 80.0;
    final titleFontSize = isTablet ? 28.0 : 24.0;
    final padding = isTablet ? 32.0 : 24.0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: formMaxWidth),
              child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ロゴ・タイトル
                  Icon(
                    Icons.restaurant,
                    size: iconSize,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.text('staffLogin'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // メールアドレス入力
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: t.text('email'),
                      prefixIcon: const Icon(Icons.email),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return t.text('enterEmail');
                      }
                      if (!value.contains('@')) {
                        return t.text('enterValidEmail');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // パスワード入力
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: t.text('password'),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return t.text('enterPassword');
                      }
                      if (value.length < 6) {
                        return t.text('passwordMinLength');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // パスワードを忘れた
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _handleForgotPassword,
                      child: Text(t.text('forgotPassword')),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ログインボタン
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            t.text('loginButton'),
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}
