import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';

/// お知らせ管理画面
class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  @override
  Widget build(BuildContext context) {
    final staffUser = ref.watch(staffUserProvider).value;

    if (staffUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('お知らせ管理'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shops')
            .doc(staffUser.shopId)
            .collection('announcements')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final announcements = snapshot.data?.docs ?? [];

          if (announcements.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'お知らせがありません',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '新しいお知らせを作成してください',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              final doc = announcements[index];
              final data = doc.data() as Map<String, dynamic>;

              return _buildAnnouncementCard(
                staffUser.shopId,
                doc.id,
                data,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(context, staffUser.shopId, null, null),
        backgroundColor: Colors.orange.shade700,
        icon: const Icon(Icons.add),
        label: const Text('新規作成'),
      ),
    );
  }

  Widget _buildAnnouncementCard(
    String shopId,
    String docId,
    Map<String, dynamic> data,
  ) {
    final title = data['title'] as String? ?? '';
    final content = data['content'] as String? ?? '';
    final isActive = data['isActive'] as bool? ?? true;
    final priority = data['priority'] as String? ?? 'normal';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final startDate = (data['startDate'] as Timestamp?)?.toDate();
    final endDate = (data['endDate'] as Timestamp?)?.toDate();

    Color priorityColor;
    String priorityLabel;
    switch (priority) {
      case 'high':
        priorityColor = Colors.red;
        priorityLabel = '重要';
        break;
      case 'low':
        priorityColor = Colors.grey;
        priorityLabel = '低';
        break;
      default:
        priorityColor = Colors.blue;
        priorityLabel = '通常';
    }

    final now = DateTime.now();
    final isWithinPeriod = (startDate == null || now.isAfter(startDate)) &&
        (endDate == null || now.isBefore(endDate));
    final isDisplayed = isActive && isWithinPeriod;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDisplayed ? Colors.green.shade50 : Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    priorityLabel,
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  isDisplayed ? Icons.visibility : Icons.visibility_off,
                  size: 16,
                  color: isDisplayed ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  isDisplayed ? '表示中' : '非表示',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDisplayed ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // コンテンツ
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // 期間
                if (startDate != null || endDate != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.date_range, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${startDate != null ? DateFormat('MM/dd').format(startDate) : '開始日なし'}'
                          ' 〜 '
                          '${endDate != null ? DateFormat('MM/dd').format(endDate) : '終了日なし'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),
                Text(
                  createdAt != null
                      ? '作成: ${DateFormat('yyyy/MM/dd HH:mm').format(createdAt)}'
                      : '',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          // アクションボタン
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 表示/非表示切り替え
                TextButton.icon(
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('shops')
                        .doc(shopId)
                        .collection('announcements')
                        .doc(docId)
                        .update({'isActive': !isActive});
                  },
                  icon: Icon(
                    isActive ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                  ),
                  label: Text(isActive ? '非表示にする' : '表示する'),
                ),
                TextButton.icon(
                  onPressed: () => _showEditDialog(context, shopId, docId, data),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('編集'),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(shopId, docId, title),
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  label: const Text('削除', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    String shopId,
    String? docId,
    Map<String, dynamic>? existingData,
  ) async {
    final titleController = TextEditingController(text: existingData?['title'] ?? '');
    final contentController = TextEditingController(text: existingData?['content'] ?? '');
    String priority = existingData?['priority'] ?? 'normal';
    bool isActive = existingData?['isActive'] ?? true;
    DateTime? startDate = (existingData?['startDate'] as Timestamp?)?.toDate();
    DateTime? endDate = (existingData?['endDate'] as Timestamp?)?.toDate();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(docId == null ? '新規お知らせ' : 'お知らせ編集'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'タイトル',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(
                    labelText: '内容',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),

                // 優先度
                const Text('優先度', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'low', label: Text('低')),
                    ButtonSegment(value: 'normal', label: Text('通常')),
                    ButtonSegment(value: 'high', label: Text('重要')),
                  ],
                  selected: {priority},
                  onSelectionChanged: (selected) {
                    setState(() => priority = selected.first);
                  },
                ),
                const SizedBox(height: 16),

                // 表示期間
                const Text('表示期間', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: startDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            setState(() => startDate = date);
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          startDate != null
                              ? DateFormat('MM/dd').format(startDate!)
                              : '開始日',
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('〜'),
                    ),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: endDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            setState(() => endDate = date);
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          endDate != null
                              ? DateFormat('MM/dd').format(endDate!)
                              : '終了日',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 有効/無効
                SwitchListTile(
                  title: const Text('すぐに公開'),
                  value: isActive,
                  onChanged: (value) {
                    setState(() => isActive = value);
                  },
                  contentPadding: EdgeInsets.zero,
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
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('タイトルを入力してください')),
                  );
                  return;
                }

                final data = {
                  'title': titleController.text.trim(),
                  'content': contentController.text.trim(),
                  'priority': priority,
                  'isActive': isActive,
                  'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
                  'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (docId == null) {
                  data['createdAt'] = FieldValue.serverTimestamp();
                  await FirebaseFirestore.instance
                      .collection('shops')
                      .doc(shopId)
                      .collection('announcements')
                      .add(data);
                } else {
                  await FirebaseFirestore.instance
                      .collection('shops')
                      .doc(shopId)
                      .collection('announcements')
                      .doc(docId)
                      .update(data);
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(docId == null ? 'お知らせを作成しました' : 'お知らせを更新しました'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: Text(docId == null ? '作成' : '更新'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String shopId, String docId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「$title」を削除しますか？'),
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
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('announcements')
          .doc(docId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('お知らせを削除しました')),
        );
      }
    }
  }
}
