import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

/// 決済ゲートウェイ設定画面（Stripe/Omise）
class PaymentGatewayScreen extends ConsumerStatefulWidget {
  const PaymentGatewayScreen({super.key});

  @override
  ConsumerState<PaymentGatewayScreen> createState() => _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends ConsumerState<PaymentGatewayScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  // Stripe設定
  final _stripePublicKeyController = TextEditingController();
  final _stripeSecretKeyController = TextEditingController();
  bool _stripeEnabled = false;
  bool _stripeTestMode = true;

  // Omise設定
  final _omisePublicKeyController = TextEditingController();
  final _omiseSecretKeyController = TextEditingController();
  bool _omiseEnabled = false;
  bool _omiseTestMode = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stripePublicKeyController.dispose();
    _stripeSecretKeyController.dispose();
    _omisePublicKeyController.dispose();
    _omiseSecretKeyController.dispose();
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
          .doc('payment')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        // Stripe
        _stripePublicKeyController.text = data['stripePublicKey'] ?? '';
        _stripeSecretKeyController.text = data['stripeSecretKey'] ?? '';
        _stripeEnabled = data['stripeEnabled'] ?? false;
        _stripeTestMode = data['stripeTestMode'] ?? true;
        // Omise
        _omisePublicKeyController.text = data['omisePublicKey'] ?? '';
        _omiseSecretKeyController.text = data['omiseSecretKey'] ?? '';
        _omiseEnabled = data['omiseEnabled'] ?? false;
        _omiseTestMode = data['omiseTestMode'] ?? true;
      }
    } catch (e) {
      debugPrint('決済設定読み込みエラー: $e');
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
          .doc('payment')
          .set({
        // Stripe
        'stripePublicKey': _stripePublicKeyController.text.trim(),
        'stripeSecretKey': _stripeSecretKeyController.text.trim(),
        'stripeEnabled': _stripeEnabled,
        'stripeTestMode': _stripeTestMode,
        // Omise
        'omisePublicKey': _omisePublicKeyController.text.trim(),
        'omiseSecretKey': _omiseSecretKeyController.text.trim(),
        'omiseEnabled': _omiseEnabled,
        'omiseTestMode': _omiseTestMode,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('決済設定を保存しました'),
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
        title: const Text('決済ゲートウェイ設定'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveSettings,
            child: const Text('保存', style: TextStyle(color: Colors.white)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Stripe'),
            Tab(text: 'Omise'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStripeTab(),
                _buildOmiseTab(),
              ],
            ),
    );
  }

  Widget _buildStripeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ロゴ
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF635BFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Stripe',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF635BFF),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 有効/無効
          SwitchListTile(
            title: const Text('Stripeを有効にする'),
            subtitle: Text(_stripeEnabled ? '有効' : '無効'),
            value: _stripeEnabled,
            onChanged: (value) {
              setState(() => _stripeEnabled = value);
            },
          ),

          // テストモード
          SwitchListTile(
            title: const Text('テストモード'),
            subtitle: Text(_stripeTestMode ? 'テスト環境' : '本番環境'),
            value: _stripeTestMode,
            onChanged: (value) {
              setState(() => _stripeTestMode = value);
            },
            secondary: Icon(
              _stripeTestMode ? Icons.bug_report : Icons.verified,
              color: _stripeTestMode ? Colors.orange : Colors.green,
            ),
          ),
          const Divider(),
          const SizedBox(height: 16),

          // APIキー
          TextField(
            controller: _stripePublicKeyController,
            decoration: InputDecoration(
              labelText: 'Publishable Key',
              border: const OutlineInputBorder(),
              helperText: _stripeTestMode ? 'pk_test_で始まるキー' : 'pk_live_で始まるキー',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _stripeSecretKeyController,
            decoration: InputDecoration(
              labelText: 'Secret Key',
              border: const OutlineInputBorder(),
              helperText: _stripeTestMode ? 'sk_test_で始まるキー' : 'sk_live_で始まるキー',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 24),

          // ヘルプ
          _buildHelpCard(
            'Stripe設定方法',
            '1. Stripe Dashboardにログイン\n'
            '2. 開発者 > APIキーを開く\n'
            '3. Publishable KeyとSecret Keyをコピー\n'
            '4. 本番前にテストモードで動作確認',
          ),
        ],
      ),
    );
  }

  Widget _buildOmiseTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ロゴ
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F71).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Omise',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1F71),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'タイ・日本・シンガポール向け決済',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 24),

          // 有効/無効
          SwitchListTile(
            title: const Text('Omiseを有効にする'),
            subtitle: Text(_omiseEnabled ? '有効' : '無効'),
            value: _omiseEnabled,
            onChanged: (value) {
              setState(() => _omiseEnabled = value);
            },
          ),

          // テストモード
          SwitchListTile(
            title: const Text('テストモード'),
            subtitle: Text(_omiseTestMode ? 'テスト環境' : '本番環境'),
            value: _omiseTestMode,
            onChanged: (value) {
              setState(() => _omiseTestMode = value);
            },
            secondary: Icon(
              _omiseTestMode ? Icons.bug_report : Icons.verified,
              color: _omiseTestMode ? Colors.orange : Colors.green,
            ),
          ),
          const Divider(),
          const SizedBox(height: 16),

          // APIキー
          TextField(
            controller: _omisePublicKeyController,
            decoration: InputDecoration(
              labelText: 'Public Key',
              border: const OutlineInputBorder(),
              helperText: _omiseTestMode ? 'pkey_test_で始まるキー' : 'pkey_で始まるキー',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _omiseSecretKeyController,
            decoration: InputDecoration(
              labelText: 'Secret Key',
              border: const OutlineInputBorder(),
              helperText: _omiseTestMode ? 'skey_test_で始まるキー' : 'skey_で始まるキー',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 24),

          // 対応決済方法
          _buildSupportedPayments(),
          const SizedBox(height: 24),

          // ヘルプ
          _buildHelpCard(
            'Omise設定方法',
            '1. Omise Dashboardにログイン\n'
            '2. APIキーページを開く\n'
            '3. Public KeyとSecret Keyをコピー\n'
            '4. テストモードで動作確認後、本番に切り替え',
          ),
        ],
      ),
    );
  }

  Widget _buildSupportedPayments() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '対応決済方法',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPaymentChip('クレジットカード', Icons.credit_card),
              _buildPaymentChip('PromptPay', Icons.qr_code),
              _buildPaymentChip('TrueMoney', Icons.account_balance_wallet),
              _buildPaymentChip('Rabbit LINE Pay', Icons.payment),
              _buildPaymentChip('インターネットバンキング', Icons.account_balance),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentChip(String label, IconData icon) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildHelpCard(String title, String content) {
    return Container(
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
