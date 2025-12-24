import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/order_provider.dart';
import 'models/order.dart';
import 'services/fcm_service.dart';
import 'services/notification_service.dart';
import 'screens/login/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/clock_in/clock_in_screen.dart';
import 'screens/notification_settings/notification_settings_screen.dart';
import 'screens/orders/orders_screen.dart';
import 'screens/settings/printer_list_screen.dart';
import 'screens/settings/language_screen.dart';
import 'screens/proxy_order/table_selection_screen.dart';
import 'screens/proxy_order/proxy_order_menu_screen.dart';
import 'screens/register/register_screen.dart';
import 'screens/table_management/table_management_screen.dart';
import 'screens/shifts/my_shifts_screen.dart';
import 'screens/shifts/shift_requests_screen.dart';
import 'screens/bulletin/bulletin_board_screen.dart';
import 'screens/bulletin/bulletin_detail_screen.dart';
import 'screens/bulletin/bulletin_new_screen.dart';
import 'screens/bulletin/bulletin_edit_screen.dart';
import 'screens/reservations/reservations_screen.dart';
import 'screens/products/products_screen.dart';
import 'screens/sessions/active_sessions_screen.dart';
import 'screens/sessions/session_detail_screen.dart';
import 'screens/staff_management/staff_management_screen.dart';
import 'screens/shift_management/shift_management_screen.dart';
import 'screens/attendance_management/attendance_management_screen.dart';
import 'screens/orders/cancelled_orders_screen.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/customers/customers_screen.dart';
import 'screens/shop_settings/shop_settings_screen.dart';
import 'screens/void_requests/void_requests_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase初期化（既に初期化済みの場合はスキップ）
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase already initialized: $e');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // アプリ起動時にFCM初期化
    FcmService().initialize();
    // 通知サービス初期化（通知音設定の読み込み）
    NotificationService().initialize();
  }

  @override
  Widget build(BuildContext context) {
    return const AppRouter();
  }
}

