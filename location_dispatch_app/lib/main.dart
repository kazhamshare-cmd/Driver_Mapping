import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'routes/app_routes.dart';
import 'screens/auth/login_screen.dart';
import 'screens/system_admin/system_admin_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/operator/operator_home_screen_simple.dart';
import 'screens/driver/driver_home_screen.dart';
import 'screens/worker/worker_home_screen_simple.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'models/user_role.dart';

// バックグラウンドメッセージハンドラー（トップレベル関数）
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('バックグラウンドメッセージ: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 日付フォーマットのロケール初期化
  await initializeDateFormatting('ja_JP');

  // Firebaseの初期化
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // バックグラウンドメッセージハンドラー登録
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('MyApp build()が呼ばれました');
    return MaterialApp(
      title: 'Location Dispatch App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        brightness: Brightness.light,
      ),
      // homeを使う場合はinitialRouteを削除
      // initialRoute: AppRoutes.initialRoute,
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print('AuthWrapper build()が呼ばれました');
    final authService = AuthService();

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        print('AuthWrapper StreamBuilder - connectionState: ${snapshot.connectionState}, hasData: ${snapshot.hasData}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          print('認証状態を確認中...');
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          print('ユーザーは認証済み、ユーザーデータを取得中...');
          return FutureBuilder(
            future: authService.getCurrentUserData(),
            builder: (context, userSnapshot) {
              print('FutureBuilder - connectionState: ${userSnapshot.connectionState}, hasData: ${userSnapshot.hasData}');

              if (userSnapshot.connectionState == ConnectionState.waiting) {
                print('ユーザーデータを読み込み中...');
                return const Scaffold(
                  backgroundColor: Colors.white,
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (userSnapshot.hasData) {
                final user = userSnapshot.data!;
                print('ユーザーログイン成功: ${user.name} (${user.role.displayName})');
                print('AdminHomeScreenを返します');

                // FCM通知を初期化
                _initializeNotifications(user.id);

                // activeRoleに基づいて画面を切り替え
                switch (user.activeRole) {
                  case UserRole.systemAdmin:
                    print('システム管理者画面に遷移');
                    return const SystemAdminHomeScreen();
                  case UserRole.admin:
                    print('組織管理者画面に遷移');
                    return const AdminHomeScreen();
                  case UserRole.operator:
                    print('オペレーター画面に遷移');
                    return const OperatorHomeScreen();
                  case UserRole.driver:
                    print('ドライバー画面に遷移');
                    return const DriverHomeScreen();
                  case UserRole.worker:
                    print('接客対応者画面に遷移');
                    return const WorkerHomeScreen();
                }
              }

              if (userSnapshot.hasError) {
                print('ユーザーデータ取得エラー: ${userSnapshot.error}');
              } else {
                print('ユーザーデータが見つかりません');
              }

              print('ログイン画面を返します');
              return const LoginScreen();
            },
          );
        }

        print('未認証のためログイン画面を返します');
        return const LoginScreen();
      },
    );
  }

  /// FCM通知の初期化
  Future<void> _initializeNotifications(String userId) async {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize(userId);
    } catch (e) {
      print('FCM初期化エラー: $e');
    }
  }
}
