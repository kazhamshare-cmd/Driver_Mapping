import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/printer_config.dart';
import '../../models/product.dart';
import '../../services/unified_printer_service.dart';
import '../../services/printer_settings_service.dart';
import '../../providers/locale_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';

/// 複数プリンター管理画面
class PrinterListScreen extends ConsumerStatefulWidget {
  const PrinterListScreen({super.key});

  @override
  ConsumerState<PrinterListScreen> createState() => _PrinterListScreenState();
}

class _PrinterListScreenState extends ConsumerState<PrinterListScreen> {
  final _settingsService = PrinterSettingsService();
  final _printerService = UnifiedPrinterService();

  List<PrinterConfig> _printers = [];
  bool _isLoading = true;
  bool _isSearching = false;
  List<DiscoveredPrinter> _discoveredPrinters = [];

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    setState(() => _isLoading = true);
    try {
      final printers = await _settingsService.getAllPrinters();
      if (mounted) {
        setState(() {
          _printers = printers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('プリンター読み込みエラー: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchPrinters() async {
    setState(() => _isSearching = true);
    try {
      final printers = await _printerService.searchPrinters();
      if (mounted) {
        setState(() {
          _discoveredPrinters = printers;
          _isSearching = false;
        });
        if (printers.isEmpty) {
          _showMessage('プリンターが見つかりませんでした', isError: true);
        } else {
          _showAddPrinterDialog(discoveredPrinters: printers);
        }
      }
    } catch (e) {
      debugPrint('検索エラー: $e');
      if (mounted) {
        setState(() => _isSearching = false);
        _showMessage('検索エラー: $e', isError: true);
      }
    }
  }

  Future<void> _testPrinter(PrinterConfig config) async {
    _showMessage('テスト印刷中...');
    try {
      final success = await _printerService.printTest(config);
      _showMessage(success ? '印刷成功' : '印刷失敗', isError: !success);
    } catch (e) {
      _showMessage('エラー: $e', isError: true);
    }
  }

  Future<void> _deletePrinter(PrinterConfig printer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${printer.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _settingsService.deletePrinter(printer.id);
      await _loadPrinters();
      _showMessage('削除しました');
    }
  }

  Future<void> _togglePrinter(PrinterConfig printer, bool enabled) async {
    final updated = printer.copyWith(autoprint: enabled);
    await _settingsService.updatePrinter(updated);
    await _loadPrinters();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _showAddPrinterDialog({List<DiscoveredPrinter>? discoveredPrinters}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddPrinterSheet(
        discoveredPrinters: discoveredPrinters ?? _discoveredPrinters,
        isSearching: _isSearching,
        onSearch: () {
          Navigator.pop(context);
          _searchPrinters();
        },
        onSelectDiscovered: (discovered) async {
          Navigator.pop(context);
          await _showPrinterDetailsDialog(discovered: discovered);
        },
        onManualInput: () {
          Navigator.pop(context);
          _showManualInputDialog();
        },
      ),
    );
  }

  void _showManualInputDialog() {
    final ipController = TextEditingController();
    final portController = TextEditingController(text: '9100');
    final nameController = TextEditingController();
    bool isReceiptPrinter = false;
    bool hasDrawer = false;
    Set<String> selectedCategoryIds = {};

    // カテゴリ取得
    final staffUser = ref.read(staffUserProvider).value;
    final shopId = staffUser?.shopId ?? '';

    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, dialogRef, _) {
          final categoriesAsync = dialogRef.watch(productCategoriesProvider(shopId));
          final categories = categoriesAsync.value ?? [];

          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('IPプリンターを追加'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'プリンター名',
                        hintText: 'プリンター1',
                        prefixIcon: Icon(Icons.label),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: ipController,
                      decoration: const InputDecoration(
                        labelText: 'IPアドレス',
                        hintText: '192.168.1.200',
                        prefixIcon: Icon(Icons.wifi),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: portController,
                      decoration: const InputDecoration(
                        labelText: 'ポート',
                        hintText: '9100',
                        prefixIcon: Icon(Icons.settings_ethernet),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('用途設定', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),

                    // レジプリンター
                    SwitchListTile(
                      title: const Text('レジ（会計レシート）'),
                      subtitle: const Text('会計時にレシートを印刷'),
                      value: isReceiptPrinter,
                      onChanged: (val) => setDialogState(() {
                        isReceiptPrinter = val;
                        if (!val) hasDrawer = false;
                      }),
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.point_of_sale, color: Colors.blue),
                    ),

                    // ドロワー（レジの場合のみ）
                    if (isReceiptPrinter)
                      SwitchListTile(
                        title: const Text('キャッシュドロワー'),
                        subtitle: const Text('ドロワー付きプリンター'),
                        value: hasDrawer,
                        onChanged: (val) => setDialogState(() => hasDrawer = val),
                        contentPadding: const EdgeInsets.only(left: 32),
                        secondary: const Icon(Icons.point_of_sale, color: Colors.green),
                      ),

                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),

                    // カテゴリ別印刷設定
                    const Text('印刷カテゴリ', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text('チェックなし = 全カテゴリ印刷', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),

                    if (categories.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('カテゴリがありません', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ...categories.map((category) {
                        return CheckboxListTile(
                          title: Text(category.name),
                          value: selectedCategoryIds.contains(category.id),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          secondary: const Icon(Icons.restaurant, color: Colors.orange),
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedCategoryIds.add(category.id);
                              } else {
                                selectedCategoryIds.remove(category.id);
                              }
                            });
                          },
                        );
                      }),
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
                    final ip = ipController.text.trim();
                    final port = int.tryParse(portController.text) ?? 9100;
                    final name = nameController.text.trim();

                    if (ip.isEmpty) {
                      _showMessage('IPアドレスを入力してください', isError: true);
                      return;
                    }

                    final config = PrinterConfig(
                      id: 'printer_${DateTime.now().millisecondsSinceEpoch}',
                      name: name.isEmpty ? 'プリンター' : name,
                      connectionType: PrinterConnectionType.network,
                      ipAddress: ip,
                      port: port,
                      model: PrinterModel.generic,
                      autoprint: true,
                      isReceiptPrinter: isReceiptPrinter,
                      hasDrawer: hasDrawer,
                      categoryIds: selectedCategoryIds,
                    );

                    await _settingsService.addPrinter(config);
                    await _loadPrinters();
                    Navigator.pop(context);
                    _showMessage('プリンターを追加しました');
                  },
                  child: const Text('追加'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showPrinterDetailsDialog({required DiscoveredPrinter discovered}) async {
    final nameController = TextEditingController(text: discovered.name);
    bool isReceiptPrinter = discovered.model == PrinterModel.starMpop;
    bool hasDrawer = discovered.model == PrinterModel.starMpop;
    Set<String> selectedCategoryIds = {};

    // カテゴリ取得
    final staffUser = ref.read(staffUserProvider).value;
    final shopId = staffUser?.shopId ?? '';

    final result = await showDialog<PrinterConfig>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, dialogRef, _) {
          final categoriesAsync = dialogRef.watch(productCategoriesProvider(shopId));
          final categories = categoriesAsync.value ?? [];

          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('プリンター設定'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 検出情報
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            discovered.connectionType == PrinterConnectionType.bluetooth
                                ? Icons.bluetooth
                                : Icons.wifi,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(discovered.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(discovered.address, style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          if (discovered.model == PrinterModel.starMpop)
                            Chip(
                              label: const Text('mPOP'),
                              backgroundColor: Colors.orange.shade100,
                              labelStyle: const TextStyle(fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'プリンター名',
                        hintText: 'レジ / プリンター1',
                        prefixIcon: Icon(Icons.label),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('用途設定', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),

                    // レジプリンター
                    SwitchListTile(
                      title: const Text('レジ（会計レシート）'),
                      subtitle: const Text('会計時にレシートを印刷'),
                      value: isReceiptPrinter,
                      onChanged: (val) => setDialogState(() {
                        isReceiptPrinter = val;
                        if (!val) hasDrawer = false;
                      }),
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.point_of_sale, color: Colors.blue),
                    ),

                    // ドロワー（レジの場合のみ）
                    if (isReceiptPrinter)
                      SwitchListTile(
                        title: const Text('キャッシュドロワー'),
                        subtitle: const Text('ドロワー付きプリンター（mPOP等）'),
                        value: hasDrawer,
                        onChanged: (val) => setDialogState(() => hasDrawer = val),
                        contentPadding: const EdgeInsets.only(left: 32),
                        secondary: const Icon(Icons.point_of_sale, color: Colors.green),
                      ),

                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),

                    // カテゴリ別印刷設定
                    const Text('印刷カテゴリ', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text('チェックなし = 全カテゴリ印刷', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),

                    if (categories.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('カテゴリがありません', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ...categories.map((category) {
                        return CheckboxListTile(
                          title: Text(category.name),
                          value: selectedCategoryIds.contains(category.id),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          secondary: const Icon(Icons.restaurant, color: Colors.orange),
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedCategoryIds.add(category.id);
                              } else {
                                selectedCategoryIds.remove(category.id);
                              }
                            });
                          },
                        );
                      }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final config = PrinterConfig(
                      id: 'printer_${DateTime.now().millisecondsSinceEpoch}',
                      name: nameController.text.trim().isNotEmpty
                          ? nameController.text.trim()
                          : discovered.name,
                      connectionType: discovered.connectionType,
                      ipAddress: discovered.connectionType == PrinterConnectionType.network
                          ? discovered.address
                          : null,
                      bluetoothAddress: discovered.connectionType == PrinterConnectionType.bluetooth
                          ? discovered.address
                          : null,
                      bluetoothName: discovered.connectionType == PrinterConnectionType.bluetooth
                          ? discovered.name
                          : null,
                      starPortName: discovered.portName,
                      model: discovered.model,
                      autoprint: true,
                      isReceiptPrinter: isReceiptPrinter,
                      hasDrawer: hasDrawer,
                      categoryIds: selectedCategoryIds,
                    );
                    Navigator.pop(context, config);
                  },
                  child: const Text('追加'),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (result != null) {
      await _settingsService.addPrinter(result);
      await _loadPrinters();
      _showMessage('プリンターを追加しました');
    }
  }

  void _showEditPrinterDialog(PrinterConfig printer) {
    final nameController = TextEditingController(text: printer.name);
    bool isReceiptPrinter = printer.isReceiptPrinter;
    bool hasDrawer = printer.hasDrawer;
    bool autoprint = printer.autoprint;
    Set<String> selectedCategoryIds = Set.from(printer.categoryIds);

    // カテゴリ取得
    final staffUser = ref.read(staffUserProvider).value;
    final shopId = staffUser?.shopId ?? '';

    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, dialogRef, _) {
          final categoriesAsync = dialogRef.watch(productCategoriesProvider(shopId));
          final categories = categoriesAsync.value ?? [];

          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('プリンター編集'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'プリンター名',
                        prefixIcon: Icon(Icons.label),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 接続情報（読み取り専用）
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            printer.connectionType == PrinterConnectionType.bluetooth
                                ? Icons.bluetooth
                                : Icons.wifi,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              printer.connectionInfo,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('用途設定', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),

                    // レジプリンター
                    SwitchListTile(
                      title: const Text('レジ（会計レシート）'),
                      subtitle: const Text('会計時にレシートを印刷'),
                      value: isReceiptPrinter,
                      onChanged: (val) => setDialogState(() {
                        isReceiptPrinter = val;
                        if (!val) hasDrawer = false;
                      }),
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.point_of_sale, color: Colors.blue),
                    ),

                    // ドロワー（レジの場合のみ）
                    if (isReceiptPrinter)
                      SwitchListTile(
                        title: const Text('キャッシュドロワー'),
                        subtitle: const Text('ドロワー付きプリンター'),
                        value: hasDrawer,
                        onChanged: (val) => setDialogState(() => hasDrawer = val),
                        contentPadding: const EdgeInsets.only(left: 32),
                        secondary: const Icon(Icons.point_of_sale, color: Colors.green),
                      ),

                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('自動印刷'),
                      subtitle: const Text('注文時に自動で印刷'),
                      value: autoprint,
                      onChanged: (val) => setDialogState(() => autoprint = val),
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.autorenew, color: Colors.purple),
                    ),

                    const Divider(),
                    const SizedBox(height: 8),

                    // カテゴリ別印刷設定
                    const Text('印刷カテゴリ', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text('チェックなし = 全カテゴリ印刷', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),

                    if (categories.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('カテゴリがありません', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ...categories.map((category) {
                        return CheckboxListTile(
                          title: Text(category.name),
                          value: selectedCategoryIds.contains(category.id),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          secondary: const Icon(Icons.restaurant, color: Colors.orange),
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedCategoryIds.add(category.id);
                              } else {
                                selectedCategoryIds.remove(category.id);
                              }
                            });
                          },
                        );
                      }),
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
                    final updated = printer.copyWith(
                      name: nameController.text.trim(),
                      autoprint: autoprint,
                      isReceiptPrinter: isReceiptPrinter,
                      hasDrawer: hasDrawer,
                      categoryIds: selectedCategoryIds,
                    );
                    await _settingsService.updatePrinter(updated);
                    await _loadPrinters();
                    Navigator.pop(context);
                    _showMessage('保存しました');
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationProvider);
    final staffUser = ref.watch(staffUserProvider).value;
    final shopId = staffUser?.shopId ?? '';
    final categoriesAsync = ref.watch(productCategoriesProvider(shopId));
    final categories = categoriesAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _printers.isEmpty
              ? _buildEmptyState()
              : _buildPrinterList(categories),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPrinterDialog(),
        icon: const Icon(Icons.add),
        label: const Text('プリンター追加'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.print_disabled, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'プリンターが登録されていません',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            '右下のボタンからプリンターを追加してください',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildPrinterList(List<ProductCategory> categories) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _printers.length,
      itemBuilder: (context, index) {
        final printer = _printers[index];
        return _buildPrinterCard(printer, categories);
      },
    );
  }

  Widget _buildPrinterCard(PrinterConfig printer, List<ProductCategory> categories) {
    // 用途に応じた色
    Color mainColor = Colors.orange; // デフォルトはカテゴリープリンター
    if (printer.isReceiptPrinter) {
      mainColor = Colors.blue; // レジ
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: mainColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                printer.connectionType == PrinterConnectionType.bluetooth
                    ? Icons.bluetooth
                    : Icons.wifi,
                color: mainColor,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    printer.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(printer.connectionInfo),
                const SizedBox(height: 4),
                // 用途タグ
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    // レジ
                    if (printer.isReceiptPrinter)
                      _buildUsageTag('レジ', Icons.point_of_sale, Colors.blue),
                    // ドロワー
                    if (printer.hasDrawer)
                      _buildUsageTag('ドロワー', Icons.point_of_sale, Colors.green),
                    // カテゴリープリンター
                    if (printer.categoryIds.isEmpty && !printer.isReceiptPrinter)
                      _buildUsageTag('伝票(全)', Icons.receipt_long, Colors.orange)
                    else if (printer.categoryIds.isNotEmpty) ...[
                      ...printer.categoryIds.take(2).map((catId) {
                        final category = categories.where((c) => c.id == catId).firstOrNull;
                        final catName = category?.name ?? catId;
                        return _buildUsageTag(catName, Icons.receipt_long, Colors.orange);
                      }),
                      if (printer.categoryIds.length > 2)
                        _buildUsageTag('+${printer.categoryIds.length - 2}', Icons.more_horiz, Colors.grey),
                    ],
                  ],
                ),
              ],
            ),
            trailing: Switch(
              value: printer.autoprint,
              onChanged: (val) => _togglePrinter(printer, val),
              activeColor: mainColor,
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _testPrinter(printer),
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('テスト'),
                ),
                TextButton.icon(
                  onPressed: () => _showEditPrinterDialog(printer),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('編集'),
                ),
                TextButton.icon(
                  onPressed: () => _deletePrinter(printer),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('削除'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageTag(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }
}

/// プリンター追加シート
class _AddPrinterSheet extends StatelessWidget {
  final List<DiscoveredPrinter> discoveredPrinters;
  final bool isSearching;
  final VoidCallback onSearch;
  final ValueChanged<DiscoveredPrinter> onSelectDiscovered;
  final VoidCallback onManualInput;

  const _AddPrinterSheet({
    required this.discoveredPrinters,
    required this.isSearching,
    required this.onSearch,
    required this.onSelectDiscovered,
    required this.onManualInput,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'プリンターを追加',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Bluetooth検索
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isSearching ? null : onSearch,
                  icon: isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.bluetooth_searching),
                  label: Text(isSearching ? '検索中...' : 'Bluetoothプリンターを検索'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // IP手動入力
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onManualInput,
                  icon: const Icon(Icons.edit),
                  label: const Text('IPアドレスを手動入力（Wi-Fi/LAN）'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 検索結果
              if (discoveredPrinters.isNotEmpty) ...[
                Text(
                  '検出されたプリンター（${discoveredPrinters.length}台）',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: discoveredPrinters.length,
                    itemBuilder: (context, index) {
                      final printer = discoveredPrinters[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            printer.connectionType == PrinterConnectionType.bluetooth
                                ? Icons.bluetooth
                                : Icons.wifi,
                            color: Colors.blue,
                          ),
                          title: Text(printer.name),
                          subtitle: Text(printer.address),
                          trailing: printer.model == PrinterModel.starMpop
                              ? Chip(
                                  label: const Text('mPOP'),
                                  backgroundColor: Colors.orange.shade100,
                                  labelStyle: const TextStyle(fontSize: 10),
                                )
                              : null,
                          onTap: () => onSelectDiscovered(printer),
                        ),
                      );
                    },
                  ),
                ),
              ] else
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.print, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          '上のボタンから検索または入力してください',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
