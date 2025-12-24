import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

/// ウェルカムメッセージ編集画面
class WelcomeMessageScreen extends ConsumerStatefulWidget {
  const WelcomeMessageScreen({super.key});

  @override
  ConsumerState<WelcomeMessageScreen> createState() => _WelcomeMessageScreenState();
}

class _WelcomeMessageScreenState extends ConsumerState<WelcomeMessageScreen> {
  bool _isLoading = false;

  // 日本語
  final _welcomeTitleJaController = TextEditingController();
  final _welcomeMessageJaController = TextEditingController();

  // 英語
  final _welcomeTitleEnController = TextEditingController();
  final _welcomeMessageEnController = TextEditingController();

  // タイ語
  final _welcomeTitleThController = TextEditingController();
  final _welcomeMessageThController = TextEditingController();

  // 設定
  bool _showLogo = true;
  bool _showBusinessHours = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _welcomeTitleJaController.dispose();
    _welcomeMessageJaController.dispose();
    _welcomeTitleEnController.dispose();
    _welcomeMessageEnController.dispose();
    _welcomeTitleThController.dispose();
    _welcomeMessageThController.dispose();
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
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final welcome = data['welcomeMessage'] as Map<String, dynamic>? ?? {};

        // 日本語
        _welcomeTitleJaController.text = welcome['titleJa'] ?? '';
        _welcomeMessageJaController.text = welcome['messageJa'] ?? '';

        // 英語
        _welcomeTitleEnController.text = welcome['titleEn'] ?? '';
        _welcomeMessageEnController.text = welcome['messageEn'] ?? '';

        // タイ語
        _welcomeTitleThController.text = welcome['titleTh'] ?? '';
        _welcomeMessageThController.text = welcome['messageTh'] ?? '';

        // 設定
        _showLogo = welcome['showLogo'] ?? true;
        _showBusinessHours = welcome['showBusinessHours'] ?? true;
      }
    } catch (e) {
      debugPrint('ウェルカムメッセージ読み込みエラー: $e');
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
          .update({
        'welcomeMessage': {
          'titleJa': _welcomeTitleJaController.text.trim(),
          'messageJa': _welcomeMessageJaController.text.trim(),
          'titleEn': _welcomeTitleEnController.text.trim(),
          'messageEn': _welcomeMessageEnController.text.trim(),
          'titleTh': _welcomeTitleThController.text.trim(),
          'messageTh': _welcomeMessageThController.text.trim(),
          'showLogo': _showLogo,
          'showBusinessHours': _showBusinessHours,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ウェルカムメッセージを保存しました'),
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
        title: const Text('ウェルカムメッセージ'),
        backgroundColor: Colors.teal.shade700,
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
                  // 説明
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.teal.shade700),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'モバイルオーダーや予約画面の最初に表示されるメッセージを設定できます。',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 表示設定
                  _buildSectionTitle('表示設定'),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('ロゴを表示'),
                    subtitle: const Text('店舗ロゴをウェルカム画面に表示'),
                    value: _showLogo,
                    onChanged: (value) {
                      setState(() => _showLogo = value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('営業時間を表示'),
                    subtitle: const Text('現在の営業時間を表示'),
                    value: _showBusinessHours,
                    onChanged: (value) {
                      setState(() => _showBusinessHours = value);
                    },
                  ),
                  const Divider(),
                  const SizedBox(height: 16),

                  // 日本語
                  _buildLanguageSection(
                    title: '日本語',
                    flag: '🇯🇵',
                    titleController: _welcomeTitleJaController,
                    messageController: _welcomeMessageJaController,
                    titleHint: 'ようこそ',
                    messageHint: '当店をご利用いただきありがとうございます。ごゆっくりお過ごしください。',
                  ),
                  const SizedBox(height: 24),

                  // 英語
                  _buildLanguageSection(
                    title: 'English',
                    flag: '🇺🇸',
                    titleController: _welcomeTitleEnController,
                    messageController: _welcomeMessageEnController,
                    titleHint: 'Welcome',
                    messageHint: 'Thank you for visiting. Enjoy your time!',
                  ),
                  const SizedBox(height: 24),

                  // タイ語
                  _buildLanguageSection(
                    title: 'ภาษาไทย',
                    flag: '🇹🇭',
                    titleController: _welcomeTitleThController,
                    messageController: _welcomeMessageThController,
                    titleHint: 'ยินดีต้อนรับ',
                    messageHint: 'ขอบคุณที่มาเยี่ยมชม ขอให้สนุกกับเวลาของคุณ!',
                  ),
                  const SizedBox(height: 32),

                  // プレビュー
                  _buildPreviewSection(),
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

  Widget _buildLanguageSection({
    required String title,
    required String flag,
    required TextEditingController titleController,
    required TextEditingController messageController,
    required String titleHint,
    required String messageHint,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(flag, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'タイトル',
                hintText: titleHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              decoration: InputDecoration(
                labelText: 'メッセージ',
                hintText: messageHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Card(
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.preview, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                const Text(
                  'プレビュー（日本語）',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (_showLogo) ...[
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.store,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    _welcomeTitleJaController.text.isEmpty
                        ? 'ようこそ'
                        : _welcomeTitleJaController.text,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _welcomeMessageJaController.text.isEmpty
                        ? '当店をご利用いただきありがとうございます。'
                        : _welcomeMessageJaController.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (_showBusinessHours) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '営業中 11:00 - 22:00',
                        style: TextStyle(
                          color: Colors.green.shade700,
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
    );
  }
}