class AppRouter extends ConsumerWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('🔍 AppRouter.build() 開始');
    final authState = ref.watch(authStateProvider);
    debugPrint('🔍 authState: $authState');
    final locale = ref.watch(localeProvider);
    debugPrint('🔍 locale: $locale');

    // ▼▼▼ グローバルな注文監視（どこにいても印刷処理） ▼▼▼
    if (authState.asData?.value != null) {
      ref.listen<AsyncValue<List<OrderModel>>>(activeOrdersProvider, (previous, next) {
        next.whenData((newOrders) async {
          if (previous == null || previous.isLoading || previous.hasError) return;

          final oldOrders = previous.value ?? [];
          final oldIds = oldOrders.map((o) => o.id).toSet();

          // 新規かつ未処理の注文を抽出
          final brandNewOrders = newOrders.where((order) => 
            order.status == OrderStatus.pending && !oldIds.contains(order.id)
          ).toList();

          if (brandNewOrders.isNotEmpty) {
            debugPrint('🚀 グローバル検知: ${brandNewOrders.length}件の新規注文');

            // 通知音を鳴らす
            try {
              final notificationService = NotificationService();
              await notificationService.notifyNewOrder();
              debugPrint('🔊 通知音再生完了');
            } catch (e) {
              debugPrint('❌ 通知音エラー: $e');
            }

            // 注意: 自動印刷はOrdersScreenで実施（isPrintedチェック＋印刷済みフラグ更新あり）
            // ここでは印刷しない（二重印刷防止）
            debugPrint('📋 OrdersScreenで自動印刷を実行します（${brandNewOrders.length}件）');
          }
        });
      });
    }
    // ▲▲▲ 監視終了 ▲▲▲

    return authState.when(
      data: (user) {
        // ★修正: ここにあった FcmService().subscribeToShop(user.shopId); を削除しました。
        // (user型にはshopIdがないため。購読処理はHomeScreenで行われます)

        return MaterialApp.router(
          title: 'Shop Staff App',
          locale: locale,
          supportedLocales: const [
            Locale('ja'),
            Locale('en'),
            Locale('th'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
            useMaterial3: true,
            fontFamily: locale.languageCode == 'th' ? null : null,
          ),
          routerConfig: _createRouter(user),
          debugShowCheckedModeBanner: false,
        );
      },
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, stack) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('認証エラー: $error'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  GoRouter _createRouter(user) {
    return GoRouter(
      initialLocation: user != null ? '/home' : '/login',
      redirect: (context, state) {
        final isLoggedIn = user != null;
        final isLoggingIn = state.matchedLocation == '/login';
        if (!isLoggedIn && !isLoggingIn) return '/login';
        if (isLoggedIn && isLoggingIn) return '/home';
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          redirect: (context, state) => '/home',
        ),
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(path: '/clock-in', builder: (context, state) => const ClockInScreen()),
        GoRoute(path: '/notification-settings', builder: (context, state) => const NotificationSettingsScreen()),
        GoRoute(
          path: '/orders',
          builder: (context, state) {
            final newOrderId = state.uri.queryParameters['newOrderId'];
            return OrdersScreen(newOrderId: newOrderId);
          },
        ),
        GoRoute(path: '/printer-settings', builder: (context, state) => const PrinterListScreen()),
        GoRoute(path: '/language-settings', builder: (context, state) => const LanguageScreen()),
        GoRoute(path: '/proxy-order', builder: (context, state) => const TableSelectionScreen()),
        GoRoute(
          path: '/proxy-order/menu',
          builder: (context, state) {
            final tableId = state.uri.queryParameters['tableId'];
            return ProxyOrderMenuScreen(tableId: tableId!);
          },
        ),
        GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
        GoRoute(path: '/table-management', builder: (context, state) => const TableManagementScreen()),
        GoRoute(path: '/my-shifts', builder: (context, state) => const MyShiftsScreen()),
        GoRoute(path: '/shift-requests', builder: (context, state) => const ShiftRequestsScreen()),
        GoRoute(path: '/bulletin', builder: (context, state) => const BulletinBoardScreen()),
        GoRoute(path: '/bulletin/new', builder: (context, state) => const BulletinNewScreen()),
        GoRoute(
          path: '/bulletin/:postId',
          builder: (context, state) {
            final postId = state.pathParameters['postId']!;
            return BulletinDetailScreen(postId: postId);
          },
        ),
        GoRoute(path: '/reservations', builder: (context, state) => const ReservationsScreen()),
        GoRoute(
          path: '/bulletin/:postId/edit',
          builder: (context, state) {
            final postId = state.pathParameters['postId']!;
            return BulletinEditScreen(postId: postId);
          },
        ),
        GoRoute(path: '/products', builder: (context, state) => const ProductsScreen()),
        GoRoute(path: '/active-sessions', builder: (context, state) => const ActiveSessionsScreen()),
        GoRoute(
          path: '/session/:sessionId',
          builder: (context, state) {
            final sessionId = state.pathParameters['sessionId']!;
            return SessionDetailScreen(sessionId: sessionId);
          },
        ),
        // ============ 管理モード用ルート ============
        GoRoute(path: '/staff-management', builder: (context, state) => const StaffManagementScreen()),
        GoRoute(path: '/shift-management', builder: (context, state) => const ShiftManagementScreen()),
        GoRoute(path: '/attendance-management', builder: (context, state) => const AttendanceManagementScreen()),
        GoRoute(path: '/cancelled-orders', builder: (context, state) => const CancelledOrdersScreen()),
        GoRoute(path: '/analytics', builder: (context, state) => const AnalyticsScreen()),
        GoRoute(path: '/customers', builder: (context, state) => const CustomersScreen()),
        GoRoute(path: '/shop-settings', builder: (context, state) => const ShopSettingsScreen()),
        GoRoute(path: '/void-requests', builder: (context, state) => const VoidRequestsScreen()),
        GoRoute(path: '/blacklist', builder: (context, state) => const _PlaceholderScreen(title: 'ブラックリスト')),
      ],
    );
  }
}

// 開発中の機能用プレースホルダー画面
class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              '現在開発中です',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '今後のアップデートをお待ちください',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('戻る'),
            ),
          ],
        ),
      ),
    );
  }
}