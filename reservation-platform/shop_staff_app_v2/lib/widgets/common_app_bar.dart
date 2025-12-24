import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/notification_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/table_call_provider.dart';
import 'table_call_notification_widget.dart';

/// 共通のアプリバー
/// 左側に戻るボタン、右側に通知バッジ付きベルアイコンと言語切り替えボタンを表示
class CommonAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final bool showLanguageButton;
  final VoidCallback? onNotificationTap;

  const CommonAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.showLanguageButton = true,
    this.onNotificationTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadNotificationCountProvider);
    final unreadCount = unreadCountAsync.value ?? 0;
    final currentLocale = ref.watch(localeProvider);
    final pendingCallCount = ref.watch(pendingTableCallCountProvider);
    final activeCalls = ref.watch(activeTableCallsProvider).value ?? [];

    // 通知の合計数（一般通知 + テーブル呼び出し）
    final totalBadgeCount = unreadCount + activeCalls.length;

    return AppBar(
      title: Text(title),
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.home),
              onPressed: () => context.go('/home'),
            )
          : null,
      actions: [
        // 言語切り替えボタン
        if (showLanguageButton)
          PopupMenuButton<AppLocale>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language, size: 20),
                const SizedBox(width: 4),
                Text(
                  currentLocale.languageCode.toUpperCase(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            tooltip: 'Change Language',
            onSelected: (AppLocale locale) {
              ref.read(localeProvider.notifier).setLocale(locale);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: AppLocale.ja,
                child: Row(
                  children: [
                    Text('🇯🇵', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 12),
                    Text('日本語'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: AppLocale.en,
                child: Row(
                  children: [
                    Text('🇬🇧', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 12),
                    Text('English'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: AppLocale.th,
                child: Row(
                  children: [
                    Text('🇹🇭', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 12),
                    Text('ไทย'),
                  ],
                ),
              ),
            ],
          ),
        // 通知アイコン（テーブル呼び出し優先）
        Stack(
          children: [
            IconButton(
              icon: Icon(
                pendingCallCount > 0
                    ? Icons.notifications_active
                    : Icons.notifications_outlined,
                color: pendingCallCount > 0 ? Colors.orange : null,
              ),
              onPressed: onNotificationTap ?? () {
                // テーブル呼び出しダイアログを表示
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
                    color: pendingCallCount > 0 ? Colors.red : Colors.orange,
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
        const SizedBox(width: 8),
      ],
    );
  }
}
