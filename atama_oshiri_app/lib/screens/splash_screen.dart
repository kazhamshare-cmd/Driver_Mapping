import 'package:flutter/material.dart';
import 'dart:async';
import 'package:package_info_plus/package_info_plus.dart';
import 'menu_screen.dart';

/// スプラッシュ画面 - 起動時に「株式会社ビーク」を表示
class SplashScreen extends StatefulWidget {
  final Future<void> Function() onInitialize;

  const SplashScreen({
    super.key,
    required this.onInitialize,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _isInitialized = false;
  bool _animationComplete = false;
  double _loadingProgress = 0.0;
  String _loadingStatus = '初期化中...';
  String _appVersion = '';

  @override
  void initState() {
    super.initState();

    // フェードインアニメーションの設定
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // アニメーション開始
    _controller.forward();

    // アプリバージョンを取得
    _getAppVersion();

    // 初期化処理とナビゲーションを実行
    _initializeAndNavigate();
  }

  Future<void> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = 'v${packageInfo.version}';
      });
    } catch (e) {
      print('⚠️ バージョン取得エラー: $e');
      setState(() {
        _appVersion = 'v1.0.0';
      });
    }
  }

  Future<void> _initializeAndNavigate() async {
    try {
      // 初期化を開始
      print('🚀 スプラッシュ: 初期化開始');
      
      // 進捗を段階的に更新
      _updateProgress(0.1, 'Firebase初期化中...');
      await Future.delayed(const Duration(milliseconds: 200));
      
      _updateProgress(0.2, '認証サービス初期化中...');
      await Future.delayed(const Duration(milliseconds: 200));
      
      _updateProgress(0.3, '音声認識サービス初期化中...');
      await Future.delayed(const Duration(milliseconds: 200));
      
      _updateProgress(0.4, '辞書データベース読み込み中...');
      await Future.delayed(const Duration(milliseconds: 300));

      // 初期化とアニメーション時間を並行実行
      final results = await Future.wait([
        widget.onInitialize().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('⏰ 初期化タイムアウト');
          },
        ),
        Future.delayed(const Duration(milliseconds: 2500)), // 最低2.5秒表示
      ], eagerError: true).catchError((e) {
        print('⚠️ 初期化エラー: $e');
        return [null, null];
      });

      _updateProgress(1.0, '初期化完了');
      print('✅ スプラッシュ: 初期化完了');

      if (!mounted) {
        print('⚠️ ウィジェットがアンマウントされています');
        return;
      }

      setState(() {
        _isInitialized = true;
      });

      // フェードアウトを開始（バックグラウンドで実行、待たない）
      print('🎭 スプラッシュ: フェードアウト開始');
      _controller.reverse().catchError((e) {
        print('⚠️ アニメーションエラー（無視）: $e');
      });

      // フェードアウト時間だけ待つ（アニメーション完了を待たない）
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) {
        print('⚠️ ウィジェットがアンマウントされています（遷移前）');
        return;
      }

      setState(() {
        _animationComplete = true;
      });

      print('🚪 スプラッシュ: メニュー画面へ遷移');

      // 必ず遷移する
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MenuScreen()),
      );

      print('✅ スプラッシュ: 遷移完了');
    } catch (e, stackTrace) {
      print('❌ スプラッシュエラー: $e');
      print('スタックトレース: $stackTrace');
      // エラーが発生してもメニュー画面に遷移
      if (mounted) {
        print('🚨 エラーリカバリー: メニュー画面へ強制遷移');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MenuScreen()),
        );
      }
    }
  }

  void _updateProgress(double progress, String status) {
    if (mounted) {
      setState(() {
        _loadingProgress = progress;
        _loadingStatus = status;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 会社名
                Text(
                  '株式会社ビーク',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade700,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 40),
                
                // 読み込み進捗バー
                Container(
                  width: 280,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // 読み込みステータス
                      Text(
                        _loadingStatus,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // プログレスバー
                      LinearProgressIndicator(
                        value: _loadingProgress,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.deepPurple.shade400,
                        ),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 12),
                      
                      // 進捗パーセンテージ
                      Text(
                        '${(_loadingProgress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // アプリバージョン
                if (_appVersion.isNotEmpty)
                  Text(
                    _appVersion,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
