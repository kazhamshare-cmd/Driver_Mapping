import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/reservation.dart';
import '../../models/table.dart';
import '../../providers/table_provider.dart';
import '../../providers/session_provider.dart';

/// 来店確認ダイアログ
class CheckInDialog extends ConsumerStatefulWidget {
  final Reservation reservation;

  const CheckInDialog({
    required this.reservation,
    super.key,
  });

  @override
  ConsumerState<CheckInDialog> createState() => _CheckInDialogState();
}

class _CheckInDialogState extends ConsumerState<CheckInDialog> {
  late int _actualCount;
  String? _selectedTableId;
  String? _selectedTableName;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _actualCount = widget.reservation.numberOfPeople ?? 1;
    _selectedTableId = widget.reservation.tableId;
  }

  @override
  Widget build(BuildContext context) {
    final tables = ref.watch(sortedTablesProvider);

    return AlertDialog(
      title: const Text('来店確認'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 予約情報
            Card(
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.reservation.userName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '予約: ${widget.reservation.menuName}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    if (widget.reservation.staffName != null)
                      Text(
                        '指名: ${widget.reservation.staffName}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 実来店人数
            const Text(
              '実来店人数',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _actualCount > 1
                      ? () => setState(() => _actualCount--)
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$_actualCount 名',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _actualCount++),
                ),
                if (widget.reservation.numberOfPeople != null &&
                    _actualCount != widget.reservation.numberOfPeople)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '(予約: ${widget.reservation.numberOfPeople}名)',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // 利用テーブル選択
            const Text(
              '利用テーブル/席',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (tables.isEmpty)
              const Text('テーブルが設定されていません')
            else
              DropdownButtonFormField<String>(
                value: _selectedTableId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                hint: const Text('テーブルを選択'),
                items: tables.map((table) {
                  return DropdownMenuItem<String>(
                    value: table.id,
                    child: Text(
                      '${table.displayName} (${table.minCapacity}-${table.maxCapacity}名)',
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTableId = value;
                    _selectedTableName = tables
                        .firstWhere((t) => t.id == value)
                        .displayName;
                  });
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _isLoading || _selectedTableId == null
              ? null
              : _handleCheckIn,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('来店開始'),
        ),
      ],
    );
  }

  Future<void> _handleCheckIn() async {
    if (_selectedTableId == null) return;

    setState(() => _isLoading = true);

    try {
      // テーブル名を取得
      final tables = ref.read(sortedTablesProvider);
      final selectedTable = tables.firstWhere(
        (t) => t.id == _selectedTableId,
        orElse: () => tables.first,
      );

      final startSession = ref.read(startSessionFromReservationProvider);
      final sessionId = await startSession(
        reservation: widget.reservation,
        actualCount: _actualCount,
        tableId: _selectedTableId!,
        tableName: selectedTable.displayName,
        primaryStaffId: widget.reservation.staffId,
        primaryStaffName: widget.reservation.staffName,
      );

      if (mounted) {
        Navigator.pop(context, sessionId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('来店を開始しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// ウォークイン（予約なし来店）ダイアログ
class WalkInDialog extends ConsumerStatefulWidget {
  const WalkInDialog({super.key});

  @override
  ConsumerState<WalkInDialog> createState() => _WalkInDialogState();
}

class _WalkInDialogState extends ConsumerState<WalkInDialog> {
  final _customerNameController = TextEditingController();
  int _actualCount = 1;
  String? _selectedTableId;
  bool _isLoading = false;

  @override
  void dispose() {
    _customerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tables = ref.watch(sortedTablesProvider);

    return AlertDialog(
      title: const Text('ウォークイン来店'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // お客様名（任意）
            TextField(
              controller: _customerNameController,
              decoration: const InputDecoration(
                labelText: 'お客様名（任意）',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // 来店人数
            const Text(
              '来店人数',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _actualCount > 1
                      ? () => setState(() => _actualCount--)
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$_actualCount 名',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _actualCount++),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 利用テーブル選択
            const Text(
              '利用テーブル/席',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (tables.isEmpty)
              const Text('テーブルが設定されていません')
            else
              DropdownButtonFormField<String>(
                value: _selectedTableId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                hint: const Text('テーブルを選択'),
                items: tables.map((table) {
                  return DropdownMenuItem<String>(
                    value: table.id,
                    child: Text(
                      '${table.displayName} (${table.minCapacity}-${table.maxCapacity}名)',
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedTableId = value);
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _isLoading || _selectedTableId == null
              ? null
              : _handleWalkIn,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('来店開始'),
        ),
      ],
    );
  }

  Future<void> _handleWalkIn() async {
    if (_selectedTableId == null) return;

    setState(() => _isLoading = true);

    try {
      final tables = ref.read(sortedTablesProvider);
      final selectedTable = tables.firstWhere(
        (t) => t.id == _selectedTableId,
        orElse: () => tables.first,
      );

      final startSession = ref.read(startWalkInSessionProvider);
      final sessionId = await startSession(
        actualCount: _actualCount,
        tableId: _selectedTableId!,
        tableName: selectedTable.displayName,
        customerName: _customerNameController.text.isNotEmpty
            ? _customerNameController.text
            : null,
      );

      if (mounted) {
        Navigator.pop(context, sessionId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('来店を開始しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
