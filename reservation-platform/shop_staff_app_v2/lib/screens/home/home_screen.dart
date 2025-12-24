import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/table_call_provider.dart';
import '../../services/fcm_service.dart';
import '../../widgets/table_call_notification_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _setupFcm();
  }

  Future<void> _setupFcm() async {
    final fcmService = FcmService();
    await fcmService.initialize();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final user = ref.read(staffUserProvider).value;
      if (user != null) {
        await fcmService.saveTokenToEmployee(user.id);

        if (!mounted) return;

        if (user.isWorking) {
          fcmService.subscribeToShop(user.shopId);
          debugPrint('✅ 出勤中のためFCM購読: shop_${user.shopId}');
        } else {
          fcmService.unsubscribeFromShop(user.shopId);
          debugPrint('ℹ️ 未出勤のためFCM購読解除: shop_${user.shopId}');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final staffUserAsync = ref.watch(staffUserProvider);
    final shopAsync = ref.watch(shopProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider).value ?? 0;
    final pendingCallCount = ref.watch(pendingTableCallCountProvider);
    final activeCalls = ref.watch(activeTableCallsProvider).value ?? [];
    final totalBadgeCount = unreadCount + activeCalls.length;
    final t = ref.watch(translationProvider);
    final appMode = ref.watch(appModeProvider);
    final canAccessManagement = ref.watch(canAccessManagementModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(appMode == AppMode.operation
            ? t.text('operationMode')
            : t.text('managementMode')),
        backgroundColor: appMode == AppMode.operation
            ? Colors.orange.shade700
            : Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          // テーブル呼び出し通知アイコン
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  pendingCallCount > 0
                      ? Icons.notifications_active
                      : Icons.notifications_outlined,
                  color: pendingCallCount > 0 ? Colors.yellow : Colors.white,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const TableCallNotificationDialog(),
                  );
                },
              ),
              if (totalBadgeCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      totalBadgeCount > 99 ? '99+' : totalBadgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () {
              context.go('/language-settings');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final fcmService = FcmService();
              final user = staffUserAsync.value;
              if (user != null) {
                await fcmService.unsubscribeFromShop(user.shopId);
              }
              await ref.read(loginProvider).signOut();
            },
          ),
        ],
      ),
      body: staffUserAsync.when(
        data: (staffUser) {
          if (staffUser == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(t.text('userInfoNotFound')),
                  const SizedBox(height: 8),
                  Text(
                    t.text('notRegisteredAsStaff'),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      await ref.read(loginProvider).signOut();
                    },
                    child: Text(t.text('logout')),
                  ),
                ],
              ),
            );
          }

          return shopAsync.when(
            data: (shop) {
              if (shop == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.store_mall_directory_outlined,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(t.text('shopInfoNotFound')),
                      const SizedBox(height: 8),
                      Text(
                        'Shop ID: ${staffUser.shopId}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.invalidate(shopProvider);
                        },
                        child: Text(t.text('retry')),
                      ),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ユーザー情報カード
                    _buildUserInfoCard(context, staffUser, shop, t),
                    const SizedBox(height: 16),

                    // モード切り替え（オーナー・店長のみ）
                    if (canAccessManagement)
                      _buildModeToggle(context, appMode, t),

                    const SizedBox(height: 24),

                    // モードに応じたメニュー表示
                    Text(
                      appMode == AppMode.operation
                          ? t.text('operationFeatures')
                          : t.text('managementFeatures'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),

                    // メニューグリッド
                    _buildMenuGrid(context, staffUser, shop, appMode, t),
                  ],
                ),
              );
            },
            loading: () {
              return const Center(child: CircularProgressIndicator());
            },
            error: (error, stack) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('${t.text('error')}: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(shopProvider);
                      },
                      child: Text(t.text('retry')),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('${t.text('error')}: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(staffUserProvider);
                },
                child: Text(t.text('retry')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(BuildContext context, staffUser, shop, t) {
    final roleDisplayName = ref.watch(roleDisplayNameProvider);

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${shop.shopName}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        staffUser.name,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getRoleColor(staffUser.role),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          roleDisplayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 出勤状態バッジ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: staffUser.isWorking ? Colors.green : Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    staffUser.isWorking ? Icons.check_circle : Icons.circle_outlined,
                    size: 16,
                    color: staffUser.isWorking ? Colors.white : Colors.grey[700],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    staffUser.isWorking
                        ? t.text('clockedIn')
                        : t.text('clockedOut'),
                    style: TextStyle(
                      color: staffUser.isWorking ? Colors.white : Colors.grey[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'owner':
        return Colors.purple;
      case 'manager':
        return Colors.blue;
      case 'staff':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Widget _buildModeToggle(BuildContext context, AppMode currentMode, t) {
    return Card(
      elevation: 2,
      color: currentMode == AppMode.management
          ? Colors.blue.shade50
          : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  ref.read(appModeProvider.notifier).state = AppMode.operation;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: currentMode == AppMode.operation
                        ? Colors.orange
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: currentMode == AppMode.operation
                        ? [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.storefront,
                        color: currentMode == AppMode.operation
                            ? Colors.white
                            : Colors.grey[600],
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t.text('operationMode'),
                        style: TextStyle(
                          color: currentMode == AppMode.operation
                              ? Colors.white
                              : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  ref.read(appModeProvider.notifier).state = AppMode.management;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: currentMode == AppMode.management
                        ? Colors.blue
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: currentMode == AppMode.management
                        ? [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.settings,
                        color: currentMode == AppMode.management
                            ? Colors.white
                            : Colors.grey[600],
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t.text('managementMode'),
                        style: TextStyle(
                          color: currentMode == AppMode.management
                              ? Colors.white
                              : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuGrid(
      BuildContext context, staffUser, shop, AppMode appMode, t) {
    final isOwner = ref.watch(isOwnerProvider);
    final isManager = ref.watch(isManagerProvider);
    final screenWidth = MediaQuery.of(context).size.width;

    int crossAxisCount;
    double childAspectRatio;
    bool isTablet = screenWidth > 600;

    if (screenWidth > 900) {
      crossAxisCount = 4;
      childAspectRatio = 1.1;
    } else if (screenWidth > 600) {
      crossAxisCount = 3;
      childAspectRatio = 1.0;
    } else {
      crossAxisCount = 2;
      childAspectRatio = 1.0;
    }

    final List<Widget> menuItems = appMode == AppMode.operation
        ? _buildOperationMenuItems(context, staffUser, shop, isTablet, t)
        : _buildManagementMenuItems(
            context, staffUser, shop, isOwner, isManager, isTablet, t);

    return GridView.count(
      crossAxisCount: crossAxisCount,
      childAspectRatio: childAspectRatio,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: isTablet ? 20 : 16,
      crossAxisSpacing: isTablet ? 20 : 16,
      children: menuItems,
    );
  }

  // ============ 営業中モードメニュー ============
  List<Widget> _buildOperationMenuItems(
      BuildContext context, staffUser, shop, bool isTablet, t) {
    final canDeleteOrders = ref.watch(canDeleteOrdersProvider);

    return [
      // 1. 代理注文
      _buildMenuCard(
        context,
        icon: Icons.add_shopping_cart,
        title: t.text('proxyOrder'),
        subtitle: t.text('proxyOrderDesc'),
        color: Colors.orange,
        isTablet: isTablet,
        onTap: () {
          if (!staffUser.isWorking) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(t.text('clockInRequired')),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          context.go('/proxy-order');
        },
      ),
      // 2. レジ・会計
      _buildMenuCard(
        context,
        icon: Icons.point_of_sale,
        title: t.text('register'),
        subtitle: t.text('registerDesc'),
        color: Colors.green,
        isTablet: isTablet,
        onTap: () {
          context.go('/register');
        },
      ),
      // 3. 注文管理
      _buildMenuCard(
        context,
        icon: Icons.receipt_long,
        title: t.text('orders'),
        subtitle: t.text('ordersDesc'),
        color: Colors.blue,
        isTablet: isTablet,
        badge: canDeleteOrders ? 'オーナー権限' : null,
        onTap: () {
          context.go('/orders');
        },
      ),
      // 4. テーブル/座席管理
      _buildMenuCard(
        context,
        icon: shop.mobileOrderEnabled ? Icons.table_bar : Icons.event_seat,
        title: shop.mobileOrderEnabled
            ? t.text('tableManagement')
            : t.text('seatManagement'),
        subtitle: shop.mobileOrderEnabled
            ? t.text('tableManagementDesc')
            : t.text('seatManagementDesc'),
        color: Colors.purple,
        isTablet: isTablet,
        onTap: () {
          context.go('/table-management');
        },
      ),
      // 5. 出退勤
      _buildMenuCard(
        context,
        icon: staffUser.isWorking ? Icons.logout : Icons.login,
        title: t.text('clockIn'),
        subtitle: staffUser.isWorking
            ? t.text('clockOutButton')
            : t.text('clockInButton'),
        color: staffUser.isWorking ? Colors.red : Colors.teal,
        isTablet: isTablet,
        onTap: () {
          context.go('/clock-in');
        },
      ),
      // 6. 予約管理
      _buildMenuCard(
        context,
        icon: Icons.calendar_today,
        title: t.text('reservations'),
        subtitle: t.text('reservationsDesc'),
        color: Colors.indigo,
        isTablet: isTablet,
        onTap: () {
          context.go('/reservations');
        },
      ),
      // 7. マイシフト
      _buildMenuCard(
        context,
        icon: Icons.calendar_month,
        title: t.text('myShifts'),
        subtitle: t.text('myShiftsDesc'),
        isTablet: isTablet,
        onTap: () {
          context.go('/my-shifts');
        },
      ),
      // 8. 掲示板
      _buildMenuCard(
        context,
        icon: Icons.message,
        title: t.text('bulletin'),
        subtitle: t.text('bulletinDesc'),
        color: Colors.teal,
        isTablet: isTablet,
        onTap: () {
          context.go('/bulletin');
        },
      ),
    ];
  }

  // ============ 管理モードメニュー ============
  List<Widget> _buildManagementMenuItems(BuildContext context, staffUser, shop,
      bool isOwner, bool isManager, bool isTablet, t) {
    final List<Widget> items = [];

    // オーナー専用: スタッフ管理
    if (isOwner) {
      items.add(
        _buildMenuCard(
          context,
          icon: Icons.people,
          title: t.text('staffManagement'),
          subtitle: t.text('staffManagementDesc'),
          color: Colors.purple,
          isTablet: isTablet,
          badge: 'オーナー専用',
          onTap: () {
            context.go('/staff-management');
          },
        ),
      );
    }

    // オーナー・店長: シフト管理
    items.add(
      _buildMenuCard(
        context,
        icon: Icons.schedule,
        title: t.text('shiftManagement'),
        subtitle: t.text('shiftManagementDesc'),
        color: Colors.indigo,
        isTablet: isTablet,
        onTap: () {
          context.go('/shift-management');
        },
      ),
    );

    // オーナー・店長: 勤怠管理
    items.add(
      _buildMenuCard(
        context,
        icon: Icons.access_time,
        title: t.text('attendanceManagement'),
        subtitle: t.text('attendanceManagementDesc'),
        color: Colors.teal,
        isTablet: isTablet,
        onTap: () {
          context.go('/attendance-management');
        },
      ),
    );

    // オーナー・店長: 商品管理
    items.add(
      _buildMenuCard(
        context,
        icon: Icons.shopping_bag,
        title: t.text('products'),
        subtitle: t.text('productsManageDesc'),
        color: Colors.deepOrange,
        isTablet: isTablet,
        onTap: () {
          context.go('/products');
        },
      ),
    );

    // オーナー・店長: 分析・売上レポート
    items.add(
      _buildMenuCard(
        context,
        icon: Icons.analytics,
        title: t.text('analytics'),
        subtitle: t.text('analyticsDesc'),
        color: Colors.blue,
        isTablet: isTablet,
        badge: isOwner ? null : '閲覧のみ',
        onTap: () {
          context.go('/analytics');
        },
      ),
    );

    // オーナー・店長: バック承認
    items.add(
      _buildMenuCard(
        context,
        icon: Icons.undo,
        title: 'バック承認',
        subtitle: '取消申請の承認・却下',
        color: Colors.deepOrange,
        isTablet: isTablet,
        onTap: () {
          context.go('/void-requests');
        },
      ),
    );

    // オーナー専用: キャンセル・削除履歴
    if (isOwner) {
      items.add(
        _buildMenuCard(
          context,
          icon: Icons.history,
          title: t.text('cancelledOrders'),
          subtitle: t.text('cancelledOrdersDesc'),
          color: Colors.red,
          isTablet: isTablet,
          badge: 'オーナー専用',
          onTap: () {
            context.go('/cancelled-orders');
          },
        ),
      );
    }

    // オーナー・店長: 顧客管理
    items.add(
      _buildMenuCard(
        context,
        icon: Icons.person_search,
        title: t.text('customers'),
        subtitle: t.text('customersDesc'),
        color: Colors.cyan,
        isTablet: isTablet,
        badge: isOwner ? null : '閲覧のみ',
        onTap: () {
          context.go('/customers');
        },
      ),
    );

    // オーナー専用: 店舗設定
    if (isOwner) {
      items.add(
        _buildMenuCard(
          context,
          icon: Icons.store,
          title: t.text('shopSettings'),
          subtitle: t.text('shopSettingsDesc'),
          color: Colors.brown,
          isTablet: isTablet,
          badge: 'オーナー専用',
          onTap: () {
            context.go('/shop-settings');
          },
        ),
      );
    }

    // オーナー専用: ブラックリスト
    if (isOwner) {
      items.add(
        _buildMenuCard(
          context,
          icon: Icons.block,
          title: t.text('blacklist'),
          subtitle: t.text('blacklistDesc'),
          color: Colors.red,
          isTablet: isTablet,
          badge: 'オーナー専用',
          onTap: () {
            context.go('/blacklist');
          },
        ),
      );
    }

    // 共通: プリンター設定
    items.add(
      _buildMenuCard(
        context,
        icon: Icons.print,
        title: t.text('printerSettings'),
        subtitle: t.text('printerSettingsDesc'),
        isTablet: isTablet,
        onTap: () {
          context.go('/printer-settings');
        },
      ),
    );

    // 共通: 通知設定
    items.add(
      _buildMenuCard(
        context,
        icon: Icons.notifications_active,
        title: t.text('notificationSettings'),
        subtitle: t.text('notificationSettingsDesc'),
        isTablet: isTablet,
        onTap: () {
          context.go('/notification-settings');
        },
      ),
    );

    return items;
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
    bool isTablet = false,
    String? badge,
  }) {
    final cardColor = color ?? Theme.of(context).primaryColor;
    final iconSize = isTablet ? 56.0 : 48.0;
    final titleSize = isTablet ? 16.0 : 14.0;
    final subtitleSize = isTablet ? 11.0 : 9.0;
    final padding = isTablet ? 20.0 : 16.0;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: iconSize, color: cardColor),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: subtitleSize,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // バッジ表示
            if (badge != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badge == 'オーナー専用'
                        ? Colors.purple
                        : badge == '閲覧のみ'
                            ? Colors.grey
                            : Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
