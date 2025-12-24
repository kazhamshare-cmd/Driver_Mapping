import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/reservation_block.dart';
import '../../providers/reservation_block_provider.dart';
import '../../providers/auth_provider.dart';

/// 予約ブロック管理画面
class ReservationBlocksScreen extends ConsumerStatefulWidget {
  const ReservationBlocksScreen({super.key});

  @override
  ConsumerState<ReservationBlocksScreen> createState() => _ReservationBlocksScreenState();
}

class _ReservationBlocksScreenState extends ConsumerState<ReservationBlocksScreen> {
  @override
  Widget build(BuildContext context) {
    final blocksAsync = ref.watch(upcomingReservationBlocksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('予約ブロック管理'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: blocksAsync.when(
        data: (blocks) {
          if (blocks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    '予約ブロックはありません',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '特定の日時の予約受付を停止できます',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          // 日付でグループ化
          final groupedBlocks = <DateTime, List<ReservationBlock>>{};
          for (final block in blocks) {
            final date = DateTime(block.date.year, block.date.month, block.date.day);
            groupedBlocks.putIfAbsent(date, () => []).add(block);
          }

          final sortedDates = groupedBlocks.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final date = sortedDates[index];
              final dateBlocks = groupedBlocks[date]!;
              return _buildDateSection(date, dateBlocks);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('エラー: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBlockDialog(),
        icon: const Icon(Icons.add),
        label: const Text('ブロック追加'),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  Widget _buildDateSection(DateTime date, List<ReservationBlock> blocks) {
    final dateFormat = DateFormat('M/d (E)', 'ja');
    final isToday = DateTime.now().difference(date).inDays == 0 &&
        DateTime.now().day == date.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(
                dateFormat.format(date),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isToday ? Colors.red.shade700 : Colors.black87,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '今日',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
        ...blocks.map((block) => _buildBlockCard(block)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBlockCard(ReservationBlock block) {
    Color typeColor;
    IconData typeIcon;

    switch (block.type) {
      case ReservationBlockType.closed:
        typeColor = Colors.red;
        typeIcon = Icons.store_mall_directory;
        break;
      case ReservationBlockType.noReservation:
        typeColor = Colors.orange;
        typeIcon = Icons.event_busy;
        break;
      case ReservationBlockType.full:
        typeColor = Colors.purple;
        typeIcon = Icons.people;
        break;
      case ReservationBlockType.staffOff:
        typeColor = Colors.blue;
        typeIcon = Icons.person_off;
        break;
      case ReservationBlockType.other:
        typeColor = Colors.grey;
        typeIcon = Icons.block;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(typeIcon, color: typeColor),
        ),
        title: Text(
          block.type.label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(block.timeRangeLabel),
            if (block.staffName != null)
              Text('スタッフ: ${block.staffName}'),
            if (block.reason != null && block.reason!.isNotEmpty)
              Text('理由: ${block.reason}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteBlock(block),
        ),
        isThreeLine: block.reason != null || block.staffName != null,
      ),
    );
  }

  Future<void> _showAddBlockDialog() async {
    final result = await showDialog<ReservationBlock>(
      context: context,
      builder: (context) => const _AddBlockDialog(),
    );

    if (result != null) {
      try {
        final create = ref.read(createReservationBlockProvider);
        await create(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('予約ブロックを追加しました'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deleteBlock(ReservationBlock block) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: Text('${block.type.label}（${block.timeRangeLabel}）を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final delete = ref.read(deleteReservationBlockProvider);
        await delete(block.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('削除しました')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

/// 予約ブロック追加ダイアログ
class _AddBlockDialog extends ConsumerStatefulWidget {
  const _AddBlockDialog();

  @override
  ConsumerState<_AddBlockDialog> createState() => _AddBlockDialogState();
}

class _AddBlockDialogState extends ConsumerState<_AddBlockDialog> {
  DateTime _selectedDate = DateTime.now();
  ReservationBlockType _selectedType = ReservationBlockType.noReservation;
  bool _isAllDay = true;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 14, minute: 0);
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd (E)', 'ja');
    final staffUser = ref.watch(staffUserProvider).value;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.block, color: Colors.red),
          SizedBox(width: 8),
          Text('予約ブロック追加'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日付選択
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('日付'),
              subtitle: Text(dateFormat.format(_selectedDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                }
              },
            ),
            const Divider(),

            // ブロック種別
            const Text('ブロック種別', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ReservationBlockType.values.map((type) {
                return ChoiceChip(
                  label: Text(type.label),
                  selected: _selectedType == type,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedType = type);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 終日/時間指定
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('終日'),
              value: _isAllDay,
              onChanged: (value) => setState(() => _isAllDay = value),
            ),

            if (!_isAllDay) ...[
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('開始時間'),
                      subtitle: Text(_formatTime(_startTime)),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _startTime,
                        );
                        if (time != null) {
                          setState(() => _startTime = time);
                        }
                      },
                    ),
                  ),
                  const Text('〜'),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('終了時間'),
                      subtitle: Text(_formatTime(_endTime)),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _endTime,
                        );
                        if (time != null) {
                          setState(() => _endTime = time);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // 理由
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: '理由（任意）',
                border: OutlineInputBorder(),
                hintText: '例: 店内改装のため',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            final block = ReservationBlock(
              id: '',
              shopId: staffUser?.shopId ?? '',
              date: _selectedDate,
              startTime: _isAllDay ? null : _formatTime(_startTime),
              endTime: _isAllDay ? null : _formatTime(_endTime),
              isAllDay: _isAllDay,
              type: _selectedType,
              reason: _reasonController.text.isEmpty ? null : _reasonController.text,
              createdAt: DateTime.now(),
              createdBy: staffUser?.id ?? '',
            );
            Navigator.pop(context, block);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          child: const Text('追加'),
        ),
      ],
    );
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
