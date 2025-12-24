import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/auth_provider.dart';

/// 営業カレンダー画面（特別営業日・臨時休業日の設定）
class BusinessCalendarScreen extends ConsumerStatefulWidget {
  const BusinessCalendarScreen({super.key});

  @override
  ConsumerState<BusinessCalendarScreen> createState() => _BusinessCalendarScreenState();
}

class _BusinessCalendarScreenState extends ConsumerState<BusinessCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // 特別日のマップ（日付 -> 種類）
  Map<DateTime, SpecialDay> _specialDays = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSpecialDays();
  }

  Future<void> _loadSpecialDays() async {
    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('shops')
          .doc(staffUser.shopId)
          .collection('specialDays')
          .get();

      final days = <DateTime, SpecialDay>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        final normalizedDate = DateTime(date.year, date.month, date.day);
        days[normalizedDate] = SpecialDay(
          id: doc.id,
          date: normalizedDate,
          type: data['type'] ?? 'closed',
          reason: data['reason'],
          openTime: data['openTime'],
          closeTime: data['closeTime'],
        );
      }

      setState(() {
        _specialDays = days;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  List<SpecialDay> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final specialDay = _specialDays[normalizedDay];
    return specialDay != null ? [specialDay] : [];
  }

  Future<void> _showDayDialog(DateTime day) async {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final existingDay = _specialDays[normalizedDay];

    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) return;

    String selectedType = existingDay?.type ?? 'closed';
    final reasonController = TextEditingController(text: existingDay?.reason ?? '');
    String? openTime = existingDay?.openTime;
    String? closeTime = existingDay?.closeTime;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${day.month}/${day.day} の設定'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('種類', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'closed', child: Text('臨時休業')),
                    DropdownMenuItem(value: 'special_hours', child: Text('特別営業時間')),
                    DropdownMenuItem(value: 'holiday', child: Text('祝日営業')),
                    DropdownMenuItem(value: 'event', child: Text('イベント')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: '理由・メモ',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (selectedType == 'special_hours' || selectedType == 'holiday') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: int.tryParse(openTime?.split(':')[0] ?? '11') ?? 11,
                                minute: int.tryParse(openTime?.split(':')[1] ?? '00') ?? 0,
                              ),
                            );
                            if (time != null) {
                              setDialogState(() {
                                openTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: '開店時間',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(openTime ?? '11:00'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: int.tryParse(closeTime?.split(':')[0] ?? '22') ?? 22,
                                minute: int.tryParse(closeTime?.split(':')[1] ?? '00') ?? 0,
                              ),
                            );
                            if (time != null) {
                              setDialogState(() {
                                closeTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: '閉店時間',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(closeTime ?? '22:00'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (existingDay != null)
              TextButton(
                onPressed: () => Navigator.pop(context, {'delete': true}),
                child: const Text('削除', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'type': selectedType,
                'reason': reasonController.text,
                'openTime': openTime,
                'closeTime': closeTime,
              }),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('shops')
          .doc(staffUser.shopId)
          .collection('specialDays');

      if (result['delete'] == true && existingDay != null) {
        // 削除
        await docRef.doc(existingDay.id).delete();
        setState(() {
          _specialDays.remove(normalizedDay);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('削除しました')),
          );
        }
      } else {
        // 追加/更新
        final data = {
          'date': Timestamp.fromDate(normalizedDay),
          'type': result['type'],
          'reason': result['reason'],
          'openTime': result['openTime'],
          'closeTime': result['closeTime'],
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (existingDay != null) {
          await docRef.doc(existingDay.id).update(data);
        } else {
          final newDoc = await docRef.add(data);
          data['id'] = newDoc.id;
        }

        setState(() {
          _specialDays[normalizedDay] = SpecialDay(
            id: existingDay?.id ?? '',
            date: normalizedDay,
            type: result['type'],
            reason: result['reason'],
            openTime: result['openTime'],
            closeTime: result['closeTime'],
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存しました')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('営業カレンダー'),
        backgroundColor: Colors.brown.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 凡例
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey.shade100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildLegend(Colors.red, '臨時休業'),
                      _buildLegend(Colors.blue, '特別営業'),
                      _buildLegend(Colors.orange, '祝日営業'),
                      _buildLegend(Colors.purple, 'イベント'),
                    ],
                  ),
                ),
                // カレンダー
                TableCalendar(
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: _getEventsForDay,
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    _showDayDialog(selectedDay);
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return null;
                      final specialDay = events.first as SpecialDay;
                      return Positioned(
                        bottom: 1,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getColorForType(specialDay.type),
                          ),
                        ),
                      );
                    },
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Colors.brown.shade200,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Colors.brown.shade700,
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonDecoration: BoxDecoration(
                      border: Border.all(color: Colors.brown.shade700),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    formatButtonTextStyle: TextStyle(color: Colors.brown.shade700),
                  ),
                ),
                const Divider(),
                // 今後の特別日リスト
                Expanded(
                  child: _buildUpcomingSpecialDays(),
                ),
              ],
            ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'closed':
        return Colors.red;
      case 'special_hours':
        return Colors.blue;
      case 'holiday':
        return Colors.orange;
      case 'event':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'closed':
        return '臨時休業';
      case 'special_hours':
        return '特別営業';
      case 'holiday':
        return '祝日営業';
      case 'event':
        return 'イベント';
      default:
        return type;
    }
  }

  Widget _buildUpcomingSpecialDays() {
    final now = DateTime.now();
    final upcomingDays = _specialDays.entries
        .where((e) => e.key.isAfter(now.subtract(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (upcomingDays.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              '特別営業日・臨時休業日はありません',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'カレンダーの日付をタップして追加',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: upcomingDays.length,
      itemBuilder: (context, index) {
        final entry = upcomingDays[index];
        final day = entry.value;
        return Card(
          child: ListTile(
            leading: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getColorForType(day.type),
              ),
            ),
            title: Text(
              '${day.date.month}/${day.date.day} (${_getWeekdayName(day.date.weekday)})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_getTypeLabel(day.type)),
                if (day.reason != null && day.reason!.isNotEmpty)
                  Text(day.reason!, style: TextStyle(color: Colors.grey.shade600)),
                if (day.openTime != null && day.closeTime != null)
                  Text('${day.openTime} - ${day.closeTime}',
                      style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showDayDialog(day.date),
            ),
          ),
        );
      },
    );
  }

  String _getWeekdayName(int weekday) {
    const names = ['月', '火', '水', '木', '金', '土', '日'];
    return names[weekday - 1];
  }
}

class SpecialDay {
  final String id;
  final DateTime date;
  final String type;
  final String? reason;
  final String? openTime;
  final String? closeTime;

  SpecialDay({
    required this.id,
    required this.date,
    required this.type,
    this.reason,
    this.openTime,
    this.closeTime,
  });
}
