import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/table.dart';
import '../../models/order.dart';
import '../../models/reservation.dart';
import '../../models/shop.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/unified_printer_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/empty_state_widget.dart';
import '../register/register_payment_dialog.dart';

class TableManagementScreen extends ConsumerStatefulWidget {
  const TableManagementScreen({super.key});

  @override
  ConsumerState<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends ConsumerState<TableManagementScreen> {
  final _printerService = UnifiedPrinterService();
  final _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    final staffUserAsync = ref.watch(staffUserProvider);
    final shopAsync = ref.watch(shopProvider);
    final t = ref.watch(translationProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: Text(t.text('tableManagement')),
      ),
      body: staffUserAsync.when(
        data: (staffUser) {
          if (staffUser == null) {
            return Center(child: Text(t.text('userInfoNotFound')));
          }

          // 本日の日付範囲を取得
          final today = DateTime.now();
          final startOfDay = DateTime(today.year, today.month, today.day);
          final endOfDay = startOfDay.add(const Duration(days: 1));

          // 席一覧、注文、本日の予約をリアルタイム監視
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tables')
                .where('shopId', isEqualTo: staffUser.shopId)
                .where('isActive', isEqualTo: true)
                .snapshots(),
            builder: (context, tableSnapshot) {
              if (tableSnapshot.hasError) {
                return ErrorStateWidget(
                  error: tableSnapshot.error.toString(),
                  onRetry: () => setState(() {}),
                );
              }
              if (!tableSnapshot.hasData) {
                return const LoadingStateWidget();
              }

              final tables = tableSnapshot.data!.docs.map((doc) {
                return TableModel.fromFirestore(doc);
              }).toList();

              // クライアント側でtableNumberでソート（数値として比較）
              tables.sort((a, b) {
                final aNum = int.tryParse(a.tableNumber) ?? 0;
                final bNum = int.tryParse(b.tableNumber) ?? 0;
                return aNum.compareTo(bNum);
              });

              // 未会計注文を監視して、注文があるテーブルを特定
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('shopId', isEqualTo: staffUser.shopId)
                    .where('status', whereIn: ['pending', 'confirmed', 'preparing', 'ready', 'served'])
                    .snapshots(),
                builder: (context, ordersSnapshot) {
                  // 未会計注文があるテーブルIDのセット
                  final Set<String> tablesWithOrders = {};
                  if (ordersSnapshot.hasData) {
                    for (var doc in ordersSnapshot.data!.docs) {
                      final tableId = doc['tableId'] as String?;
                      if (tableId != null) {
                        tablesWithOrders.add(tableId);
                      }
                    }
                  }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reservations')
                    .where('shopId', isEqualTo: staffUser.shopId)
                    .where('reservationDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                    .where('reservationDate', isLessThan: Timestamp.fromDate(endOfDay))
                    .snapshots(),
                builder: (context, reservationSnapshot) {
                  final reservations = reservationSnapshot.hasData
                      ? reservationSnapshot.data!.docs
                          .map((doc) => Reservation.fromFirestore(doc))
                          .where((r) => r.status == ReservationStatus.confirmed || r.status == ReservationStatus.pending)
                          .toList()
                      : <Reservation>[];
                  reservations.sort((a, b) => a.startTime.compareTo(b.startTime));

                  // 状態別カウント
                  // 注文があるテーブルは「使用中」として扱う
                  final availableTables = tables.where((t) =>
                    (t.status == TableStatus.available || t.status == TableStatus.cleaning) &&
                    !tablesWithOrders.contains(t.id)
                  ).toList();
                  final occupiedTables = tables.where((t) =>
                    t.status == TableStatus.occupied || tablesWithOrders.contains(t.id)
                  ).toList();
                  final reservedTables = tables.where((t) =>
                    t.status == TableStatus.reserved && !tablesWithOrders.contains(t.id)
                  ).toList();

                  // 未アサイン予約
                  final unassignedReservations = reservations.where((r) => r.tableId == null).toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 状況サマリー
                        _buildSummaryCard(
                          available: availableTables.length,
                          occupied: occupiedTables.length,
                          reserved: reservedTables.length,
                        ),
                        const SizedBox(height: 16),

                        // 未アサイン予約の警告
                        if (unassignedReservations.isNotEmpty)
                          _buildUnassignedReservationsAlert(
                            unassignedReservations,
                            availableTables,
                            staffUser.shopId,
                          ),

                        const SizedBox(height: 16),

                        // 全席一覧
                        Text(
                          '${t.text('tableStatus')} (${tables.length})',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),

                        if (tables.isEmpty)
                          EmptyStateWidget(
                            icon: Icons.table_restaurant,
                            message: t.text('noTables'),
                            subtitle: '管理画面からテーブルを追加してください',
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              // 画面幅に応じてカラム数を決定
                              final screenWidth = constraints.maxWidth;
                              int crossAxisCount;
                              double childAspectRatio;

                              if (screenWidth > 900) {
                                // 大きなタブレット
                                crossAxisCount = 4;
                                childAspectRatio = 1.3;
                              } else if (screenWidth > 600) {
                                // タブレット
                                crossAxisCount = 3;
                                childAspectRatio = 1.2;
                              } else {
                                // スマートフォン
                                crossAxisCount = 2;
                                childAspectRatio = 1.1;
                              }

                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: childAspectRatio,
                                ),
                                itemCount: tables.length,
                                itemBuilder: (context, index) {
                                  final table = tables[index];
                                  final reservation = reservations.firstWhere(
                                    (r) => r.tableId == table.id,
                                    orElse: () => Reservation(
                                      id: '',
                                      shopId: '',
                                      userId: '',
                                      userName: '',
                                      userEmail: '',
                                      userPhone: '',
                                      menuId: '',
                                      menuName: '',
                                      reservationDate: DateTime.now(),
                                      startTime: '',
                                      endTime: '',
                                      duration: 0,
                                      totalPrice: 0,
                                      status: ReservationStatus.cancelled,
                                      createdAt: DateTime.now(),
                                      updatedAt: DateTime.now(),
                                    ),
                                  );
                                  final hasReservation = reservation.id.isNotEmpty;

                                  // 同じグループのテーブルを取得
                                  final groupedTables = table.groupId != null
                                      ? tables.where((t) => t.groupId == table.groupId && t.id != table.id).toList()
                                      : <TableModel>[];

                                  // 店舗情報を取得
                                  final shop = shopAsync.value;
                                  final shopAddress = shop != null
                                      ? '${shop.prefecture}${shop.city}${shop.address}${shop.building ?? ''}'
                                      : null;

                                  // このテーブルに注文があるかチェック
                                  final hasOrders = tablesWithOrders.contains(table.id);

                                  return _TableCard(
                                    table: table,
                                    shopId: staffUser.shopId,
                                    shopCode: shop?.shopCode,
                                    reservation: hasReservation ? reservation : null,
                                    printerService: _printerService,
                                    firebaseService: _firebaseService,
                                    onStatusChange: (newStatus) => _changeTableStatus(table.id, newStatus),
                                    onCheckIn: hasReservation ? () => _handleCheckIn(reservation, table.id) : null,
                                    onMerge: () => _showMergeDialog(table, tables, staffUser.shopId),
                                    onUnmerge: table.groupId != null ? () => _unmergeTable(table) : null,
                                    groupedTables: groupedTables,
                                    t: t,
                                    isTablet: screenWidth > 600,
                                    shopName: shop?.shopName,
                                    shopAddress: shopAddress,
                                    shopPhone: shop?.phoneNumber,
                                    receiptSettings: shop?.receiptSettings,
                                    paymentMethods: shop?.paymentMethods ?? [],
                                    staffId: staffUser.id,
                                    staffName: staffUser.name,
                                    hasOrders: hasOrders,
                                  );
                                },
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
              );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('${t.text('error')}: $error')),
      ),
    );
  }

  Widget _buildSummaryCard({
    required int available,
    required int occupied,
    required int reserved,
  }) {
    final t = ref.read(translationProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem(t.text('available'), available, Colors.green),
            _buildSummaryItem(t.text('occupied'), occupied, Colors.red),
            _buildSummaryItem(t.text('reserved'), reserved, Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildUnassignedReservationsAlert(
    List<Reservation> reservations,
    List<TableModel> availableTables,
    String shopId,
  ) {
    final t = ref.read(translationProvider);
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  '${t.text('unassignedReservations')} (${reservations.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: reservations.map((r) {
                return ActionChip(
                  avatar: const Icon(Icons.person, size: 18),
                  label: Text('${r.startTime} ${r.userName} (${r.numberOfPeople ?? 1}${t.text('people')})'),
                  backgroundColor: Colors.orange.shade100,
                  onPressed: () => _showAssignDialog(r, availableTables, shopId),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignDialog(Reservation reservation, List<TableModel> availableTables, String shopId) {
    final t = ref.read(translationProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.text('seatAssign')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 予約情報
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.text('reservationInfo'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    reservation.userName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text('${reservation.startTime}〜 / ${reservation.numberOfPeople ?? 1}${t.text('people')}'),
                  if (reservation.menuName.isNotEmpty)
                    Text(
                      reservation.menuName,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(t.text('selectSeat')),
            const SizedBox(height: 8),
            if (availableTables.isEmpty)
              Text(t.text('noAvailableSeats'), style: const TextStyle(color: Colors.red))
            else
              ...availableTables.map((table) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Text(
                      table.tableNumber,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  title: Text('${table.tableNumber} (${table.capacity}${t.text('personSeat')})'),
                  onTap: () {
                    Navigator.pop(context);
                    _assignTable(reservation, table);
                  },
                );
              }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.text('cancel')),
          ),
        ],
      ),
    );
  }

  Future<void> _assignTable(Reservation reservation, TableModel table) async {
    final t = ref.read(translationProvider);
    try {
      // 予約にテーブル情報を追加
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservation.id)
          .update({
        'tableId': table.id,
        'tableNumber': table.tableNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // テーブルを予約済みに変更
      await FirebaseFirestore.instance.collection('tables').doc(table.id).update({
        'status': 'reserved',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${reservation.userName}${t.text('assignedTo')}${table.tableNumber}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.text('assignError')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleCheckIn(Reservation reservation, String tableId) async {
    final t = ref.read(translationProvider);
    try {
      // 予約に来店時刻を記録
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservation.id)
          .update({
        'checkedInAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // テーブルを使用中に変更
      await FirebaseFirestore.instance.collection('tables').doc(tableId).update({
        'status': 'occupied',
        'sessionStartedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${reservation.userName}${t.text('checkInRecorded')}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.text('checkInError')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _changeTableStatus(String tableId, String newStatus) async {
    final t = ref.read(translationProvider);
    try {
      final Map<String, dynamic> updateData = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'available') {
        updateData['sessionStartedAt'] = null;
      } else if (newStatus == 'occupied') {
        updateData['sessionStartedAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance.collection('tables').doc(tableId).update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.text('tableStatusUpdated')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.text('statusChangeError')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// テーブル結合ダイアログを表示
  void _showMergeDialog(TableModel table, List<TableModel> allTables, String shopId) {
    final t = ref.read(translationProvider);

    // 結合可能なテーブル（自分以外で、まだグループに入っていないか、同じグループのもの）
    final availableTables = allTables.where((t) {
      if (t.id == table.id) return false;
      // 既に別のグループに属している場合は除外
      if (t.groupId != null && t.groupId != table.groupId) return false;
      return true;
    }).toList();

    // 既存グループのテーブル
    final currentGroupTables = table.groupId != null
        ? allTables.where((t) => t.groupId == table.groupId && t.id != table.id).toList()
        : <TableModel>[];

    // 選択可能なテーブル（既にグループに入っていないもの）
    final selectableTables = availableTables.where((t) => t.groupId == null).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.text('tableMerge')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 現在のテーブル
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue,
                      radius: 16,
                      child: Text(
                        table.tableNumber,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${t.text('currentTable')}: ${table.tableNumber}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              // 既存の結合テーブル
              if (currentGroupTables.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  t.text('mergedTables'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: currentGroupTables.map((t) {
                    return Chip(
                      avatar: CircleAvatar(
                        backgroundColor: Colors.purple,
                        child: Text(t.tableNumber, style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                      label: Text(t.tableNumber),
                      backgroundColor: Colors.purple.shade50,
                    );
                  }).toList(),
                ),
              ],

              // 結合可能なテーブル
              const SizedBox(height: 16),
              Text(
                t.text('selectTableToMerge'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              if (selectableTables.isEmpty)
                Text(
                  t.text('noTableToMerge'),
                  style: const TextStyle(color: Colors.grey),
                )
              else
                ...selectableTables.map((targetTable) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Text(
                        targetTable.tableNumber,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    title: Text('${targetTable.tableNumber} (${targetTable.capacity}${t.text('personSeat')})'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _mergeTables(table, targetTable);
                    },
                  );
                }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.text('cancel')),
          ),
        ],
      ),
    );
  }

  /// テーブルを結合する
  Future<void> _mergeTables(TableModel table1, TableModel table2) async {
    final t = ref.read(translationProvider);
    try {
      // 既存のグループIDを使用するか、新しいIDを生成
      final groupId = table1.groupId ?? FirebaseFirestore.instance.collection('tables').doc().id;

      // 両方のテーブルに同じgroupIdを設定
      final batch = FirebaseFirestore.instance.batch();

      batch.update(
        FirebaseFirestore.instance.collection('tables').doc(table1.id),
        {
          'groupId': groupId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      batch.update(
        FirebaseFirestore.instance.collection('tables').doc(table2.id),
        {
          'groupId': groupId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${table1.tableNumber}${t.text('and')}${table2.tableNumber}${t.text('tableMerged')}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.text('mergeError')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// テーブル結合を解除する
  Future<void> _unmergeTable(TableModel table) async {
    final t = ref.read(translationProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.text('confirmUnmerge')),
        content: Text('${table.tableNumber}${t.text('unmergeConfirmMessage')}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.text('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(t.text('unmerge')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('tables').doc(table.id).update({
        'groupId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${table.tableNumber}${t.text('tableUnmerged')}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.text('unmergeError')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// 席カード
class _TableCard extends StatelessWidget {
  final TableModel table;
  final String shopId;
  final String? shopCode;  // QRコードURL用
  final Reservation? reservation;
  final UnifiedPrinterService printerService;
  final FirebaseService firebaseService;
  final Function(String) onStatusChange;
  final VoidCallback? onCheckIn;
  final VoidCallback onMerge;
  final VoidCallback? onUnmerge;
  final List<TableModel> groupedTables;
  final AppTranslations t;
  final bool isTablet;
  // レシート印刷用の店舗情報
  final String? shopName;
  final String? shopAddress;
  final String? shopPhone;
  final Map<String, dynamic>? receiptSettings;
  // 支払い方法マスタ
  final List<PaymentMethodSetting> paymentMethods;
  // 担当スタッフ情報
  final String? staffId;
  final String? staffName;
  // 注文があるかどうか
  final bool hasOrders;

  const _TableCard({
    required this.table,
    required this.shopId,
    this.shopCode,
    required this.reservation,
    required this.printerService,
    required this.firebaseService,
    required this.onStatusChange,
    required this.onMerge,
    required this.groupedTables,
    required this.t,
    this.onCheckIn,
    this.onUnmerge,
    this.isTablet = false,
    this.shopName,
    this.shopAddress,
    this.shopPhone,
    this.receiptSettings,
    this.paymentMethods = const [],
    this.staffId,
    this.staffName,
    this.hasOrders = false,
  });

  // 注文があれば「使用中」として扱う
  bool get _isEffectivelyOccupied => table.status == TableStatus.occupied || hasOrders;

  Color get _statusColor {
    if (_isEffectivelyOccupied) {
      return Colors.red;
    }
    switch (table.status) {
      case TableStatus.reserved:
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String get _statusLabel {
    if (_isEffectivelyOccupied) {
      return t.text('occupied');
    }
    switch (table.status) {
      case TableStatus.reserved:
        return t.text('reserved');
      default:
        return t.text('available');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionStartedAt = table.sessionStartedAt;
    final elapsedDuration = sessionStartedAt != null
        ? DateTime.now().difference(sessionStartedAt)
        : Duration.zero;

    // サイズ調整
    final cardPadding = isTablet ? 12.0 : 8.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: _statusColor, width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー: テーブル名 + ステータス + 人数
            Row(
              children: [
                // テーブル名（背景色付き角丸）
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    table.tableNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // 人数
                Text(
                  '${table.capacity}名',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const Spacer(),
                // ステータス
                Text(
                  _statusLabel,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            // グループ表示（結合されている場合）
            if (groupedTables.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.link, size: 10, color: Colors.purple.shade700),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      '+ ${groupedTables.map((t) => t.tableNumber).join(', ')}',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.purple.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 6),

            // 使用中の場合：滞在時間 + 注文金額（1行）
            if (_isEffectivelyOccupied) ...[
              Row(
                children: [
                  Icon(Icons.access_time, size: 12, color: _getElapsedTimeColor(elapsedDuration)),
                  const SizedBox(width: 2),
                  Text(
                    _formatElapsedTime(elapsedDuration),
                    style: TextStyle(
                      color: _getElapsedTimeColor(elapsedDuration),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  _buildOrderInfoCompact(context),
                ],
              ),
            ],

            // 予約済みの場合：予約情報（コンパクト）
            if (table.status == TableStatus.reserved && reservation != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event, size: 12, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${reservation!.startTime} ${reservation!.userName}様',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (reservation!.checkedInAt == null) ...[
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  height: 28,
                  child: ElevatedButton(
                    onPressed: onCheckIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(t.text('checkIn'), style: const TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ],

            const Spacer(),

            // アクションボタン
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  /// 注文金額（コンパクト版）
  Widget _buildOrderInfoCompact(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('shopId', isEqualTo: shopId)
          .where('tableId', isEqualTo: table.id)
          .where('status', whereIn: ['pending', 'confirmed', 'preparing', 'ready', 'served'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final orders = snapshot.data!.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
        final total = orders.fold<double>(0, (acc, o) => acc + o.total);

        return Text(
          '¥${total.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        );
      },
    );
  }

  Widget _buildOrderInfo(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('shopId', isEqualTo: shopId)
          .where('tableId', isEqualTo: table.id)
          .where('status', whereIn: ['pending', 'confirmed', 'preparing', 'ready', 'served'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final orders = snapshot.data!.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
        final total = orders.fold<double>(0, (acc, o) => acc + o.total);

        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${orders.length}件 ¥${total.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        // 使用中（注文がある場合も含む）→ 会計ボタン
        if (_isEffectivelyOccupied)
          Expanded(
            child: SizedBox(
              height: 28,
              child: ElevatedButton(
                onPressed: () => _openPaymentDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                ),
                child: Text(t.text('checkout'), style: const TextStyle(fontSize: 10)),
              ),
            ),
          ),
        if (_isEffectivelyOccupied) const SizedBox(width: 4),

        // QR印刷
        SizedBox(
          height: 28,
          width: 28,
          child: IconButton(
            onPressed: () => _printTableQR(context),
            icon: const Icon(Icons.qr_code, size: 16),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey[200],
            ),
          ),
        ),
        const SizedBox(width: 4),

        // テーブル結合
        SizedBox(
          height: 28,
          width: 28,
          child: IconButton(
            onPressed: onMerge,
            icon: const Icon(Icons.link, size: 16),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: Colors.purple[100],
            ),
          ),
        ),

        // 結合解除（グループに属している場合のみ）
        if (onUnmerge != null) ...[
          const SizedBox(width: 4),
          SizedBox(
            height: 28,
            width: 28,
            child: IconButton(
              onPressed: onUnmerge!,
              icon: const Icon(Icons.link_off, size: 16),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: Colors.orange[100],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatElapsedTime(Duration elapsed) {
    if (elapsed.inMinutes < 60) {
      return '${elapsed.inMinutes}${t.text('elapsedMin')}';
    } else {
      final hours = elapsed.inHours;
      final minutes = elapsed.inMinutes % 60;
      return '$hours${t.text('elapsedHour')}$minutes${t.text('elapsedMin')}';
    }
  }

  Color _getElapsedTimeColor(Duration elapsed) {
    if (elapsed.inMinutes < 60) {
      return Colors.green;
    } else if (elapsed.inMinutes < 120) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Future<void> _printTableQR(BuildContext context) async {
    try {
      await printerService.printTableQR(table, shopCode: shopCode);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.text('qrPrintSuccess')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.text('qrPrintFailed')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 会計ダイアログを表示
  Future<void> _openPaymentDialog(BuildContext context) async {
    // このテーブルの未会計注文を取得
    final ordersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .where('tableId', isEqualTo: table.id)
        .where('status', whereIn: ['pending', 'confirmed', 'preparing', 'ready', 'served'])
        .get();

    if (ordersSnapshot.docs.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.text('noUnpaidOrders')),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final orders = ordersSnapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();

    // 合算用オーダー作成
    double totalSubtotal = 0;
    double totalTax = 0;
    List<OrderItem> allItems = [];

    for (var o in orders) {
      totalSubtotal += o.subtotal;
      totalTax += o.tax;
      allItems.addAll(o.items);
    }

    final summaryOrder = OrderModel(
      id: orders.first.id,
      shopId: orders.first.shopId,
      tableId: orders.first.tableId,
      tableNumber: orders.first.tableNumber,
      orderNumber: 'Merged-${orders.length}',
      items: allItems,
      subtotal: totalSubtotal,
      tax: totalTax,
      total: totalSubtotal + totalTax,
      status: OrderStatus.served,
      paymentStatus: PaymentStatus.unpaid,
      orderedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (!context.mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RegisterPaymentDialog(
        order: summaryOrder,
        shopName: shopName,
        firebaseService: firebaseService,
        shopAddress: shopAddress,
        shopPhone: shopPhone,
        receiptSettings: receiptSettings,
        paymentMethods: paymentMethods,
        staffId: staffId,
        staffName: staffName,
      ),
    );

    if (result == true && context.mounted) {
      // 全注文をcompletedに更新
      for (var order in orders) {
        await firebaseService.updateOrderStatus(order.id, OrderStatus.completed);
      }

      // テーブル結合を解除（groupIdがある場合）
      if (table.groupId != null) {
        // 同じグループの全テーブルのgroupIdを削除
        final groupSnapshot = await FirebaseFirestore.instance
            .collection('tables')
            .where('groupId', isEqualTo: table.groupId)
            .get();

        for (var doc in groupSnapshot.docs) {
          await doc.reference.update({
            'groupId': FieldValue.delete(),
            'status': 'available',
            'sessionStartedAt': FieldValue.delete(),
            'updatedAt': Timestamp.now(),
          });
        }
      } else {
        // テーブルを空席に戻す
        await firebaseService.updateTableStatus(table.id, TableStatus.available);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.text('paymentCompleted')),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}

