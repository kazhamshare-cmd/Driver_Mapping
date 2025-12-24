import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/printer_config.dart';

/// ドロワー信号のピン設定
enum DrawerPin {
  pin2,  // ピン2（標準）
  pin5,  // ピン5
}

/// プリンター設定を管理するサービス
/// 複数プリンター（レシート/キッチン）それぞれの設定を管理
class PrinterSettingsService {
  // 旧設定キー（後方互換性のため残す）
  static const String _printerIpKey = 'printer_ip';
  static const String _printerPortKey = 'printer_port';
  static const String _printerEnabledKey = 'printer_enabled';
  static const String _drawerEnabledKey = 'drawer_enabled';
  static const String _drawerPinKey = 'drawer_pin';

  // 新しい複数プリンター設定キー
  static const String _receiptPrinterKey = 'receipt_printer_config';
  static const String _kitchenPrinterKey = 'kitchen_printer_config';
  static const String _receiptPrinterEnabledKey = 'receipt_printer_enabled';
  static const String _kitchenPrinterEnabledKey = 'kitchen_printer_enabled';

  // 複数プリンターリスト用キー
  static const String _printerListKey = 'printer_list';

  // ========================================
  // 複数プリンターリスト管理（新方式）
  // ========================================

  /// すべてのプリンターを取得
  Future<List<PrinterConfig>> getAllPrinters() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_printerListKey);
    if (json == null) {
      // 旧設定からマイグレーション
      final migrated = <PrinterConfig>[];
      final receipt = await getReceiptPrinter();
      if (receipt != null) migrated.add(receipt);
      final kitchen = await getKitchenPrinter();
      if (kitchen != null) migrated.add(kitchen);
      return migrated;
    }
    final List<dynamic> list = jsonDecode(json);
    return list.asMap().entries.map((entry) {
      return PrinterConfig.fromMap(entry.value as Map<String, dynamic>, 'printer_${entry.key}');
    }).toList();
  }

  /// すべてのプリンターを保存
  Future<void> saveAllPrinters(List<PrinterConfig> printers) async {
    final prefs = await SharedPreferences.getInstance();
    final list = printers.map((p) => p.toMap()).toList();
    await prefs.setString(_printerListKey, jsonEncode(list));
  }

  /// プリンターを追加
  Future<void> addPrinter(PrinterConfig printer) async {
    final printers = await getAllPrinters();
    printers.add(printer);
    await saveAllPrinters(printers);
  }

  /// プリンターを更新
  Future<void> updatePrinter(PrinterConfig printer) async {
    final printers = await getAllPrinters();
    final index = printers.indexWhere((p) => p.id == printer.id);
    if (index >= 0) {
      printers[index] = printer;
      await saveAllPrinters(printers);
    }
  }

  /// プリンターを削除
  Future<void> deletePrinter(String printerId) async {
    final printers = await getAllPrinters();
    printers.removeWhere((p) => p.id == printerId);
    await saveAllPrinters(printers);

    // 全プリンターが削除されたら旧設定もクリア
    if (printers.isEmpty) {
      await clearSettings();
    }
  }

  /// レシートプリンターを取得（有効なもの）
  Future<List<PrinterConfig>> getReceiptPrinters() async {
    final printers = await getAllPrinters();
    return printers.where((p) => p.isReceiptPrinter && p.autoprint).toList();
  }

  /// 指定カテゴリの印刷対象プリンターを取得
  Future<List<PrinterConfig>> getKitchenPrintersForCategory(String? categoryId) async {
    final printers = await getAllPrinters();
    return printers.where((p) =>
      p.isKitchenPrinter &&
      p.autoprint &&
      p.shouldPrintCategory(categoryId)
    ).toList();
  }

  /// ドロワー付きプリンターを取得
  Future<PrinterConfig?> getDrawerPrinter() async {
    final printers = await getAllPrinters();
    return printers.where((p) => p.hasDrawer && p.autoprint).firstOrNull;
  }

  // ========================================
  // 旧方式（レシート/キッチン各1台）- 互換性維持
  // ========================================

  /// レシートプリンター設定を保存
  Future<void> saveReceiptPrinter(PrinterConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_receiptPrinterKey, jsonEncode(config.toMap()));
  }

  /// レシートプリンター設定を取得
  Future<PrinterConfig?> getReceiptPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_receiptPrinterKey);
    if (json == null) {
      // 旧設定からマイグレーション
      final ip = await getPrinterIp();
      if (ip != null && ip.isNotEmpty) {
        final port = await getPrinterPort();
        return PrinterConfig(
          id: 'receipt_migrated',
          name: 'レシートプリンター',
          connectionType: PrinterConnectionType.network,
          ipAddress: ip,
          port: port,
          model: PrinterModel.generic,
          isReceiptPrinter: true,
        );
      }
      return null;
    }
    return PrinterConfig.fromMap(jsonDecode(json), 'receipt');
  }

  /// キッチンプリンター設定を保存
  Future<void> saveKitchenPrinter(PrinterConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kitchenPrinterKey, jsonEncode(config.toMap()));
  }

  /// キッチンプリンター設定を取得
  Future<PrinterConfig?> getKitchenPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kitchenPrinterKey);
    if (json == null) return null;
    return PrinterConfig.fromMap(jsonDecode(json), 'kitchen');
  }

  /// レシートプリンターの有効/無効を保存
  Future<void> setReceiptPrinterEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_receiptPrinterEnabledKey, enabled);
  }

  /// レシートプリンターの有効/無効を取得
  Future<bool> isReceiptPrinterEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // 旧設定にフォールバック
    return prefs.getBool(_receiptPrinterEnabledKey) ??
           prefs.getBool(_printerEnabledKey) ?? false;
  }

  /// キッチンプリンターの有効/無効を保存
  Future<void> setKitchenPrinterEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kitchenPrinterEnabledKey, enabled);
  }

  /// キッチンプリンターの有効/無効を取得
  Future<bool> isKitchenPrinterEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kitchenPrinterEnabledKey) ?? false;
  }

  // ========================================
  // 旧API（後方互換性のため維持）
  // ========================================

  /// プリンターのIPアドレスを保存
  Future<void> savePrinterIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_printerIpKey, ip);
  }

  /// プリンターのIPアドレスを取得
  Future<String?> getPrinterIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_printerIpKey);
  }

  /// プリンターのポート番号を保存
  Future<void> savePrinterPort(int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_printerPortKey, port);
  }

  /// プリンターのポート番号を取得（デフォルト: 9100）
  Future<int> getPrinterPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_printerPortKey) ?? 9100;
  }

  /// プリンターの有効/無効を保存
  Future<void> setPrinterEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_printerEnabledKey, enabled);
  }

  /// プリンターの有効/無効を取得
  Future<bool> isPrinterEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_printerEnabledKey) ?? false;
  }

  /// ドロワーの有効/無効を保存
  Future<void> setDrawerEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_drawerEnabledKey, enabled);
  }

  /// ドロワーの有効/無効を取得
  Future<bool> isDrawerEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_drawerEnabledKey) ?? false;
  }

  /// ドロワーのピン設定を保存
  Future<void> saveDrawerPin(DrawerPin pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_drawerPinKey, pin.index);
  }

  /// ドロワーのピン設定を取得（デフォルト: pin2）
  Future<DrawerPin> getDrawerPin() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_drawerPinKey) ?? 0;
    return DrawerPin.values[index];
  }

  /// すべての設定をクリア
  Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_printerIpKey);
    await prefs.remove(_printerPortKey);
    await prefs.remove(_printerEnabledKey);
    await prefs.remove(_drawerEnabledKey);
    await prefs.remove(_drawerPinKey);
    await prefs.remove(_receiptPrinterKey);
    await prefs.remove(_kitchenPrinterKey);
    await prefs.remove(_receiptPrinterEnabledKey);
    await prefs.remove(_kitchenPrinterEnabledKey);
    await prefs.remove(_printerListKey);  // 新方式のプリンターリストもクリア
  }
}
