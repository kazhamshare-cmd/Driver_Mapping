import 'package:flutter/foundation.dart';
import '../models/printer_config.dart';
import '../models/order.dart';
import '../models/table.dart';
import '../models/adjustment.dart';
import 'printer_service.dart';
import 'star_printer_service.dart';
import 'printer_settings_service.dart';

/// 統合プリンターサービス
/// IP接続（汎用ESC/POS）とBluetooth（Star mPOP）の両方を統一的に扱う
class UnifiedPrinterService {
  final PrinterService _networkPrinterService = PrinterService();
  final StarPrinterService _starPrinterService = StarPrinterService();
  final PrinterSettingsService _settingsService = PrinterSettingsService();

  /// 周辺のプリンターを検索（Starプリンターのみ対応）
  Future<List<DiscoveredPrinter>> searchPrinters() async {
    final results = <DiscoveredPrinter>[];

    try {
      final starPrinters = await _starPrinterService.searchPrinters();
      for (final printer in starPrinters) {
        final portName = printer.portName ?? '';

        // portNameからMACアドレスを抽出（BT:XX:XX:XX:XX:XX:XX形式の場合）
        String address = printer.macAddress ?? '';
        if (address.isEmpty && portName.startsWith('BT:')) {
          address = portName.substring(3); // "BT:"の後ろのMACアドレス部分
        } else if (address.isEmpty) {
          address = portName;
        }

        debugPrint('Discovered printer: name=${printer.modelName}, portName=$portName, macAddress=${printer.macAddress}, extracted=$address');

        results.add(DiscoveredPrinter(
          name: printer.modelName ?? 'Unknown Star Printer',
          address: address,
          portName: portName, // Star SDKが返すportNameをそのまま保存
          connectionType: portName.startsWith('BT:')
              ? PrinterConnectionType.bluetooth
              : PrinterConnectionType.network,
          model: _detectStarModel(printer.modelName),
        ));
      }
    } catch (e) {
      debugPrint('Starプリンター検索エラー: $e');
    }

    return results;
  }

  /// プリンターモデルを検出
  PrinterModel _detectStarModel(String? modelName) {
    if (modelName == null) return PrinterModel.generic;
    final lower = modelName.toLowerCase();
    if (lower.contains('mpop')) return PrinterModel.starMpop;
    if (lower.contains('tsp100')) return PrinterModel.starTsp100;
    return PrinterModel.generic;
  }

  /// 接続テスト
  Future<bool> testConnection(PrinterConfig config) async {
    switch (config.connectionType) {
      case PrinterConnectionType.network:
        if (config.ipAddress == null) return false;
        return _networkPrinterService.testConnection(config.ipAddress!, config.port);
      case PrinterConnectionType.bluetooth:
        return _starPrinterService.testConnection(config);
    }
  }

  /// 会計レシートを印刷（レシートプリンターを使用）
  Future<bool> printPaymentReceipt({
    required OrderModel order,
    String? shopName,
    List<AdjustmentModel> adjustments = const [],
    required double grandTotal,
    required String paymentMethod,
    double? receivedAmount,
    double? changeAmount,
    Map<String, dynamic>? receiptSettings,
    String? shopAddress,
    String? shopPhone,
  }) async {
    try {
      // 新方式：プリンターリストからレシートプリンターを取得
      final receiptPrinters = await _settingsService.getReceiptPrinters();
      if (receiptPrinters.isEmpty) {
        debugPrint('レシートプリンターが設定されていません');
        return false;
      }

      // 最初のレシートプリンターを使用
      final config = receiptPrinters.first;
      debugPrint('レシート印刷: ${config.name} (${config.connectionType.name})');

      return _printPaymentReceiptWithConfig(
        config: config,
        order: order,
        shopName: shopName,
        adjustments: adjustments,
        grandTotal: grandTotal,
        paymentMethod: paymentMethod,
        receivedAmount: receivedAmount,
        changeAmount: changeAmount,
        receiptSettings: receiptSettings,
        shopAddress: shopAddress,
        shopPhone: shopPhone,
      );
    } catch (e) {
      debugPrint('会計レシート印刷エラー: $e');
      return false;
    }
  }

