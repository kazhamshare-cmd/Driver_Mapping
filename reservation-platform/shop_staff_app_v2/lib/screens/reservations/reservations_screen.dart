import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../models/reservation.dart';
import '../../models/table.dart';
import '../../providers/reservation_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/auth_provider.dart' show staffUserProvider;
import '../../providers/shift_provider.dart';
import '../../services/reservation_service.dart';
import '../../services/table_service.dart';
import 'staff_reservation_create_screen.dart';
import 'reservation_blocks_screen.dart';
import 'widgets/gantt_chart_view.dart';
import 'widgets/staff_filter_bar.dart';
import '../sessions/check_in_dialog.dart';
import '../sessions/session_detail_screen.dart';

class ReservationsScreen extends ConsumerStatefulWidget {
  const ReservationsScreen({super.key});

  @override
  ConsumerState<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends ConsumerState<ReservationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ReservationService _reservationService = ReservationService();
  final TableService _tableService = TableService();

  // カレンダー用
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = ref.watch(pendingReservationCountProvider).value ?? 0;
    final t = ref.watch(translationProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: Text(t.text('reservationManagement')),
        actions: [
          IconButton(
            icon: const Icon(Icons.block),
            tooltip: '予約ブロック',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReservationBlocksScreen(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month, size: 18),
                  const SizedBox(width: 4),
                  Text(t.text('calendar')),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.view_timeline, size: 18),
                  const SizedBox(width: 4),
                  Text(t.text('ganttChart')),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.text('reservationPending')),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCalendarView(),
          GanttChartView(
            onReservationTap: _showReservationDetail,
          ),
          _buildPendingReservations(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateReservation(),
        icon: const Icon(Icons.add),
        label: Text(t.text('newReservation')),
        backgroundColor: Colors.blue,
      ),
    );
  }

  /// カレンダー表示
  Widget _buildCalendarView() {
    final reservationsAsync = ref.watch(reservationsProvider);
    final filteredReservations = ref.watch(filteredReservationsProvider);
    final t = ref.read(translationProvider);

    return reservationsAsync.when(
      data: (reservations) {
        // 日付ごとの予約をグループ化
        final Map<DateTime, List<Reservation>> reservationsByDate = {};
        for (var r in reservations) {
          final date = DateTime(
            r.reservationDate.year,
            r.reservationDate.month,
            r.reservationDate.day,
          );
          reservationsByDate.putIfAbsent(date, () => []).add(r);
        }

        // フィルター適用済みの選択日予約（ロールベースでフィルター済み）
        final selectedDayReservations = [...filteredReservations];
        // 時間順にソート
        selectedDayReservations.sort((a, b) => a.startTime.compareTo(b.startTime));

        return Column(
          children: [
            // スタッフフィルターバー（マネージャー/オーナーのみ表示）
            const StaffFilterBar(),
            // カレンダー
            TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: _calendarFormat,
              startingDayOfWeek: StartingDayOfWeek.monday,
              locale: 'ja_JP',
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                formatButtonDecoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.blue.shade200,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              eventLoader: (day) {
                final key = DateTime(day.year, day.month, day.day);
                return reservationsByDate[key] ?? [];
              },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return null;
                  final reservationList = events.cast<Reservation>();
                  final pendingCount = reservationList.where((r) => r.status == ReservationStatus.pending).length;
                  final confirmedCount = reservationList.where((r) => r.status == ReservationStatus.confirmed).length;

                  return Positioned(
                    bottom: 1,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (pendingCount > 0)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (confirmedCount > 0)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                // プロバイダーも更新（ガントチャートと連携）
                ref.read(selectedDateProvider.notifier).state = selectedDay;
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
            ),
            const Divider(height: 1),

            // 選択日の予約リスト
            Expanded(
              child: selectedDayReservations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_available, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            t.text('noReservationsForDate'),
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _openCreateReservation(date: _selectedDay),
                            icon: const Icon(Icons.add),
                            label: Text(t.text('createReservation')),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: selectedDayReservations.length,
                      itemBuilder: (context, index) {
                        final reservation = selectedDayReservations[index];
                        return _buildReservationCard(reservation, showActions: reservation.status == ReservationStatus.pending);
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('${t.text('errorOccurred')}: $error'),
      ),
    );
  }

  Widget _buildPendingReservations() {
    final reservationsAsync = ref.watch(pendingReservationsProvider);
    final t = ref.read(translationProvider);

    return reservationsAsync.when(
      data: (reservations) {
        if (reservations.isEmpty) {
          return _buildEmptyState(Icons.event_available, t.text('noPendingReservations'));
        }

        return _buildReservationList(reservations, showActions: true);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('${t.text('errorOccurred')}: $error'),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: isTablet ? 80 : 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey, fontSize: isTablet ? 18 : 16),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationList(List<Reservation> reservations, {bool showActions = false}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    if (isTablet) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: screenWidth > 900 ? 3 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: showActions ? 0.95 : 1.1,
        ),
        itemCount: reservations.length,
        itemBuilder: (context, index) {
          final reservation = reservations[index];
          return _buildReservationCard(reservation, showActions: showActions, isTablet: true);
        },
      );
    }

    return ListView.builder(
      itemCount: reservations.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final reservation = reservations[index];
        return _buildReservationCard(reservation, showActions: showActions);
      },
    );
  }

  Widget _buildReservationCard(Reservation reservation,
      {bool showActions = false, bool isTablet = false}) {
    final dateFormat = DateFormat('yyyy/MM/dd (E)', 'ja_JP');
    final cardPadding = isTablet ? 20.0 : 16.0;
    final iconSize = isTablet ? 22.0 : 20.0;
    final dateStr = dateFormat.format(reservation.reservationDate);

    Color statusColor;
    IconData statusIcon;

    switch (reservation.status) {
      case ReservationStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case ReservationStatus.confirmed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case ReservationStatus.cancelled:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case ReservationStatus.completed:
        statusColor = Colors.blue;
        statusIcon = Icons.done_all;
        break;
      case ReservationStatus.noShow:
        statusColor = Colors.grey;
        statusIcon = Icons.person_off;
        break;
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 0 : 8, vertical: isTablet ? 0 : 4),
      child: InkWell(
        onTap: () => _showReservationDetail(reservation),
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ステータスバッジ
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: iconSize),
                  const SizedBox(width: 4),
                  Text(
                    reservation.status.label,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (reservation.numberOfPeople != null)
                    Chip(
                      label: Text('${reservation.numberOfPeople}名'),
                      backgroundColor: Colors.grey.shade200,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // 時間（大きく表示）
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      reservation.startTime,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '〜 ${reservation.endTime}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 顧客情報
              Row(
                children: [
                  const Icon(Icons.person, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reservation.userName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // 電話番号
              Row(
                children: [
                  const Icon(Icons.phone, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    reservation.userPhone,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // メニュー名
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  reservation.menuName,
                  style: TextStyle(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // 席種別・希望条件
              if (reservation.seatType != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    Chip(
                      label: Text(reservation.seatTypeName),
                      backgroundColor: Colors.purple.shade50,
                      labelStyle: TextStyle(
                        color: Colors.purple.shade900,
                        fontSize: 12,
                      ),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    ...reservation.requestedFeatureNames.map((f) => Chip(
                          label: Text(f),
                          backgroundColor: Colors.teal.shade50,
                          labelStyle: TextStyle(
                            color: Colors.teal.shade900,
                            fontSize: 12,
                          ),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        )),
                  ],
                ),
              ],

              // テーブル割当状況
              if (reservation.tableIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.table_restaurant,
                          size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reservation.isCombined
                              ? '結合: ${reservation.tableIds.length}テーブル'
                              : '割当済み',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (reservation.status == ReservationStatus.pending ||
                  reservation.status == ReservationStatus.confirmed) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.table_restaurant,
                          size: 16, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'テーブル未割当',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // メモ
              if (reservation.notes != null && reservation.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.yellow.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.note, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reservation.notes!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // アクションボタン（承認待ちの場合のみ）
              if (showActions &&
                  reservation.status == ReservationStatus.pending) ...[
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final t = ref.read(translationProvider);
                    return Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _cancelReservation(reservation),
                            icon: const Icon(Icons.cancel, size: 18),
                            label: Text(t.text('reject')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () => _approveReservation(reservation),
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: Text(t.text('approve')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],

              // 確定済み予約のアクションボタン
              if (reservation.status == ReservationStatus.confirmed) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    // キャンセルボタン
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _cancelConfirmedReservation(reservation),
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('キャンセル'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    // 来店ボタン（当日の場合のみ）
                    if (_isToday(reservation.reservationDate)) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => _showCheckInDialog(reservation),
                          icon: const Icon(Icons.login, size: 18),
                          label: const Text('来店'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showReservationDetail(Reservation reservation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return _buildReservationDetailSheet(reservation, scrollController);
        },
      ),
    );
  }

  Widget _buildReservationDetailSheet(
      Reservation reservation, ScrollController scrollController) {
    final dateFormat = DateFormat('yyyy/MM/dd (E)', 'ja_JP');
    final dateStr = dateFormat.format(reservation.reservationDate);
    final t = ref.read(translationProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        controller: scrollController,
        children: [
          // ハンドル
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // タイトル
          Text(
            t.text('reservationDetails'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),

          // ステータス
          _buildDetailRow(
            icon: Icons.info,
            label: t.text('status'),
            value: reservation.status.label,
          ),
          const Divider(),

          // 日時
          _buildDetailRow(
            icon: Icons.calendar_today,
            label: t.text('reservationDate'),
            value: dateStr,
          ),
          const Divider(),

          _buildDetailRow(
            icon: Icons.access_time,
            label: t.text('time'),
            value: '${reservation.startTime} - ${reservation.endTime}',
          ),
          const Divider(),

          // 顧客情報
          _buildDetailRow(
            icon: Icons.person,
            label: t.text('customerName'),
            value: reservation.userName,
          ),
          const Divider(),

          _buildDetailRow(
            icon: Icons.phone,
            label: t.text('customerPhone'),
            value: reservation.userPhone,
          ),
          const Divider(),

          _buildDetailRow(
            icon: Icons.email,
            label: t.text('customerEmail'),
            value: reservation.userEmail,
          ),
          const Divider(),

          // 連絡ボタン
          const SizedBox(height: 8),
          _buildContactButtons(reservation),
          const SizedBox(height: 8),
          const Divider(),

          // 人数
          if (reservation.numberOfPeople != null) ...[
            _buildDetailRow(
              icon: Icons.groups,
              label: t.text('numberOfPeople'),
              value: '${reservation.numberOfPeople}${t.text('people')}',
            ),
            const Divider(),
          ],

          // メニュー
          _buildDetailRow(
            icon: Icons.restaurant_menu,
            label: t.text('menu'),
            value: reservation.menuName,
          ),
          const Divider(),

          // 料金
          _buildDetailRow(
            icon: Icons.payments,
            label: t.text('fee'),
            value: '¥${reservation.totalPrice.toStringAsFixed(0)}',
          ),
          const Divider(),

          // メモ
          if (reservation.notes != null && reservation.notes!.isNotEmpty) ...[
            _buildDetailRow(
              icon: Icons.note,
              label: t.text('notes'),
              value: reservation.notes!,
            ),
            const Divider(),
          ],

          // スタッフ
          if (reservation.staffName != null) ...[
            _buildDetailRow(
              icon: Icons.person_pin,
              label: t.text('assignedStaff'),
              value: reservation.staffName!,
            ),
            const Divider(),
          ],

          // 席種別
          if (reservation.seatType != null) ...[
            _buildDetailRow(
              icon: Icons.event_seat,
              label: '希望席種別',
              value: reservation.seatTypeName,
            ),
            const Divider(),
          ],

          // 希望条件
          if (reservation.requestedFeatures.isNotEmpty) ...[
            _buildDetailRow(
              icon: Icons.checklist,
              label: '希望条件',
              value: reservation.requestedFeatureNames.join('、'),
            ),
            const Divider(),
          ],

          // テーブル割当状況
          _buildDetailRow(
            icon: Icons.table_restaurant,
            label: 'テーブル',
            value: reservation.tableIds.isNotEmpty
                ? (reservation.isCombined
                    ? '結合（${reservation.tableIds.length}テーブル）'
                    : '割当済み')
                : '未割当',
          ),
          const Divider(),

          const SizedBox(height: 24),

          // テーブル割当ボタン（承認待ちまたは確定済みの場合）
          if (reservation.status == ReservationStatus.pending ||
              reservation.status == ReservationStatus.confirmed) ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showTableAssignmentDialog(reservation);
              },
              icon: const Icon(Icons.table_restaurant),
              label: Text(reservation.tableIds.isNotEmpty
                  ? 'テーブル割当を変更'
                  : 'テーブルを割り当てる'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // アクションボタン
          if (reservation.status == ReservationStatus.pending) ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _approveReservation(reservation);
              },
              icon: const Icon(Icons.check_circle),
              label: Text(t.text('approve')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _cancelReservation(reservation);
              },
              icon: const Icon(Icons.cancel),
              label: Text(t.text('reject')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],

          if (reservation.status == ReservationStatus.confirmed) ...[
            // 来店ボタン（当日のみ）
            if (_isToday(reservation.reservationDate)) ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showCheckInDialog(reservation);
                },
                icon: const Icon(Icons.login),
                label: const Text('来店開始'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 8),
            ],
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _completeReservation(reservation);
              },
              icon: const Icon(Icons.done_all),
              label: Text(t.text('markCompleted')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _markAsNoShow(reservation);
              },
              icon: const Icon(Icons.person_off),
              label: Text(t.text('reservationNoShow')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 8),
            // 店舗側からのキャンセルボタン
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _cancelConfirmedReservation(reservation);
              },
              icon: const Icon(Icons.cancel),
              label: const Text('予約をキャンセル'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 新規予約作成画面を開く
  void _openCreateReservation({DateTime? date}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StaffReservationCreateScreen(
          initialDate: date ?? _selectedDay,
        ),
      ),
    );
  }

  Future<void> _approveReservation(Reservation reservation) async {
    final t = ref.read(translationProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.text('approveReservationTitle')),
        content: Text('${reservation.userName}${t.text('approveReservationConfirm')}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.text('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(t.text('approve')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _reservationService.approveReservation(reservation.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t.text('reservationApproveSuccess')),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${t.text('errorOccurred')}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _cancelReservation(Reservation reservation) async {
    final t = ref.read(translationProvider);
    final TextEditingController reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.text('rejectReservationTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${reservation.userName}${t.text('rejectReservationConfirm')}'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: t.text('rejectReason'),
                border: const OutlineInputBorder(),
                hintText: t.text('rejectReasonHint'),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.text('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(t.text('reject')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _reservationService.cancelReservation(
          reservation.id,
          reasonController.text.isNotEmpty ? reasonController.text : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t.text('reservationRejectSuccess')),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${t.text('errorOccurred')}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    reasonController.dispose();
  }

  Future<void> _completeReservation(Reservation reservation) async {
    final t = ref.read(translationProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.text('completeReservationTitle')),
        content: Text(t.text('completeReservationConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.text('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.text('markCompleted')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _reservationService.completeReservation(reservation.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t.text('reservationCompleteSuccess')),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${t.text('errorOccurred')}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _markAsNoShow(Reservation reservation) async {
    final t = ref.read(translationProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.text('noShowTitle')),
        content: Text(t.text('noShowConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.text('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
            ),
            child: Text(t.text('markNoShow')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _reservationService.markAsNoShow(reservation.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t.text('noShowSuccess')),
              backgroundColor: Colors.grey,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${t.text('errorOccurred')}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// 確定済み予約を店舗側からキャンセル
  Future<void> _cancelConfirmedReservation(Reservation reservation) async {
    final t = ref.read(translationProvider);
    final TextEditingController reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('予約キャンセル'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${reservation.userName}様の予約をキャンセルしますか？',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '※お客様にキャンセル通知が送信されます',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'キャンセル理由',
                border: OutlineInputBorder(),
                hintText: '例：店舗都合により',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.text('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('キャンセル実行'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _reservationService.cancelReservation(
          reservation.id,
          reasonController.text.isNotEmpty ? reasonController.text : '店舗都合によりキャンセル',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('予約をキャンセルしました'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${t.text('errorOccurred')}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    reasonController.dispose();
  }

  /// テーブル割当ダイアログを表示
  Future<void> _showTableAssignmentDialog(Reservation reservation) async {
    final staffUser = ref.read(staffUserProvider).value;
    final shopId = staffUser?.shopId;

    if (shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('店舗情報が取得できません'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // テーブル一覧を取得
    final tables = await _tableService.getTablesOnce(shopId);
    if (tables.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('テーブルが登録されていません'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // 推奨テーブルを取得
    List<TableModel> recommendedTables = [];
    if (reservation.numberOfPeople != null) {
      recommendedTables = await _tableService.getRecommendedTables(
        shopId: shopId,
        numberOfPeople: reservation.numberOfPeople!,
        seatType: reservation.seatType,
        requestedFeatures: reservation.requestedFeatures,
      );
    }

    // 選択されたテーブルID
    List<String> selectedTableIds = List.from(reservation.tableIds);

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ハンドル
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // タイトル
                    Text(
                      'テーブル割当',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),

                    // 予約情報
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person, size: 20),
                          const SizedBox(width: 8),
                          Text(reservation.userName),
                          const SizedBox(width: 16),
                          const Icon(Icons.groups, size: 20),
                          const SizedBox(width: 4),
                          Text('${reservation.numberOfPeople ?? '-'}名'),
                          if (reservation.seatType != null) ...[
                            const SizedBox(width: 16),
                            const Icon(Icons.event_seat, size: 20),
                            const SizedBox(width: 4),
                            Text(reservation.seatTypeName),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 推奨テーブル
                    if (recommendedTables.isNotEmpty) ...[
                      Text(
                        '推奨テーブル',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: recommendedTables.length,
                          itemBuilder: (context, index) {
                            final table = recommendedTables[index];
                            final isSelected =
                                selectedTableIds.contains(table.id);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    if (isSelected) {
                                      selectedTableIds.remove(table.id);
                                    } else {
                                      selectedTableIds.add(table.id);
                                    }
                                  });
                                },
                                child: Container(
                                  width: 100,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.green.shade100
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.green
                                          : Colors.grey.shade300,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        table.displayName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.green.shade900
                                              : null,
                                        ),
                                      ),
                                      Text(
                                        '${table.minCapacity}-${table.maxCapacity}名',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        table.seatTypeName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.purple.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 全テーブル
                    Text(
                      'すべてのテーブル',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: tables.length,
                        itemBuilder: (context, index) {
                          final table = tables[index];
                          final isSelected =
                              selectedTableIds.contains(table.id);
                          final isRecommended = recommendedTables
                              .any((t) => t.id == table.id);

                          return Card(
                            color: isSelected
                                ? Colors.green.shade50
                                : Colors.white,
                            child: ListTile(
                              leading: Icon(
                                Icons.table_restaurant,
                                color: isSelected
                                    ? Colors.green
                                    : Colors.grey.shade400,
                              ),
                              title: Row(
                                children: [
                                  Text(table.displayName),
                                  if (isRecommended) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '推奨',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                '${table.seatTypeName} / ${table.minCapacity}-${table.maxCapacity}名',
                              ),
                              trailing: Checkbox(
                                value: isSelected,
                                onChanged: (value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      selectedTableIds.add(table.id);
                                    } else {
                                      selectedTableIds.remove(table.id);
                                    }
                                  });
                                },
                              ),
                              onTap: () {
                                setDialogState(() {
                                  if (isSelected) {
                                    selectedTableIds.remove(table.id);
                                  } else {
                                    selectedTableIds.add(table.id);
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 確定ボタン
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('キャンセル'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: selectedTableIds.isEmpty
                                ? null
                                : () async {
                                    Navigator.pop(context);
                                    await _assignTables(
                                      reservation,
                                      selectedTableIds,
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              selectedTableIds.length > 1
                                  ? '${selectedTableIds.length}テーブルを割当（結合）'
                                  : 'テーブルを割当',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// テーブルを割り当てる
  Future<void> _assignTables(
    Reservation reservation,
    List<String> tableIds,
  ) async {
    try {
      await _reservationService.updateTableAssignment(
        reservation.id,
        tableIds: tableIds,
        isCombined: tableIds.length > 1,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tableIds.length > 1
                ? '${tableIds.length}テーブルを結合して割り当てました'
                : 'テーブルを割り当てました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 本日かどうかを判定
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// 来店ダイアログを表示
  void _showCheckInDialog(Reservation reservation) {
    showDialog(
      context: context,
      builder: (context) => CheckInDialog(reservation: reservation),
    ).then((sessionId) {
      if (sessionId != null && sessionId is String) {
        // セッション詳細画面に遷移
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SessionDetailScreen(sessionId: sessionId),
          ),
        );
      }
    });
  }

  /// 連絡ボタンを構築
  Widget _buildContactButtons(Reservation reservation) {
    final hasLineId = reservation.userLineId != null && reservation.userLineId!.isNotEmpty;
    final hasPhone = reservation.userPhone.isNotEmpty;

    return Row(
      children: [
        // LINE送信ボタン
        if (hasLineId)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showSendLineDialog(reservation),
              icon: const Icon(Icons.chat, size: 18),
              label: const Text('LINE送信'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06C755),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        if (hasLineId && hasPhone)
          const SizedBox(width: 8),
        // SMS送信ボタン（電話番号がある場合）
        if (hasPhone)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showSendSmsDialog(reservation),
              icon: const Icon(Icons.sms, size: 18),
              label: const Text('SMS送信'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        if (hasPhone)
          const SizedBox(width: 8),
        // 電話ボタン
        if (hasPhone)
          IconButton(
            onPressed: () => _makePhoneCall(reservation.userPhone),
            icon: const Icon(Icons.phone),
            tooltip: '電話をかける',
            style: IconButton.styleFrom(
              backgroundColor: Colors.green.shade100,
              foregroundColor: Colors.green.shade700,
            ),
          ),
      ],
    );
  }

  /// LINE送信ダイアログを表示
  Future<void> _showSendLineDialog(Reservation reservation) async {
    final TextEditingController messageController = TextEditingController();
    final dateFormat = DateFormat('yyyy/MM/dd', 'ja_JP');

    // デフォルトメッセージ
    messageController.text = '${reservation.userName}様\n\n'
        '${dateFormat.format(reservation.reservationDate)} ${reservation.startTime}からの'
        'ご予約についてご連絡いたします。\n\n';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.chat, color: Color(0xFF06C755)),
            SizedBox(width: 8),
            Text('LINEメッセージ送信'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '送信先: ${reservation.userName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'メッセージ',
                  border: OutlineInputBorder(),
                  hintText: 'メッセージを入力してください',
                ),
                maxLines: 6,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06C755),
              foregroundColor: Colors.white,
            ),
            child: const Text('送信'),
          ),
        ],
      ),
    );

    messageController.dispose();

    if (confirmed == true && messageController.text.isNotEmpty) {
      await _sendLineMessage(reservation, messageController.text);
    }
  }

  /// LINEメッセージを送信
  Future<void> _sendLineMessage(Reservation reservation, String message) async {
    try {
      // ローディング表示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('送信中...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast1');
      final callable = functions.httpsCallable('sendLineNotification');

      await callable.call({
        'shopId': reservation.shopId,
        'userLineId': reservation.userLineId,
        'messageType': 'custom',
        'customMessage': message,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('LINEメッセージを送信しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('送信エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// SMS送信ダイアログを表示
  Future<void> _showSendSmsDialog(Reservation reservation) async {
    final TextEditingController messageController = TextEditingController();
    final dateFormat = DateFormat('MM/dd', 'ja_JP');

    // デフォルトメッセージ（SMSは文字数制限があるため短め）
    messageController.text = '${reservation.userName}様 '
        '${dateFormat.format(reservation.reservationDate)} ${reservation.startTime}のご予約について連絡です。';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sms, color: Colors.blue),
            SizedBox(width: 8),
            Text('SMS送信'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '送信先: ${reservation.userPhone}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '※SMS送信には通信料がかかります',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'メッセージ',
                  border: OutlineInputBorder(),
                  hintText: 'メッセージを入力してください',
                  counterText: '',
                ),
                maxLines: 4,
                maxLength: 160,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('送信'),
          ),
        ],
      ),
    );

    if (confirmed == true && messageController.text.isNotEmpty) {
      await _sendSmsMessage(reservation, messageController.text);
    }

    messageController.dispose();
  }

  /// SMSメッセージを送信
  Future<void> _sendSmsMessage(Reservation reservation, String message) async {
    try {
      // ローディング表示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('送信中...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast1');
      final callable = functions.httpsCallable('sendSmsNotification');

      await callable.call({
        'shopId': reservation.shopId,
        'phoneNumber': reservation.userPhone,
        'message': message,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMSを送信しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('送信エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 電話をかける
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('電話をかけることができません'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
