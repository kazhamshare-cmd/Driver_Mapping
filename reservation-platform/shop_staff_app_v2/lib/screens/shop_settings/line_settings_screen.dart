import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

/// LINE連携設定画面
class LineSettingsScreen extends ConsumerStatefulWidget {
  const LineSettingsScreen({super.key});

  @override
  ConsumerState<LineSettingsScreen> createState() => _LineSettingsScreenState();
}

class _LineSettingsScreenState extends ConsumerState<LineSettingsScreen> {
  final _channelIdController = TextEditingController();
  final _channelSecretController = TextEditingController();
  final _accessTokenController = TextEditingController();
  bool _isLoading = false;
  bool _isEnabled = false;

  // 通知設定
  bool _notifyReservation = true;
  bool _notifyReservationReminder = true;
  bool _notifyOrder = false;
  bool _notifyAdminNewReservation = true;
  bool _notifyAdminCancellation = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _channelIdController.dispose();
    _channelSecretController.dispose();
    _accessTokenController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) return;

    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(staffUser.shopId)
          .collection('integrations')
          .doc('line')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _channelIdController.text = data['channelId'] ?? '';
        _channelSecretController.text = data['channelSecret'] ?? '';
        _accessTokenController.text = data['accessToken'] ?? '';
        _isEnabled = data['isEnabled'] ?? false;
        _notifyReservation = data['notifyReservation'] ?? true;
        _notifyReservationReminder = data['notifyReservationReminder'] ?? true;
        _notifyOrder = data['notifyOrder'] ?? false;
        _notifyAdminNewReservation = data['notifyAdminNewReservation'] ?? true;
        _notifyAdminCancellation = data['notifyAdminCancellation'] ?? true;
      }
    } catch (e) {
      debugPrint('LINE設定読み込みエラー: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(staffUser.shopId)
          .collection('integrations')
          .doc('line')
          .set({
        'channelId': _channelIdController.text.trim(),
        'channelSecret': _channelSecretController.text.trim(),
        'accessToken': _accessTokenController.text.trim(),
        'isEnabled': _isEnabled,
        'notifyReservation': _notifyReservation,
        'notifyReservationReminder': _notifyReservationReminder,
        'notifyOrder': _notifyOrder,
        'notifyAdminNewReservation': _notifyAdminNewReservation,
        'notifyAdminCancellation': _notifyAdminCancellation,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('LINE設定を保存しました'),
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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LINE連携設定'),
        backgroundColor: const Color(0xFF00B900),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveSettings,
            child: const Text('保存', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 有効/無効
                  SwitchListTile(
                    title: const Text('LINE連携を有効にする'),
                    subtitle: Text(
                      _isEnabled ? '連携中' : '連携停止中',
                      style: TextStyle(
                        color: _isEnabled ? Colors.green : Colors.grey,
                      ),
                    ),
                    value: _isEnabled,
                    onChanged: (value) {
                      setState(() => _isEnabled = value);
                    },
                    secondary: Icon(
                      Icons.power_settings_new,
                      color: _isEnabled ? Colors.green : Colors.grey,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 16),

                  // API設定
                  _buildSectionTitle('API設定'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _channelIdController,
                    decoration: const InputDecoration(
                      labelText: 'Channel ID',
                      border: OutlineInputBorder(),
                      helperText: 'LINE Developers ConsoleのChannel ID',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _channelSecretController,
                    decoration: const InputDecoration(
                      labelText: 'Channel Secret',
                      border: OutlineInputBorder(),
                      helperText: 'LINE Developers ConsoleのChannel Secret',
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _accessTokenController,
                    decoration: const InputDecoration(
                      labelText: 'Channel Access Token',
                      border: OutlineInputBorder(),
                      helperText: 'Messaging APIのアクセストークン',
                    ),
                    obscureText: true,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 24),

                  // 顧客向け通知設定
                  _buildSectionTitle('顧客向け通知'),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('予約確認通知'),
                    subtitle: const Text('予約完了時に顧客へ通知'),
                    value: _notifyReservation,
                    onChanged: (value) {
                      setState(() => _notifyReservation = value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('予約リマインダー'),
                    subtitle: const Text('予約日前日に顧客へリマインド'),
                    value: _notifyReservationReminder,
                    onChanged: (value) {
                      setState(() => _notifyReservationReminder = value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('注文完了通知'),
                    subtitle: const Text('注文完了時に顧客へ通知'),
                    value: _notifyOrder,
                    onChanged: (value) {
                      setState(() => _notifyOrder = value);
                    },
                  ),
                  const SizedBox(height: 16),

                  // 管理者向け通知設定
                  _buildSectionTitle('管理者向け通知'),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('新規予約通知'),
                    subtitle: const Text('新しい予約が入った時に通知'),
                    value: _notifyAdminNewReservation,
                    onChanged: (value) {
                      setState(() => _notifyAdminNewReservation = value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('キャンセル通知'),
                    subtitle: const Text('予約がキャンセルされた時に通知'),
                    value: _notifyAdminCancellation,
                    onChanged: (value) {
                      setState(() => _notifyAdminCancellation = value);
                    },
                  ),
                  const SizedBox(height: 24),

                  // ヘルプ
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.help_outline, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            const Text(
                              '設定方法',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '1. LINE Developers Consoleでプロバイダーを作成\n'
                          '2. Messaging APIチャンネルを作成\n'
                          '3. Channel ID、Secret、Access Tokenを取得\n'
                          '4. 上記フィールドに入力して保存',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade700,
      ),
    );
  }
}
