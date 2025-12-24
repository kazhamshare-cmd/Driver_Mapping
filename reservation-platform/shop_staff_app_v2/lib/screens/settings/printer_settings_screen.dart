import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // ★追加
import '../../services/printer_service.dart';
import '../../services/printer_settings_service.dart';
import '../../widgets/common_app_bar.dart';
import '../../providers/locale_provider.dart'; 

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _printerService = PrinterService();
  final _settingsService = PrinterSettingsService();
  
  bool _isTesting = false;
  bool _isEnabled = false;
  bool _isDrawerEnabled = false;
  DrawerPin _drawerPin = DrawerPin.pin2;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final ip = await _settingsService.getPrinterIp();
    final port = await _settingsService.getPrinterPort();
    final enabled = await _settingsService.isPrinterEnabled();
    final drawerEnabled = await _settingsService.isDrawerEnabled();
    final drawerPin = await _settingsService.getDrawerPin();

    if (mounted) {
      setState(() {
        _ipController.text = ip ?? '192.168.1.200';
        _portController.text = port.toString();
        _isEnabled = enabled;
        _isDrawerEnabled = drawerEnabled;
        _drawerPin = drawerPin;
      });
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  /// 接続テスト実行
  Future<void> _runConnectionTest() async {
    final t = ref.read(translationProvider);
    final ip = _ipController.text;
    final port = int.tryParse(_portController.text);

    if (ip.isEmpty || port == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.text('invalidInput'))),
      );
      return;
    }

    setState(() => _isTesting = true);

    try {
      final isSuccess = await _printerService.testConnection(ip, port);

      if (!mounted) return;

      if (isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.text('connectionSuccess')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.text('connectionFailed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.text('error')}: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  /// 設定を保存
  Future<void> _saveSettings() async {
    final t = ref.read(translationProvider);
    final ip = _ipController.text;
    final port = int.tryParse(_portController.text);

    if (ip.isEmpty || port == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.text('invalidInput'))),
      );
      return;
    }

    await _settingsService.savePrinterIp(ip);
    await _settingsService.savePrinterPort(port);
    await _settingsService.setPrinterEnabled(_isEnabled);
    await _settingsService.setDrawerEnabled(_isDrawerEnabled);
    await _settingsService.saveDrawerPin(_drawerPin);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.text('settingsSaved')), backgroundColor: Colors.green),
    );

    // ▼▼▼ 修正箇所 ▼▼▼
    // 戻れる場合は戻り、戻れない（履歴がない）場合はホームへ移動する安全策
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
    // ▲▲▲ 修正箇所 ▲▲▲
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationProvider);

    return Scaffold(
      appBar: AppBar( // CommonAppBarがない場合を考慮して標準AppBarを使用
        title: Text(t.text('printer')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // スイッチ部分
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.text('printerEnabled'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(t.text('printerSettingsDesc'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isEnabled,
                    onChanged: (val) {
                      setState(() => _isEnabled = val);
                    },
                    activeColor: Colors.orange,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // キャッシュドロワー設定
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.text('drawerEnabled'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(t.text('drawerSettings'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isDrawerEnabled,
                        onChanged: (val) {
                          setState(() => _isDrawerEnabled = val);
                        },
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                  if (_isDrawerEnabled) ...[
                    const SizedBox(height: 16),
                    Text(t.text('drawerPin'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<DrawerPin>(
                            title: Text(t.text('pin2')),
                            value: DrawerPin.pin2,
                            groupValue: _drawerPin,
                            onChanged: (val) => setState(() => _drawerPin = val!),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<DrawerPin>(
                            title: Text(t.text('pin5')),
                            value: DrawerPin.pin5,
                            groupValue: _drawerPin,
                            onChanged: (val) => setState(() => _drawerPin = val!),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),
            Text(t.text('connectTest'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              t.text('printerNotConfigured'),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),

            const SizedBox(height: 24),

            // 入力フォーム
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _ipController,
                    decoration: InputDecoration(
                      labelText: t.text('printerAddress'),
                      prefixIcon: const Icon(Icons.wifi),
                      border: const OutlineInputBorder(),
                      hintText: '192.168.x.x',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _portController,
                    decoration: InputDecoration(
                      labelText: t.text('printerPort'),
                      prefixIcon: const Icon(Icons.settings_ethernet),
                      border: const OutlineInputBorder(),
                      hintText: '9100',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // テスト接続ボタン
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isTesting ? null : _runConnectionTest,
                icon: _isTesting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.print),
                label: Text(_isTesting ? t.text('loading') : t.text('testPrint')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.grey),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 保存ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isTesting ? null : _saveSettings,
                icon: const Icon(Icons.save, color: Colors.white),
                label: Text(t.text('save'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}