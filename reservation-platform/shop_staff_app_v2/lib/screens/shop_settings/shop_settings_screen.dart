import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import 'business_calendar_screen.dart';
import 'payment_methods_screen.dart';
import 'line_settings_screen.dart';
import 'payment_gateway_screen.dart';
import 'subscription_screen.dart';
import 'welcome_message_screen.dart';
import 'announcements_screen.dart';

/// 店舗設定画面（オーナー専用）
class ShopSettingsScreen extends ConsumerStatefulWidget {
  const ShopSettingsScreen({super.key});

  @override
  ConsumerState<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends ConsumerState<ShopSettingsScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationProvider);
    final isOwner = ref.watch(isOwnerProvider);
    final staffUser = ref.watch(staffUserProvider).value;

    if (!isOwner) {
      return Scaffold(
        appBar: AppBar(
          title: Text(t.text('shopSettings')),
        ),
        body: const Center(
          child: Text('この画面はオーナーのみアクセスできます'),
        ),
      );
    }

    if (staffUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.text('shopSettings')),
        backgroundColor: Colors.brown.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shops')
            .doc(staffUser.shopId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('店舗情報が見つかりません'));
          }

          final shop = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ロゴ・画像
                _buildSection(
                  title: 'ロゴ・画像',
                  icon: Icons.image,
                  children: [
                    _buildLogoTile(staffUser.shopId, shop['logoUrl']),
                  ],
                ),
                const SizedBox(height: 16),

                // 基本情報
                _buildSection(
                  title: '基本情報',
                  icon: Icons.store,
                  children: [
                    _buildSettingTile(
                      title: '店舗名',
                      value: shop['shopName'] ?? '未設定',
                      onTap: () => _editTextSetting(
                        staffUser.shopId,
                        'shopName',
                        '店舗名',
                        shop['shopName'] ?? '',
                      ),
                    ),
                    _buildSettingTile(
                      title: '住所',
                      value: shop['address'] ?? '未設定',
                      onTap: () => _editTextSetting(
                        staffUser.shopId,
                        'address',
                        '住所',
                        shop['address'] ?? '',
                      ),
                    ),
                    _buildSettingTile(
                      title: '電話番号',
                      value: shop['phone'] ?? '未設定',
                      onTap: () => _editTextSetting(
                        staffUser.shopId,
                        'phone',
                        '電話番号',
                        shop['phone'] ?? '',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 営業設定
                _buildSection(
                  title: '営業設定',
                  icon: Icons.schedule,
                  children: [
                    _buildSwitchTile(
                      title: 'モバイルオーダー',
                      subtitle: '顧客がスマホから注文可能',
                      value: shop['mobileOrderEnabled'] ?? false,
                      onChanged: (value) => _updateSetting(
                        staffUser.shopId,
                        'mobileOrderEnabled',
                        value,
                      ),
                    ),
                    _buildSwitchTile(
                      title: '予約受付',
                      subtitle: 'オンライン予約を受付',
                      value: shop['reservationEnabled'] ?? true,
                      onChanged: (value) => _updateSetting(
                        staffUser.shopId,
                        'reservationEnabled',
                        value,
                      ),
                    ),
                    _buildSwitchTile(
                      title: 'テイクアウト',
                      subtitle: 'テイクアウト注文を受付',
                      value: shop['takeoutEnabled'] ?? false,
                      onChanged: (value) => _updateSetting(
                        staffUser.shopId,
                        'takeoutEnabled',
                        value,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 営業時間設定
                _buildSection(
                  title: '営業時間設定',
                  icon: Icons.access_time,
                  children: [
                    _buildSettingTile(
                      title: '営業時間',
                      value: _formatBusinessHours(shop['businessHours']),
                      onTap: () => _editBusinessHours(
                        staffUser.shopId,
                        shop['businessHours'],
                      ),
                    ),
                    _buildSettingTile(
                      title: 'ラストオーダー',
                      value: shop['lastOrderMinutes'] != null
                          ? '閉店${shop['lastOrderMinutes']}分前'
                          : '設定なし',
                      onTap: () => _editLastOrder(
                        staffUser.shopId,
                        shop['lastOrderMinutes'] ?? 30,
                      ),
                    ),
                    _buildSettingTile(
                      title: '営業カレンダー',
                      value: '特別営業日・臨時休業日',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BusinessCalendarScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 消費税設定
                _buildSection(
                  title: '消費税設定',
                  icon: Icons.percent,
                  children: [
                    _buildSettingTile(
                      title: '税率',
                      value: '${((shop['taxRate'] ?? 0.1) * 100).toInt()}%',
                      onTap: () => _editTaxRate(
                        staffUser.shopId,
                        shop['taxRate'] ?? 0.1,
                      ),
                    ),
                    _buildSwitchTile(
                      title: '内税表示',
                      subtitle: '価格に税込み表示',
                      value: shop['taxIncluded'] ?? true,
                      onChanged: (value) => _updateSetting(
                        staffUser.shopId,
                        'taxIncluded',
                        value,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // テーブル設定
                _buildSection(
                  title: 'テーブル設定',
                  icon: Icons.table_bar,
                  children: [
                    _buildSettingTile(
                      title: 'テーブル数',
                      value: '${shop['tableCount'] ?? 0}卓',
                      onTap: () => _editNumberSetting(
                        staffUser.shopId,
                        'tableCount',
                        'テーブル数',
                        shop['tableCount'] ?? 0,
                      ),
                    ),
                    _buildSettingTile(
                      title: '席数',
                      value: '${shop['seatCount'] ?? 0}席',
                      onTap: () => _editNumberSetting(
                        staffUser.shopId,
                        'seatCount',
                        '席数',
                        shop['seatCount'] ?? 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 通知設定
                _buildSection(
                  title: '通知設定',
                  icon: Icons.notifications,
                  children: [
                    _buildSwitchTile(
                      title: '新規注文通知',
                      subtitle: '注文が入った時にプッシュ通知',
                      value: shop['orderNotificationEnabled'] ?? true,
                      onChanged: (value) => _updateSetting(
                        staffUser.shopId,
                        'orderNotificationEnabled',
                        value,
                      ),
                    ),
                    _buildSwitchTile(
                      title: '予約通知',
                      subtitle: '新しい予約が入った時にプッシュ通知',
                      value: shop['reservationNotificationEnabled'] ?? true,
                      onChanged: (value) => _updateSetting(
                        staffUser.shopId,
                        'reservationNotificationEnabled',
                        value,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 支払方法設定
                _buildSection(
                  title: '支払方法設定',
                  icon: Icons.payment,
                  children: [
                    _buildSettingTile(
                      title: '支払方法',
                      value: '有効な支払方法を管理',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PaymentMethodsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildSettingTile(
                      title: '決済ゲートウェイ',
                      value: 'Stripe / Omise 連携',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PaymentGatewayScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 顧客向け設定
                _buildSection(
                  title: '顧客向け設定',
                  icon: Icons.people,
                  children: [
                    _buildSettingTile(
                      title: 'ウェルカムメッセージ',
                      value: '顧客への挨拶メッセージ',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WelcomeMessageScreen(),
                          ),
                        );
                      },
                    ),
                    _buildSettingTile(
                      title: 'お知らせ管理',
                      value: '顧客向けのお知らせ配信',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AnnouncementsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 外部連携
                _buildSection(
                  title: '外部連携',
                  icon: Icons.link,
                  children: [
                    _buildSettingTile(
                      title: 'LINE連携',
                      value: 'LINE通知・Messaging API',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LineSettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // プラン・契約
                _buildSection(
                  title: 'プラン・契約',
                  icon: Icons.card_membership,
                  children: [
                    _buildSettingTile(
                      title: 'ご利用プラン',
                      value: 'プラン確認・変更',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SubscriptionScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // その他
                _buildSection(
                  title: 'その他',
                  icon: Icons.more_horiz,
                  children: [
                    _buildSettingTile(
                      title: 'Shop ID',
                      value: staffUser.shopId,
                      isReadOnly: true,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.brown.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown.shade700,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  /// ロゴ画像タイル
  Widget _buildLogoTile(String shopId, String? logoUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('店舗ロゴ', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              // ロゴプレビュー
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  image: logoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(logoUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: logoUrl == null
                    ? Icon(Icons.store, size: 40, color: Colors.grey.shade400)
                    : null,
              ),
              const SizedBox(width: 16),
              // ボタン
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _uploadLogo(shopId),
                      icon: const Icon(Icons.upload, size: 18),
                      label: Text(logoUrl != null ? 'ロゴを変更' : 'ロゴをアップロード'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (logoUrl != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _isLoading ? null : () => _deleteLogo(shopId),
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('削除'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '推奨: 正方形、500×500px以上のPNGまたはJPG',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  /// ロゴをアップロード
  Future<void> _uploadLogo(String shopId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      // Firebase Storageにアップロード
      final file = File(pickedFile.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('shops')
          .child(shopId)
          .child('logo_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      // Firestoreに保存
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .update({'logoUrl': downloadUrl});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ロゴをアップロードしました'),
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ロゴを削除
  Future<void> _deleteLogo(String shopId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: const Text('ロゴを削除しますか？'),
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

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .update({'logoUrl': FieldValue.delete()});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ロゴを削除しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSettingTile({
    required String title,
    required String value,
    VoidCallback? onTap,
    bool isReadOnly = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(
        value,
        style: TextStyle(
          color: isReadOnly ? Colors.grey : Colors.black87,
        ),
      ),
      trailing: isReadOnly
          ? null
          : const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: isReadOnly ? null : onTap,
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      value: value,
      onChanged: _isLoading ? null : onChanged,
      activeColor: Colors.brown.shade700,
    );
  }

  Future<void> _updateSetting(String shopId, String field, dynamic value) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .update({field: value});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('設定を更新しました'),
            backgroundColor: Colors.green,
          ),
        );
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _editTextSetting(
    String shopId,
    String field,
    String label,
    String currentValue,
  ) async {
    final controller = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && result != currentValue) {
      await _updateSetting(shopId, field, result);
    }
  }

  Future<void> _editNumberSetting(
    String shopId,
    String field,
    String label,
    int currentValue,
  ) async {
    final controller = TextEditingController(text: currentValue.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value >= 0) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && result != currentValue) {
      await _updateSetting(shopId, field, result);
    }
  }

  String _formatBusinessHours(dynamic businessHours) {
    if (businessHours == null) return '未設定';
    if (businessHours is Map) {
      // 簡略表示: 月〜日の営業時間を確認
      final monday = businessHours['monday'];
      if (monday != null && monday['isOpen'] == true) {
        return '${monday['open']} - ${monday['close']}';
      }
    }
    return '設定済み（タップで編集）';
  }

  final List<String> _dayNames = ['月', '火', '水', '木', '金', '土', '日'];
  final List<String> _dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

  Future<void> _editBusinessHours(String shopId, dynamic currentHours) async {
    // 現在の設定を取得またはデフォルト値を作成
    Map<String, dynamic> hours = {};
    if (currentHours != null && currentHours is Map) {
      hours = Map<String, dynamic>.from(currentHours);
    } else {
      // デフォルト値
      for (final key in _dayKeys) {
        hours[key] = {
          'isOpen': key != 'sunday', // 日曜はデフォルトで休み
          'open': '11:00',
          'close': '22:00',
        };
      }
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _BusinessHoursDialog(
        hours: hours,
        dayNames: _dayNames,
        dayKeys: _dayKeys,
      ),
    );

    if (result != null) {
      await _updateSetting(shopId, 'businessHours', result);
    }
  }

  Future<void> _editLastOrder(String shopId, int currentMinutes) async {
    final controller = TextEditingController(text: currentMinutes.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ラストオーダー設定'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '閉店時間の何分前にラストオーダーとするか設定します。',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '閉店前の分数',
                border: OutlineInputBorder(),
                suffixText: '分',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value >= 0) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _updateSetting(shopId, 'lastOrderMinutes', result);
    }
  }

  Future<void> _editTaxRate(String shopId, double currentRate) async {
    int selectedRate = (currentRate * 100).toInt();
    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('税率設定'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<int>(
                title: const Text('8%（軽減税率）'),
                value: 8,
                groupValue: selectedRate,
                onChanged: (value) {
                  setState(() {
                    selectedRate = value!;
                  });
                },
              ),
              RadioListTile<int>(
                title: const Text('10%（標準税率）'),
                value: 10,
                groupValue: selectedRate,
                onChanged: (value) {
                  setState(() {
                    selectedRate = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selectedRate),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _updateSetting(shopId, 'taxRate', result / 100);
    }
  }
}

/// 営業時間編集ダイアログ
class _BusinessHoursDialog extends StatefulWidget {
  final Map<String, dynamic> hours;
  final List<String> dayNames;
  final List<String> dayKeys;

  const _BusinessHoursDialog({
    required this.hours,
    required this.dayNames,
    required this.dayKeys,
  });

  @override
  State<_BusinessHoursDialog> createState() => _BusinessHoursDialogState();
}

class _BusinessHoursDialogState extends State<_BusinessHoursDialog> {
  late Map<String, dynamic> _hours;

  @override
  void initState() {
    super.initState();
    _hours = Map<String, dynamic>.from(widget.hours);
    // 各曜日のデータをディープコピー
    for (final key in widget.dayKeys) {
      if (_hours[key] != null) {
        _hours[key] = Map<String, dynamic>.from(_hours[key]);
      } else {
        _hours[key] = {
          'isOpen': true,
          'open': '11:00',
          'close': '22:00',
        };
      }
    }
  }

  Future<void> _selectTime(String dayKey, String field) async {
    final currentTime = _hours[dayKey][field] as String? ?? '11:00';
    final parts = currentTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 11,
      minute: int.tryParse(parts[1]) ?? 0,
    );

    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (time != null) {
      setState(() {
        _hours[dayKey][field] =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: Colors.brown.shade700),
                  const SizedBox(width: 8),
                  const Text(
                    '営業時間設定',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: widget.dayKeys.length,
                itemBuilder: (context, index) {
                  final dayKey = widget.dayKeys[index];
                  final dayName = widget.dayNames[index];
                  final dayData = _hours[dayKey] as Map<String, dynamic>;
                  final isOpen = dayData['isOpen'] as bool? ?? true;
                  final openTime = dayData['open'] as String? ?? '11:00';
                  final closeTime = dayData['close'] as String? ?? '22:00';

                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          // 曜日
                          SizedBox(
                            width: 40,
                            child: Text(
                              '$dayName曜',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: dayKey == 'saturday'
                                    ? Colors.blue
                                    : dayKey == 'sunday'
                                        ? Colors.red
                                        : Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 営業/定休
                          SizedBox(
                            width: 80,
                            child: Switch(
                              value: isOpen,
                              onChanged: (value) {
                                setState(() {
                                  _hours[dayKey]['isOpen'] = value;
                                });
                              },
                              activeColor: Colors.green,
                            ),
                          ),
                          // 開店時間
                          Expanded(
                            child: isOpen
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      InkWell(
                                        onTap: () => _selectTime(dayKey, 'open'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.shade300),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(openTime),
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                        child: Text('〜'),
                                      ),
                                      InkWell(
                                        onTap: () => _selectTime(dayKey, 'close'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.shade300),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(closeTime),
                                        ),
                                      ),
                                    ],
                                  )
                                : Center(
                                    child: Text(
                                      '定休日',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, _hours),
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
