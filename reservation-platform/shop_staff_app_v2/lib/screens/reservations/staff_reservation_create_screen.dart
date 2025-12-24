import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/table.dart';
import '../../models/menu.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';

/// スタッフによる予約作成画面
class StaffReservationCreateScreen extends ConsumerStatefulWidget {
  final DateTime initialDate;

  const StaffReservationCreateScreen({
    super.key,
    required this.initialDate,
  });

  @override
  ConsumerState<StaffReservationCreateScreen> createState() =>
      _StaffReservationCreateScreenState();
}

class _StaffReservationCreateScreenState
    extends ConsumerState<StaffReservationCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  // 入力フィールド
  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;
  int _numberOfPeople = 1;
  String? _selectedMenuId;
  String? _selectedTableId;
  SeatType? _selectedSeatType;
  List<String> _selectedFeatures = [];

  // 顧客情報
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();

  // 既存顧客データ
  List<Map<String, dynamic>> _existingCustomers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  Map<String, dynamic>? _selectedCustomer;
  bool _isSearching = false;

  // データ
  List<Menu> _menus = [];
  List<TableModel> _tables = [];
  List<TableModel> _availableTables = [];
  bool _isLoading = false;
  bool _isCheckingAvailability = false;

  // 空き状況
  Map<String, bool> _timeSlotAvailability = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) return;

    setState(() => _isLoading = true);

    try {
      // メニュー取得
      final menuSnapshot = await _firestore
          .collection('menus')
          .where('shopId', isEqualTo: staffUser.shopId)
          .where('isActive', isEqualTo: true)
          .where('isReservationMenu', isEqualTo: true)
          .get();

      _menus = menuSnapshot.docs.map((doc) => Menu.fromFirestore(doc)).toList();

      // テーブル取得
      final tableSnapshot = await _firestore
          .collection('tables')
          .where('shopId', isEqualTo: staffUser.shopId)
          .where('isActive', isEqualTo: true)
          .orderBy('tableNumber')
          .get();

      _tables = tableSnapshot.docs.map((doc) => TableModel.fromFirestore(doc)).toList();

      // 既存顧客を予約履歴から取得
      await _loadExistingCustomers(staffUser.shopId);
    } catch (e) {
      debugPrint('データ読み込みエラー: $e');
    }

    setState(() => _isLoading = false);
  }

  /// 既存顧客を予約履歴から取得
  Future<void> _loadExistingCustomers(String shopId) async {
    try {
      final reservationSnapshot = await _firestore
          .collection('reservations')
          .where('shopId', isEqualTo: shopId)
          .orderBy('createdAt', descending: true)
          .limit(500) // 最新500件から顧客を抽出
          .get();

      // 電話番号でグループ化（重複排除）
      final customerMap = <String, Map<String, dynamic>>{};

      for (var doc in reservationSnapshot.docs) {
        final data = doc.data();
        final phone = data['userPhone'] as String? ?? '';
        final userId = data['userId'] as String?;

        // 電話番号が空の場合はスキップ
        if (phone.isEmpty) continue;

        // まだ登録されていない顧客のみ追加
        if (!customerMap.containsKey(phone)) {
          customerMap[phone] = {
            'userId': userId,
            'userName': data['userName'] ?? '',
            'userPhone': phone,
            'userEmail': data['userEmail'] ?? '',
            'userLineId': data['userLineId'],
            'lastReservationDate': (data['reservationDate'] as Timestamp?)?.toDate(),
            'reservationCount': 1,
          };
        } else {
          // 予約回数をインクリメント
          customerMap[phone]!['reservationCount'] =
              (customerMap[phone]!['reservationCount'] as int) + 1;

          // userLineIdが無い場合は更新
          if (customerMap[phone]!['userLineId'] == null && data['userLineId'] != null) {
            customerMap[phone]!['userLineId'] = data['userLineId'];
          }
          // userIdが'walk-in'でない場合は更新
          if ((customerMap[phone]!['userId'] == 'walk-in' || customerMap[phone]!['userId'] == null)
              && userId != null && userId != 'walk-in') {
            customerMap[phone]!['userId'] = userId;
          }
        }
      }

      _existingCustomers = customerMap.values.toList();
      // 予約回数の多い順にソート
      _existingCustomers.sort((a, b) =>
          (b['reservationCount'] as int).compareTo(a['reservationCount'] as int));

      debugPrint('既存顧客数: ${_existingCustomers.length}');
    } catch (e) {
      debugPrint('顧客データ読み込みエラー: $e');
    }
  }

  /// 顧客を検索
  void _searchCustomers(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredCustomers = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final normalizedQuery = query.replaceAll(RegExp(r'[- ]'), '').toLowerCase();

    final filtered = _existingCustomers.where((customer) {
      final phone = (customer['userPhone'] as String).replaceAll(RegExp(r'[- ]'), '');
      final name = (customer['userName'] as String).toLowerCase();

      // 電話番号の下4桁でマッチ
      if (normalizedQuery.length >= 3 && phone.endsWith(normalizedQuery)) {
        return true;
      }
      // 電話番号に含まれる
      if (phone.contains(normalizedQuery)) {
        return true;
      }
      // 名前に含まれる
      if (name.contains(normalizedQuery)) {
        return true;
      }
      return false;
    }).toList();

    setState(() {
      _filteredCustomers = filtered;
    });
  }

  /// 顧客を選択してフォームに反映
  void _selectCustomer(Map<String, dynamic> customer) {
    setState(() {
      _selectedCustomer = customer;
      _nameController.text = customer['userName'] ?? '';
      _phoneController.text = customer['userPhone'] ?? '';
      _emailController.text = customer['userEmail'] ?? '';
      _searchController.clear();
      _filteredCustomers = [];
      _isSearching = false;
    });
  }

  /// 顧客選択をクリア
  void _clearSelectedCustomer() {
    setState(() {
      _selectedCustomer = null;
      _nameController.clear();
      _phoneController.clear();
      _emailController.clear();
    });
  }

  /// 選択した日時・人数で空いているテーブルをチェック
  Future<void> _checkAvailability() async {
    if (_selectedTime == null) return;

    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) return;

    setState(() => _isCheckingAvailability = true);

    try {
      final selectedDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // 選択時間帯の既存予約を取得
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final reservationSnapshot = await _firestore
          .collection('reservations')
          .where('shopId', isEqualTo: staffUser.shopId)
          .where('reservationDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('reservationDate', isLessThan: Timestamp.fromDate(endOfDay))
          .where('status', whereIn: ['pending', 'confirmed'])
          .get();

      // 予約済みテーブルIDを取得
      final reservedTableIds = <String>{};
      final selectedTimeStr = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

      for (var doc in reservationSnapshot.docs) {
        final data = doc.data();
        final startTime = data['startTime'] as String;
        final endTime = data['endTime'] as String;

        // 時間帯が重なるかチェック
        if (_isTimeOverlapping(selectedTimeStr, startTime, endTime)) {
          final tableIds = data['tableIds'] as List<dynamic>?;
          if (tableIds != null) {
            reservedTableIds.addAll(tableIds.cast<String>());
          }
          final tableId = data['tableId'] as String?;
          if (tableId != null) {
            reservedTableIds.add(tableId);
          }
        }
      }

      // 利用可能なテーブルをフィルタ
      _availableTables = _tables.where((table) {
        // 予約済みは除外
        if (reservedTableIds.contains(table.id)) return false;
        // 人数チェック
        if (table.maxCapacity < _numberOfPeople) return false;
        // 席種別チェック（SeatType enumで比較）
        if (_selectedSeatType != null && table.seatType != _selectedSeatType) return false;
        // 特徴チェック
        if (_selectedFeatures.isNotEmpty) {
          final tableFeatures = table.features ?? [];
          if (!_selectedFeatures.every((f) => tableFeatures.contains(f))) return false;
        }
        return true;
      }).toList();

      // 時間帯の空き状況を更新
      _timeSlotAvailability = {};
      for (var hour = 10; hour <= 22; hour++) {
        for (var minute in [0, 30]) {
          final timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
          bool hasAvailable = false;

          for (var table in _tables) {
            if (table.maxCapacity >= _numberOfPeople) {
              bool isReserved = false;
              for (var doc in reservationSnapshot.docs) {
                final data = doc.data();
                final startTime = data['startTime'] as String;
                final endTime = data['endTime'] as String;
                final tableIds = data['tableIds'] as List<dynamic>?;
                final tableId = data['tableId'] as String?;

                if ((tableIds?.contains(table.id) ?? false) || tableId == table.id) {
                  if (_isTimeOverlapping(timeStr, startTime, endTime)) {
                    isReserved = true;
                    break;
                  }
                }
              }
              if (!isReserved) {
                hasAvailable = true;
                break;
              }
            }
          }
          _timeSlotAvailability[timeStr] = hasAvailable;
        }
      }
    } catch (e) {
      debugPrint('空き状況チェックエラー: $e');
    }

    setState(() => _isCheckingAvailability = false);
  }

  bool _isTimeOverlapping(String checkTime, String startTime, String endTime) {
    final check = _parseTime(checkTime);
    final start = _parseTime(startTime);
    final end = _parseTime(endTime);

    // チェック時間から2時間後までの範囲と予約時間が重なるかチェック
    final checkEnd = check + 120; // 2時間後
    return !(checkEnd <= start || check >= end);
  }

  int _parseTime(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  Future<void> _createReservation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('時間を選択してください'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_selectedMenuId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メニューを選択してください'), backgroundColor: Colors.orange),
      );
      return;
    }

    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) return;

    setState(() => _isLoading = true);

    try {
      final selectedMenu = _menus.firstWhere((m) => m.id == _selectedMenuId);
      final startTimeStr = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

      // 終了時間を計算（メニューの所要時間または2時間）
      final duration = selectedMenu.duration ?? 120;
      final endTime = TimeOfDay(
        hour: (_selectedTime!.hour + duration ~/ 60) % 24,
        minute: (_selectedTime!.minute + duration % 60) % 60,
      );
      final endTimeStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

      final reservationDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // 既存顧客の場合はuserId/userLineIdを使用
      final userId = _selectedCustomer?['userId'] ?? 'walk-in';
      final userLineId = _selectedCustomer?['userLineId'];

      // 予約データ作成
      final reservationData = <String, dynamic>{
        'shopId': staffUser.shopId,
        'userId': userId,
        'userName': _nameController.text,
        'userPhone': _phoneController.text,
        'userEmail': _emailController.text.isNotEmpty ? _emailController.text : null,
        'menuId': _selectedMenuId,
        'menuName': selectedMenu.name,
        'menuPrice': selectedMenu.price,
        'reservationDate': Timestamp.fromDate(reservationDate),
        'startTime': startTimeStr,
        'endTime': endTimeStr,
        'duration': duration,
        'numberOfPeople': _numberOfPeople,
        'totalPrice': selectedMenu.price,
        'status': 'confirmed', // スタッフが作成した予約は即確定
        'notes': _notesController.text.isNotEmpty ? _notesController.text : null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': staffUser.id,
        'createdByName': staffUser.name,
        'createdByType': 'staff', // スタッフが作成
      };

      // LINE ID（確認メッセージ送信用）
      if (userLineId != null) {
        reservationData['userLineId'] = userLineId;
      }

      // 席種別・希望条件
      if (_selectedSeatType != null) {
        reservationData['seatType'] = _seatTypeToString(_selectedSeatType!);
      }
      if (_selectedFeatures.isNotEmpty) {
        reservationData['requestedFeatures'] = _selectedFeatures;
      }

      // テーブル割当
      if (_selectedTableId != null) {
        reservationData['tableId'] = _selectedTableId;
        reservationData['tableIds'] = [_selectedTableId];
        reservationData['isCombined'] = false;

        // テーブルを予約済みに更新
        await _firestore.collection('tables').doc(_selectedTableId).update({
          'status': 'reserved',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await _firestore.collection('reservations').add(reservationData);

      if (mounted) {
        String message;
        if (userLineId != null) {
          message = '予約を作成しました\n確認メッセージをLINEに送信します';
        } else if (userId != 'walk-in' && _phoneController.text.isNotEmpty) {
          message = '予約を作成しました\n確認メッセージをSMSに送信します';
        } else {
          message = '予約を作成しました';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationProvider);
    final dateFormat = DateFormat('yyyy/MM/dd (E)', 'ja_JP');

    return Scaffold(
      appBar: AppBar(
        title: Text(t.text('newReservation')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 日付選択
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('予約日'),
                      subtitle: Text(dateFormat.format(_selectedDate)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() => _selectedDate = date);
                          _checkAvailability();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 人数選択
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('人数', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                onPressed: _numberOfPeople > 1
                                    ? () {
                                        setState(() => _numberOfPeople--);
                                        _checkAvailability();
                                      }
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  '$_numberOfPeople名',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() => _numberOfPeople++);
                                  _checkAvailability();
                                },
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 時間選択
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('時間', style: TextStyle(fontWeight: FontWeight.bold)),
                              const Spacer(),
                              if (_isCheckingAvailability)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var hour = 10; hour <= 22; hour++)
                                for (var minute in [0, 30])
                                  _buildTimeChip(hour, minute),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // メニュー選択
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('メニュー', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (_menus.isEmpty)
                            const Text('予約可能なメニューがありません', style: TextStyle(color: Colors.grey))
                          else
                            DropdownButtonFormField<String>(
                              value: _selectedMenuId,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'メニューを選択',
                              ),
                              items: _menus.map((menu) {
                                return DropdownMenuItem(
                                  value: menu.id,
                                  child: Text('${menu.name} (¥${menu.price})'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedMenuId = value);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 席種別選択（任意）
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('席種別（任意）', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _getAvailableSeatTypes().map((type) {
                              final seatType = type['value'] as SeatType;
                              final label = type['label'] as String;
                              final isSelected = _selectedSeatType == seatType;
                              return FilterChip(
                                label: Text(label),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedSeatType = selected ? seatType : null;
                                  });
                                  _checkAvailability();
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // テーブル選択（時間選択後）
                  if (_selectedTime != null && _availableTables.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('テーブル', style: TextStyle(fontWeight: FontWeight.bold)),
                                const Spacer(),
                                Text(
                                  '${_availableTables.length}席空き',
                                  style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _availableTables.map((table) {
                                final isSelected = _selectedTableId == table.id;
                                return FilterChip(
                                  label: Text('${table.displayName} (${table.minCapacity}-${table.maxCapacity}名)'),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedTableId = selected ? table.id : null;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // 顧客検索・情報入力
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_search, size: 20),
                              const SizedBox(width: 8),
                              const Text('お客様情報', style: TextStyle(fontWeight: FontWeight.bold)),
                              const Spacer(),
                              if (_existingCustomers.isNotEmpty)
                                Text(
                                  '登録顧客: ${_existingCustomers.length}名',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 顧客検索フィールド
                          TextFormField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: '顧客検索（電話番号下4桁・名前）',
                              hintText: '例: 1234 または 田中',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        _searchCustomers('');
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: _searchCustomers,
                          ),

                          // 検索結果リスト
                          if (_isSearching && _filteredCustomers.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              constraints: const BoxConstraints(maxHeight: 200),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: _filteredCustomers.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final customer = _filteredCustomers[index];
                                  final hasLine = customer['userLineId'] != null;
                                  final hasSms = !hasLine && customer['userId'] != null && customer['userId'] != 'walk-in';
                                  return ListTile(
                                    dense: true,
                                    leading: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: hasLine
                                          ? Colors.green.shade100
                                          : hasSms
                                              ? Colors.blue.shade100
                                              : Colors.grey.shade200,
                                      child: Icon(
                                        hasLine ? Icons.chat : hasSms ? Icons.sms : Icons.person,
                                        size: 18,
                                        color: hasLine ? Colors.green : hasSms ? Colors.blue : Colors.grey,
                                      ),
                                    ),
                                    title: Text(
                                      customer['userName'] ?? '名前なし',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    subtitle: Text(
                                      '${customer['userPhone']} • 来店${customer['reservationCount']}回',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    trailing: hasLine
                                        ? const Tooltip(
                                            message: 'LINE連携済み',
                                            child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                                          )
                                        : hasSms
                                            ? const Tooltip(
                                                message: 'SMS連携済み',
                                                child: Icon(Icons.check_circle, color: Colors.blue, size: 20),
                                              )
                                            : null,
                                    onTap: () => _selectCustomer(customer),
                                  );
                                },
                              ),
                            ),

                          // 検索結果なし
                          if (_isSearching && _filteredCustomers.isEmpty && _searchController.text.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
                                  const SizedBox(width: 8),
                                  Text(
                                    '該当する顧客が見つかりません（新規登録）',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),

                          // 選択された顧客表示
                          if (_selectedCustomer != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.blue, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '既存顧客: ${_selectedCustomer!['userName']}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          '${_selectedCustomer!['userPhone']} • 来店${_selectedCustomer!['reservationCount']}回',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                        ),
                                        if (_selectedCustomer!['userLineId'] != null)
                                          Row(
                                            children: [
                                              Icon(Icons.chat, size: 14, color: Colors.green.shade700),
                                              const SizedBox(width: 4),
                                              Text(
                                                'LINE連携済み（確認メッセージを自動送信）',
                                                style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                                              ),
                                            ],
                                          )
                                        else if (_selectedCustomer!['userId'] != null &&
                                                 _selectedCustomer!['userId'] != 'walk-in')
                                          Row(
                                            children: [
                                              Icon(Icons.sms, size: 14, color: Colors.blue.shade700),
                                              const SizedBox(width: 4),
                                              Text(
                                                'SMS連携済み（確認メッセージを自動送信）',
                                                style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: _clearSelectedCustomer,
                                    tooltip: '選択解除',
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),

                          // お客様情報入力フィールド
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'お名前 *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'お名前を入力してください';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: '電話番号 *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '電話番号を入力してください';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'メールアドレス（任意）',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: '備考（任意）',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.note),
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 予約確定ボタン
                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _createReservation,
                      icon: const Icon(Icons.check),
                      label: const Text('予約を確定する', style: TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildTimeChip(int hour, int minute) {
    final timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    final isSelected = _selectedTime?.hour == hour && _selectedTime?.minute == minute;
    final isAvailable = _timeSlotAvailability[timeStr] ?? true;

    return FilterChip(
      label: Text(timeStr),
      selected: isSelected,
      backgroundColor: isAvailable ? null : Colors.grey.shade300,
      labelStyle: TextStyle(
        color: isAvailable ? null : Colors.grey.shade500,
      ),
      onSelected: isAvailable
          ? (selected) {
              setState(() {
                _selectedTime = selected ? TimeOfDay(hour: hour, minute: minute) : null;
              });
              if (selected) {
                _checkAvailability();
              }
            }
          : null,
    );
  }

  List<Map<String, dynamic>> _getAvailableSeatTypes() {
    final seatTypes = <SeatType>{};
    for (var table in _tables) {
      seatTypes.add(table.seatType);
    }

    return seatTypes.map((type) {
      return {
        'value': type,
        'label': _getSeatTypeLabel(type),
      };
    }).toList();
  }

  String _getSeatTypeLabel(SeatType type) {
    switch (type) {
      case SeatType.counter:
        return 'カウンター';
      case SeatType.table:
        return 'テーブル席';
      case SeatType.privateRoom:
        return '個室';
      case SeatType.semiPrivate:
        return '半個室';
      case SeatType.tatami:
        return '座敷';
      case SeatType.terrace:
        return 'テラス';
      case SeatType.other:
        return 'その他';
    }
  }

  String _seatTypeToString(SeatType type) {
    switch (type) {
      case SeatType.counter:
        return 'counter';
      case SeatType.table:
        return 'table';
      case SeatType.privateRoom:
        return 'privateRoom';
      case SeatType.semiPrivate:
        return 'semiPrivate';
      case SeatType.tatami:
        return 'tatami';
      case SeatType.terrace:
        return 'terrace';
      case SeatType.other:
        return 'other';
    }
  }
}
