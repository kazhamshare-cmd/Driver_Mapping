import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'services/sound_service.dart';
import 'services/i18n_service.dart';
import 'services/auth_service.dart';
import 'services/ad_service.dart';
import 'screens/splash_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/game_screen.dart';
import 'screens/simple_lobby_screen.dart';
import 'models/game_settings.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Firebaseを同期的に初期化
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');

    // Firebase Realtime Databaseの最適化設定
    final database = FirebaseDatabase.instance;
    database.setPersistenceEnabled(true);
    database.setPersistenceCacheSizeBytes(20 * 1024 * 1024);
    print('✅ Firebase Realtime Database optimized');

    // サービスを同期的に初期化
    await _initializeServicesAsync();
  } catch (e) {
    print('❌ App initialization failed: $e');
  }

  runApp(const BellChallengeApp());
}


// 非同期でサービスを初期化
Future<void> _initializeServicesAsync() async {
  try {
    // 並列でサービスを初期化
    await Future.wait([
      AuthService().initialize(),
      AdService().initialize(),
      SoundService.initialize(),
    ]);
    print('✅ All services initialized');
  } catch (e) {
    print('❌ Services initialization failed: $e');
  }
}

class BellChallengeApp extends StatefulWidget {
  const BellChallengeApp({super.key});

  @override
  State<BellChallengeApp> createState() => _BellChallengeAppState();
}

class _BellChallengeAppState extends State<BellChallengeApp> with WidgetsBindingObserver {
  String _currentState = 'splash';
  GameSettings? _gameSettings;
  Locale _locale = const Locale('en');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('🔄 アプリライフサイクル変更: $state');

    switch (state) {
      case AppLifecycleState.paused:
        // アプリがバックグラウンドになった
        SoundService().onAppPaused();
        break;
      case AppLifecycleState.resumed:
        // アプリがフォアグラウンドに復帰した
        SoundService().onAppResumed();
        break;
      case AppLifecycleState.inactive:
        // アプリが非アクティブ状態（通知やコントロールセンターを開いた時など）
        SoundService().onAppInactive();
        break;
      case AppLifecycleState.hidden:
        // アプリが隠された状態
        SoundService().onAppPaused();
        break;
      case AppLifecycleState.detached:
        // アプリが切り離された状態（終了直前）
        break;
    }
  }

  Future<void> _initializeApp() async {
    print('🚀 Starting app initialization...');
    print('🚀 Current state: $_currentState');

    try {
      // Show splash for a brief moment, then go to settings
      print('🚀 Setting state to splash...');
      setState(() {
        _currentState = 'splash';
      });
      print('🚀 State set to: $_currentState');

      // Wait for splash screen to show briefly
      print('🚀 Waiting for 500ms...');
      await Future.delayed(const Duration(milliseconds: 500));
      print('🚀 Wait completed');

      // Move to settings screen
      print('🚀 Moving to settings screen...');
      setState(() {
        _locale = const Locale('ja', 'JP');
        _currentState = 'settings';
      });
      print('🚀 State set to: $_currentState');

      print('✅ Fast initialization completed');

      // Initialize services in background after UI is shown
      _initializeServicesInBackground();
    } catch (e, stackTrace) {
      print('❌ Error during initialization: $e');
      print('❌ Stack trace: $stackTrace');
      // Fallback to settings screen even if there's an error
      setState(() {
        _locale = const Locale('ja', 'JP');
        _currentState = 'settings';
      });
    }
  }

  Future<void> _initializeServicesInBackground() async {
    print('🔧 Starting background service initialization...');

    try {
      print('📱 Initializing I18n service...');
      await I18nService.initialize();
      print('✅ I18n service initialized');

      final locale = await I18nService.getCurrentLocale();
      setState(() {
        _locale = locale;
      });
    } catch (e, stackTrace) {
      print('❌ Error initializing I18n service: $e');
      print('Stack trace: $stackTrace');
    }

    try {
      print('🔊 Initializing Sound service...');
      await SoundService.initialize();
      print('✅ Sound service initialized');
    } catch (e, stackTrace) {
      print('❌ Error initializing Sound service: $e');
      print('Stack trace: $stackTrace');
    }

    print('✅ Background service initialization completed');
  }

  void _onStartGame(GameSettings settings) {
    setState(() {
      _gameSettings = settings;
      _currentState = 'game';
    });
  }

  void _onBackToSettings() {
    setState(() {
      _currentState = 'settings';
    });
  }

  void _onStartOnlineGame(GameSettings settings) {
    setState(() {
      _gameSettings = settings;
      _currentState = 'online';
    });
  }

  void _onLanguageChanged(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  Widget _buildCurrentScreen() {
    switch (_currentState) {
      case 'splash':
        return const SplashScreen();
      case 'settings':
        return SettingsScreen(
          onStartGame: _onStartGame,
          onLanguageChanged: _onLanguageChanged,
          onStartOnlineGame: _onStartOnlineGame,
          onStartSimpleOnlineGame: () {
            setState(() {
              _currentState = 'online';
            });
          },
        );
      case 'game':
        return GameScreen(
          gameSettings: _gameSettings!,
          onBackToSettings: _onBackToSettings,
        );
      case 'online':
        return SimpleLobbyScreen(
          onBackToMenu: _onBackToSettings,
        );
      default:
        return const SplashScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bell Challenge Game',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF1a1a2e),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
        ),
      ),
      locale: _locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: I18nService.supportedLocales,
      home: _buildCurrentScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