  /// 指定した設定で会計レシートを印刷
  Future<bool> _printPaymentReceiptWithConfig({
    required PrinterConfig config,
    required OrderModel order,
    String? shopName,
    List<AdjustmentModel> adjustments = const [],
    required double grandTotal,
    required String paymentMethod,
    double? receivedAmount,
    double? changeAmount,
    Map<String, dynamic>? receiptSettings,
    String? shopAddress,
    String? shopPhone,
  }) async {
    switch (config.connectionType) {
      case PrinterConnectionType.network:
        return _networkPrinterService.printPaymentReceipt(
          order: order,
          shopName: shopName,
          adjustments: adjustments,
          grandTotal: grandTotal,
          paymentMethod: paymentMethod,
          receivedAmount: receivedAmount,
          changeAmount: changeAmount,
          receiptSettings: receiptSettings,
          shopAddress: shopAddress,
          shopPhone: shopPhone,
        );
      case PrinterConnectionType.bluetooth:
        return _starPrinterService.printPaymentReceipt(
          config: config,
          order: order,
          shopName: shopName,
          adjustments: adjustments,
          grandTotal: grandTotal,
          paymentMethod: paymentMethod,
          receivedAmount: receivedAmount,
          changeAmount: changeAmount,
          receiptSettings: receiptSettings,
          shopAddress: shopAddress,
          shopPhone: shopPhone,
        );
    }
  }

  /// 伝票を印刷（カテゴリ別プリンター振り分け）
  /// 1商品1枚、数量分個別印刷、カテゴリに応じたプリンターに出力
  Future<bool> printKitchenTicket(OrderModel order) async {
    try {
      final allPrinters = await _settingsService.getAllPrinters();
      final categoryPrinters = allPrinters.where((p) => p.isKitchenPrinter && p.autoprint).toList();

      if (categoryPrinters.isEmpty) {
        debugPrint('カテゴリープリンターが設定されていません');
        return false;
      }

      // 各商品を個別に印刷
      for (final item in order.items) {
        // この商品のカテゴリに対応するプリンターを検索
        final targetPrinters = categoryPrinters.where((p) =>
          p.shouldPrintCategory(item.categoryId)
        ).toList();

        if (targetPrinters.isEmpty) {
          debugPrint('カテゴリ ${item.categoryId} の印刷先プリンターがありません');
          continue;
        }

        // 対象の全プリンターに出力（複数プリンターに同じカテゴリが設定されている場合）
        for (final config in targetPrinters) {
          for (int i = 1; i <= item.quantity; i++) {
            final success = await _printSingleTicket(
              config: config,
              order: order,
              item: item,
              currentNumber: i,
              totalQuantity: item.quantity,
            );
            if (!success) {
              debugPrint('伝票印刷失敗: ${item.productName} -> ${config.name}');
            }
            // プリンター処理待ち
            await Future.delayed(const Duration(milliseconds: 300));
          }
        }
      }

      return true;
    } catch (e) {
      debugPrint('伝票印刷エラー: $e');
      return false;
    }
  }

  /// 1枚の伝票を印刷
  Future<bool> _printSingleTicket({
    required PrinterConfig config,
    required OrderModel order,
    required OrderItem item,
    required int currentNumber,
    required int totalQuantity,
  }) async {
    switch (config.connectionType) {
      case PrinterConnectionType.network:
        // 既存のネットワークプリンターサービスを使用
        // PrinterServiceは_generateSingleItemKitchenTicketBytesを持っているが、
        // 外部からは呼べないので、ここでは全体印刷を使う（後で改善）
        // TODO: PrinterServiceをリファクタして単品印刷を公開する
        return _networkPrinterService.printKitchenTicket(order);
      case PrinterConnectionType.bluetooth:
        return _starPrinterService.printKitchenTicket(
          config: config,
          order: order,
          item: item,
          currentNumber: currentNumber,
          totalQuantity: totalQuantity,
        );
    }
  }

