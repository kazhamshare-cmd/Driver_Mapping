import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/menu_screen.dart';
import 'services/sound_service.dart';
import 'services/speech_service.dart';
import 'services/game_center_service.dart';
import 'services/firebase_auth_service.dart';
import 'models/dictionary_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<void> _initializeApp() async {
    try {
      // Firebase初期化
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase初期化完了');

      // サービスの初期化
      await FirebaseAuthService.instance.initialize(); // Firebase認証（匿名ログイン）
      await SoundService.instance.initialize();
      await SpeechService.instance.initialize();
      await DictionaryModel.instance.loadDictionary();
      await GameCenterService.instance.initialize();

      print('✅ 全サービスの初期化完了');
    } catch (e) {
      print('❌ 初期化エラー: $e');
      // エラーでも続行
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
      ),
    );
  }
}
