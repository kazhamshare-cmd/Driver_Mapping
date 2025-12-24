import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/table.dart';
import '../../providers/auth_provider.dart';
// import '../../widgets/common_app_bar.dart'; // CommonAppBarを使わず標準AppBarで対応

/// テーブル選択画面（代理注文用）
class TableSelectionScreen extends ConsumerWidget {
  const TableSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffUserAsync = ref.watch(staffUserProvider);
    final firebaseService = ref.watch(firebaseServiceProvider);

    return Scaffold(
      // ▼ TOPに戻れるように標準のAppBarを使用
      appBar: AppBar(
        title: const Text('代理注文 - テーブル選択'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'), // 確実にホームへ戻る
        ),
      ),
      body: staffUserAsync.when(
        data: (staffUser) {
          if (staffUser == null) {
            return const Center(child: Text('ユーザー情報が取得できません'));
          }

          // 出勤中でなければ利用不可
          if (!staffUser.isWorking) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.work_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    '代理注文は出勤中のみ利用できます',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/clock-in'),
                    icon: const Icon(Icons.login),
                    label: const Text('出勤する'),
                  ),
                ],
              ),
            );
          }

          return StreamBuilder<List<TableModel>>(
            stream: firebaseService.watchTables(staffUser.shopId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('エラー: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final tables = snapshot.data!;

              if (tables.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.table_restaurant, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'テーブルが登録されていません',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              // タブレット対応
              return LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  int crossAxisCount;
                  double childAspectRatio;
                  bool isTablet = screenWidth > 600;

                  if (screenWidth > 900) {
                    crossAxisCount = 5;
                    childAspectRatio = 1.1;
                  } else if (screenWidth > 600) {
                    crossAxisCount = 4;
                    childAspectRatio = 1.0;
                  } else {
                    crossAxisCount = 3;
                    childAspectRatio = 1.2;
                  }

                  return GridView.builder(
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: isTablet ? 20 : 16,
                      mainAxisSpacing: isTablet ? 20 : 16,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemCount: tables.length,
                    itemBuilder: (context, index) {
                      final table = tables[index];
                      return _TableCard(
                        table: table,
                        isTablet: isTablet,
                        onTap: () {
                          // メニュー選択画面へ遷移
                          context.go('/proxy-order/menu?tableId=${table.id}');
                        },
                      );
                    },
                  );
                },
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
              Text('エラー: $error'),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  final TableModel table;
  final VoidCallback onTap;
  final bool isTablet;

  const _TableCard({
    required this.table,
    required this.onTap,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    final isOccupied = table.status == TableStatus.occupied;
    final isReserved = table.status == TableStatus.reserved;

    final iconSize = isTablet ? 36.0 : 28.0;
    final titleFontSize = isTablet ? 16.0 : 14.0;
    final subtitleFontSize = isTablet ? 13.0 : 11.0;
    final padding = isTablet ? 12.0 : 8.0;

    Color cardColor;
    Color textColor;
    IconData icon;

    if (isOccupied) {
      cardColor = Colors.orange.shade100;
      textColor = Colors.orange.shade900;
      icon = Icons.people;
    } else if (isReserved) {
      cardColor = Colors.blue.shade100;
      textColor = Colors.blue.shade900;
      icon = Icons.event_seat;
    } else {
      cardColor = Colors.green.shade100;
      textColor = Colors.green.shade900;
      icon = Icons.check_circle_outline;
    }

    return Card(
      color: cardColor,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize, color: textColor),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  'テーブル ${table.tableNumber}',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  _getStatusText(),
                  style: TextStyle(
                    fontSize: subtitleFontSize,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText() {
    switch (table.status) {
      case TableStatus.available:
        return '空席';
      case TableStatus.occupied:
        return '使用中';
      case TableStatus.reserved:
        return '予約済';
      case TableStatus.cleaning:
        return '清掃中';
    }
  }
}