  /// キャッシュドロワーを開放
  Future<bool> openCashDrawer() async {
    try {
      // ドロワー付きプリンターを検索
      final drawerPrinter = await _settingsService.getDrawerPrinter();
      if (drawerPrinter != null) {
        return _openDrawerWithConfig(drawerPrinter);
      }

      // 旧設定のドロワー（後方互換性）
      final isDrawerEnabled = await _settingsService.isDrawerEnabled();
      if (isDrawerEnabled) {
        return _networkPrinterService.openCashDrawer();
      }

      debugPrint('ドロワーが設定されていません');
      return false;
    } catch (e) {
      debugPrint('ドロワー開放エラー: $e');
      return false;
    }
  }

  /// 指定した設定でドロワーを開放
  Future<bool> _openDrawerWithConfig(PrinterConfig config) async {
    switch (config.connectionType) {
      case PrinterConnectionType.network:
        return _networkPrinterService.openCashDrawer();
      case PrinterConnectionType.bluetooth:
        return _starPrinterService.openCashDrawer(config);
    }
  }

  /// 注文レシートを印刷（会計前の確認用）
  Future<bool> printOrderReceipt(OrderModel order, {String? shopName}) async {
    try {
      final isEnabled = await _settingsService.isReceiptPrinterEnabled();
      if (!isEnabled) return false;

      final config = await _settingsService.getReceiptPrinter();
      if (config == null) return false;

      if (config.connectionType == PrinterConnectionType.network) {
        return _networkPrinterService.printOrderReceipt(order, shopName: shopName);
      } else {
        // Starプリンターでも同じ形式で印刷（簡易版）
        // TODO: StarPrinterServiceにprintOrderReceiptを追加
        return false;
      }
    } catch (e) {
      debugPrint('注文レシート印刷エラー: $e');
      return false;
    }
  }

  /// テーブルQRコードを印刷
  Future<bool> printTableQR(TableModel table, {String? shopCode}) async {
    try {
      // 新方式：プリンターリストからレシートプリンターを取得
      final receiptPrinters = await _settingsService.getReceiptPrinters();
      if (receiptPrinters.isEmpty) {
        throw Exception('レシートプリンターが設定されていません');
      }

      // 最初のレシートプリンターを使用
      final config = receiptPrinters.first;
      debugPrint('QR印刷: ${config.name} (${config.connectionType.name})');

      if (config.connectionType == PrinterConnectionType.network) {
        return _networkPrinterService.printTableQR(table, shopCode: shopCode);
      } else {
        // Bluetoothプリンター（Star mPOP等）
        return _starPrinterService.printTableQR(
          config: config,
          table: table,
          shopCode: shopCode,
        );
      }
    } catch (e) {
      debugPrint('QR印刷エラー: $e');
      rethrow;
    }
  }

  /// テスト印刷
  Future<bool> printTest(PrinterConfig config) async {
    try {
      switch (config.connectionType) {
        case PrinterConnectionType.network:
          if (config.ipAddress == null) return false;
          return _networkPrinterService.testConnection(config.ipAddress!, config.port);
        case PrinterConnectionType.bluetooth:
          // Starプリンターでテスト印刷を実行
          return _starPrinterService.printTest(config);
      }
    } catch (e) {
      debugPrint('テスト印刷エラー: $e');
      return false;
    }
  }
}

/// 検索で発見されたプリンター
class DiscoveredPrinter {
  final String name;
  final String address;
  final String portName;
  final PrinterConnectionType connectionType;
  final PrinterModel model;

  DiscoveredPrinter({
    required this.name,
    required this.address,
    required this.portName,
    required this.connectionType,
    required this.model,
  });

  /// PrinterConfigに変換
  PrinterConfig toConfig({
    required String id,
    String? customName,
    bool isReceiptPrinter = false,
    bool hasDrawer = false,
    Set<String>? categoryIds,
  }) {
    return PrinterConfig(
      id: id,
      name: customName ?? name,
      connectionType: connectionType,
      ipAddress: connectionType == PrinterConnectionType.network ? address : null,
      bluetoothAddress: connectionType == PrinterConnectionType.bluetooth ? address : null,
      bluetoothName: connectionType == PrinterConnectionType.bluetooth ? name : null,
      starPortName: portName, // Star SDK用ポート名を保存
      model: model,
      isReceiptPrinter: isReceiptPrinter,
      hasDrawer: hasDrawer || model == PrinterModel.starMpop, // mPOPはドロワー内蔵
      categoryIds: categoryIds,
    );
  }
}
