import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/session.dart';
import '../../providers/session_provider.dart';
import 'session_detail_screen.dart';
import 'check_in_dialog.dart';

/// アクティブセッション（利用中）一覧画面
class ActiveSessionsScreen extends ConsumerWidget {
  const ActiveSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(activeSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('利用中'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(activeSessionsProvider),
            tooltip: '更新',
          ),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('エラー: $error')),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '現在利用中のお客様はいません',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showWalkInDialog(context),
                    icon: const Icon(Icons.person_add),
                    label: const Text('ウォークイン来店'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return _SessionCard(
                session: session,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SessionDetailScreen(
                        sessionId: session.id,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showWalkInDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('ウォークイン'),
      ),
    );
  }

  void _showWalkInDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const WalkInDialog(),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback onTap;

  const _SessionCard({
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final duration = DateTime.now().difference(session.startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー行
              Row(
                children: [
                  // テーブル名
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      session.tableName ?? 'テーブル未設定',
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 人数
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people, size: 16),
                        const SizedBox(width: 4),
                        Text('${session.actualCount}名'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // 経過時間
                  Text(
                    hours > 0 ? '$hours時間${minutes}分' : '$minutes分',
                    style: TextStyle(
                      color: duration.inMinutes > 120
                          ? Colors.orange[700]
                          : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // お客様名
              if (session.customerName != null)
                Text(
                  session.customerName!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              // 担当スタッフ
              if (session.primaryStaffName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '担当: ${session.primaryStaffName}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

              // 注文アイテム数と金額
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.receipt, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${session.items.length}点',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Text(
                    '¥${session.calculatedTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // 予約からの場合
              if (session.reservationId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event, size: 14, color: Colors.green[700]),
                        const SizedBox(width: 4),
                        Text(
                          '予約',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
