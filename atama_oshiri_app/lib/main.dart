import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/menu_screen.dart';
import 'services/sound_service.dart';
import 'services/speech_service.dart';
import 'services/firebase_auth_service.dart';
import 'models/dictionary_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  double _progress = 0.0;
  String _message = '初期化中...';

  Future<void> _initializeApp() async {
    try {
      // Firebase初期化
      _updateProgress(0.1, 'Firebaseを初期化中...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase初期化完了');

      // サービスの初期化
      _updateProgress(0.25, '認証サービスを初期化中...');
      await FirebaseAuthService.instance.initialize();

      _updateProgress(0.5, 'サウンドサービスを初期化中...');
      await SoundService.instance.initialize();

      _updateProgress(0.75, '音声認識を初期化中...');
      await SpeechService.instance.initialize();

      _updateProgress(0.9, '辞書データを読み込み中...');
      await DictionaryModel.instance.loadDictionary();

      _updateProgress(1.0, '完了！');
      print('✅ 全サービスの初期化完了');
    } catch (e) {
      print('❌ 初期化エラー: $e');
      _updateProgress(1.0, 'エラーが発生しました');
      // エラーでも続行
    }
  }

  void _updateProgress(double progress, String message) {
    if (mounted) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _message = message;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '頭お尻ゲーム',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        fontFamily: 'NotoSansJP',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 16),
          bodyMedium: TextStyle(fontSize: 14),
        ),
      ),
      home: SplashScreen(
        onInitialize: _initializeApp,
        progress: _progress,
        message: _message,
      ),
    );
  }
}
