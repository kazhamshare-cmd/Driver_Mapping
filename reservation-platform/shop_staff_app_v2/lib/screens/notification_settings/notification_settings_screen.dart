import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/notification_service.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<ProductCategory> _categories = [];
  Set<String> _selectedCategories = {};
  String? _errorMessage;

  // 通知音設定
  final NotificationService _notificationService = NotificationService();
  NotificationSoundType _selectedSoundType = NotificationSoundType.bell;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  // 予約通知設定
  // 'all' = すべての予約, 'myAppointments' = 自分の指名のみ, 'off' = 通知OFF
  String _reservationNotificationType = 'off';
  // true = 常時受信, false = 出勤中のみ
  bool _reservationAlwaysReceive = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// カテゴリと現在の設定を読み込み
  Future<void> _loadData() async {
    final t = ref.read(translationProvider);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final staffUser = await ref.read(staffUserProvider.future);
      final shop = await ref.read(shopProvider.future);

      if (staffUser == null || shop == null) {
        setState(() {
          _errorMessage = t.text('userInfoNotFound');
          _isLoading = false;
        });
        return;
      }

      final db = FirebaseFirestore.instance;

      // スタッフの現在の通知設定を取得
      final employeeDoc = await db.collection('employees').doc(staffUser.id).get();
      final notificationSettings =
          employeeDoc.data()?['notificationSettings'] as Map<String, dynamic>?;
      final currentCategories =
          (notificationSettings?['orderNotificationCategories'] as List?)
                  ?.cast<String>() ??
              [];

      // 予約通知設定を取得
      final reservationType = notificationSettings?['reservationNotificationType'] as String? ?? 'off';
      final alwaysReceive = notificationSettings?['reservationAlwaysReceive'] as bool? ?? false;

      debugPrint('🔔 現在の通知設定カテゴリ: $currentCategories');
      debugPrint('📅 予約通知タイプ: $reservationType, 常時受信: $alwaysReceive');

      // 店舗のカテゴリを取得
      final categoriesSnapshot = await db
          .collection('productCategories')
          .where('shopId', isEqualTo: shop.id)
          .orderBy('sortOrder')
          .get();

      final categories = categoriesSnapshot.docs
          .map((doc) => ProductCategory.fromFirestore(doc))
          .toList();

      debugPrint('📦 取得したカテゴリ数: ${categories.length}');

      // 通知音設定を読み込み
      await _notificationService.initialize();

      setState(() {
        _categories = categories;
        _selectedCategories = Set.from(currentCategories);
        _selectedSoundType = _notificationService.currentSoundType;
        _soundEnabled = _notificationService.soundEnabled;
        _vibrationEnabled = _notificationService.vibrationEnabled;
        _reservationNotificationType = reservationType;
        _reservationAlwaysReceive = alwaysReceive;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ データ読み込みエラー: $e');
      setState(() {
        _errorMessage = '${t.text('errorOccurred')}: $e';
        _isLoading = false;
      });
    }
  }

  /// 設定を保存
  Future<void> _saveSettings() async {
    final t = ref.read(translationProvider);
    final staffUser = await ref.read(staffUserProvider.future);
    if (staffUser == null) {
      _showSnackBar(t.text('userInfoNotFound'));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final db = FirebaseFirestore.instance;

      debugPrint('💾 通知設定を保存: ${_selectedCategories.toList()}');
      debugPrint('📅 予約通知設定を保存: タイプ=$_reservationNotificationType, 常時=$_reservationAlwaysReceive');

      await db.collection('employees').doc(staffUser.id).update({
        'notificationSettings.orderNotificationCategories':
            _selectedCategories.toList(),
        'notificationSettings.reservationNotificationType':
            _reservationNotificationType,
        'notificationSettings.reservationAlwaysReceive':
            _reservationAlwaysReceive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 通知音設定を保存
      await _notificationService.setSoundType(_selectedSoundType);
      await _notificationService.setSoundEnabled(_soundEnabled);
      await _notificationService.setVibrationEnabled(_vibrationEnabled);

      debugPrint('✅ 通知設定を保存しました');

      _showSnackBar(t.text('settingsSaved'));

      // ホーム画面に戻る
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      debugPrint('❌ 保存エラー: $e');
      _showSnackBar('${t.text('errorOccurred')}: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  /// 通知音選択ダイアログを表示
  void _showSoundSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.music_note, color: Colors.blue),
              SizedBox(width: 8),
              Text('通知音を選択'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: NotificationSoundType.values.map((type) {
                final isSelected = type == _selectedSoundType;
                return Card(
                  color: isSelected ? Colors.blue[50] : null,
                  elevation: isSelected ? 2 : 0,
                  child: ListTile(
                    leading: Icon(
                      _getSoundIcon(type),
                      color: isSelected ? Colors.blue : Colors.grey,
                    ),
                    title: Text(
                      type.displayName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      type.description,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_circle_outline),
                          color: Colors.green,
                          onPressed: () {
                            _notificationService.playPreview(type);
                          },
                          tooltip: '試聴',
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: Colors.blue),
                      ],
                    ),
                    onTap: () {
                      setState(() {
                        _selectedSoundType = type;
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  IconData _getSoundIcon(NotificationSoundType type) {
    switch (type) {
      case NotificationSoundType.chime:
        return Icons.music_note;
      case NotificationSoundType.bell:
        return Icons.notifications;
      case NotificationSoundType.alert:
        return Icons.warning_amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffUserAsync = ref.watch(staffUserProvider);
    final t = ref.watch(translationProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/');
          },
        ),
        title: Text(t.text('notificationSettingsTitle')),
      ),
      body: staffUserAsync.when(
        data: (staffUser) {
          if (staffUser == null) {
            return Center(child: Text(t.text('userInfoNotFound')));
          }

          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: Text(t.text('retry')),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 説明カード
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              t.text('orderNotifications'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• ${t.text('clockedIn')}',
                          style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // スタッフ情報と出勤状態
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${staffUser.lastName} ${staffUser.firstName}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: staffUser.isWorking ? Colors.green[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        staffUser.isWorking ? t.text('clockedIn') : t.text('clockedOut'),
                        style: TextStyle(
                          color: staffUser.isWorking ? Colors.green[900] : Colors.grey[700],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (!staffUser.isWorking)
                  Card(
                    color: Colors.orange[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.text('clockInRequired'),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // ===================
                // 予約通知設定セクション
                // ===================
                Text(
                  '📅 ${t.text('reservationNotificationSettings')}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.text('reservationNotificationDesc'),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),

                // 予約通知タイプ選択
                Card(
                  child: Column(
                    children: [
                      // すべての予約を受信
                      RadioListTile<String>(
                        value: 'all',
                        groupValue: _reservationNotificationType,
                        onChanged: (value) {
                          setState(() {
                            _reservationNotificationType = value!;
                          });
                        },
                        title: Text(t.text('receiveAllReservations')),
                        subtitle: Text(
                          t.text('receiveAllReservationsDesc'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        secondary: Icon(
                          Icons.notifications_active,
                          color: _reservationNotificationType == 'all'
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                      const Divider(height: 1),
                      // 自分の指名のみ
                      RadioListTile<String>(
                        value: 'myAppointments',
                        groupValue: _reservationNotificationType,
                        onChanged: (value) {
                          setState(() {
                            _reservationNotificationType = value!;
                          });
                        },
                        title: Text(t.text('receiveMyAppointments')),
                        subtitle: Text(
                          t.text('receiveMyAppointmentsDesc'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        secondary: Icon(
                          Icons.person,
                          color: _reservationNotificationType == 'myAppointments'
                              ? Colors.blue
                              : Colors.grey,
                        ),
                      ),
                      const Divider(height: 1),
                      // 通知OFF
                      RadioListTile<String>(
                        value: 'off',
                        groupValue: _reservationNotificationType,
                        onChanged: (value) {
                          setState(() {
                            _reservationNotificationType = value!;
                          });
                        },
                        title: Text(t.text('noReservationNotification')),
                        subtitle: Text(
                          t.text('noReservationNotificationDesc'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        secondary: Icon(
                          Icons.notifications_off,
                          color: _reservationNotificationType == 'off'
                              ? Colors.red
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                // 常時受信 / 出勤中のみ の選択（通知がOFF以外の場合のみ表示）
                if (_reservationNotificationType != 'off') ...[
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '注文通知は出勤中のみ受信しますが、予約通知は常時受信することもできます。',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        // 常時受信
                        RadioListTile<bool>(
                          value: true,
                          groupValue: _reservationAlwaysReceive,
                          onChanged: (value) {
                            setState(() {
                              _reservationAlwaysReceive = value!;
                            });
                          },
                          title: Text(t.text('alwaysReceive')),
                          subtitle: Text(
                            t.text('alwaysReceiveDesc'),
                            style: const TextStyle(fontSize: 12),
                          ),
                          secondary: Icon(
                            Icons.alarm_on,
                            color: _reservationAlwaysReceive
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                        const Divider(height: 1),
                        // 出勤中のみ
                        RadioListTile<bool>(
                          value: false,
                          groupValue: _reservationAlwaysReceive,
                          onChanged: (value) {
                            setState(() {
                              _reservationAlwaysReceive = value!;
                            });
                          },
                          title: Text(t.text('onlyWhenWorking')),
                          subtitle: Text(
                            t.text('onlyWhenWorkingDesc'),
                            style: const TextStyle(fontSize: 12),
                          ),
                          secondary: Icon(
                            Icons.work,
                            color: !_reservationAlwaysReceive
                                ? Colors.orange
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // ===================
                // 注文通知・通知音設定セクション
                // ===================
                Text(
                  '🔔 ${t.text('orderNotifications')}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: Colors.orange[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '注文通知は出勤中のみ受信します。',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 通知音の有効/無効
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('通知音'),
                        subtitle: const Text('新規注文時に音を鳴らす'),
                        secondary: Icon(
                          Icons.volume_up,
                          color: _soundEnabled ? Colors.blue : Colors.grey,
                        ),
                        value: _soundEnabled,
                        onChanged: (value) {
                          setState(() {
                            _soundEnabled = value;
                          });
                        },
                      ),
                      if (_soundEnabled)
                        ListTile(
                          leading: Icon(
                            _getSoundIcon(_selectedSoundType),
                            color: Colors.blue,
                          ),
                          title: const Text('通知音を選択'),
                          subtitle: Text(_selectedSoundType.displayName),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.play_circle_outline),
                                color: Colors.green,
                                onPressed: () {
                                  _notificationService.playPreview(_selectedSoundType);
                                },
                                tooltip: '試聴',
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: _showSoundSelectionDialog,
                        ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('バイブレーション'),
                        subtitle: const Text('新規注文時に振動で通知'),
                        secondary: Icon(
                          Icons.vibration,
                          color: _vibrationEnabled ? Colors.blue : Colors.grey,
                        ),
                        value: _vibrationEnabled,
                        onChanged: (value) {
                          setState(() {
                            _vibrationEnabled = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ===================
                // カテゴリ選択セクション
                // ===================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${t.text('category')} (${_selectedCategories.length}/${_categories.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedCategories.length == _categories.length) {
                            _selectedCategories.clear();
                          } else {
                            _selectedCategories =
                                Set.from(_categories.map((c) => c.id));
                          }
                        });
                      },
                      child: Text(
                        _selectedCategories.length == _categories.length
                            ? t.text('cancel')
                            : t.text('all'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_categories.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(t.text('noData')),
                      ),
                    ),
                  )
                else
                  ..._categories.map((category) {
                    final isSelected = _selectedCategories.contains(category.id);
                    return Card(
                      elevation: isSelected ? 2 : 0,
                      color: isSelected ? Colors.green[50] : Colors.grey[100],
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedCategories.add(category.id);
                            } else {
                              _selectedCategories.remove(category.id);
                            }
                          });
                        },
                        title: Text(
                          category.displayName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: category.description != null
                            ? Text(
                                category.description!,
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                        secondary: Icon(
                          Icons.notifications_active,
                          color: isSelected ? Colors.green : Colors.grey,
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 24),

                // 保存ボタン
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveSettings,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            t.text('save'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('${t.text('error')}: $error'),
        ),
      ),
    );
  }
}

// ProductCategoryモデル
class ProductCategory {
  final String id;
  final String name;
  final String displayName;
  final String? description;
  final int sortOrder;

  ProductCategory({
    required this.id,
    required this.name,
    required this.displayName,
    this.description,
    required this.sortOrder,
  });

  factory ProductCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductCategory(
      id: doc.id,
      name: data['name'] ?? '',
      displayName: data['displayName'] ?? data['name'] ?? '',
      description: data['description'],
      sortOrder: data['sortOrder'] ?? 0,
    );
  }
}
