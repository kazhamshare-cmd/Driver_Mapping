import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../models/order.dart';
import '../models/table.dart';
import '../models/adjustment.dart';
import 'printer_settings_service.dart';

/// Wi-Fi経由でESC/POSプリンターに接続して印刷するサービス
class PrinterService {
  final PrinterSettingsService _settingsService = PrinterSettingsService();

  /// 接続テスト（テスト印刷を実行）
  Future<bool> testConnection(String ip, int port) async {
    Socket? socket;
    try {
      // ソケット接続（タイムアウト2秒）
      socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 2));

      // テスト印刷データ生成
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      // 英語のみでテスト
      bytes += generator.text('Connection Test',
          styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
      bytes += generator.feed(1);
      bytes += generator.text('IP: $ip');
      bytes += generator.text('Port: $port');
      bytes += generator.feed(2);
      bytes += generator.cut();

      // 送信
      socket.add(Uint8List.fromList(bytes));
      await socket.flush();
      
      return true;
    } catch (e) {
      debugPrint('接続テストエラー: $e');
      return false;
    } finally {
      await socket?.close();
    }
  }

  /// 注文レシートを印刷
  Future<bool> printOrderReceipt(OrderModel order, {String? shopName}) async {
    try {
      final isEnabled = await _settingsService.isPrinterEnabled();
      if (!isEnabled) return false;

      final ip = await _settingsService.getPrinterIp();
      final port = await _settingsService.getPrinterPort();

      if (ip == null || ip.isEmpty) return false;

      // ESC/POSコマンドを生成（日本語対応）
      final bytes = await _generateReceiptBytes(order, shopName: shopName);

      // プリンターに接続して印刷
      await _printToNetwork(ip, port, bytes);

      debugPrint('印刷成功: 注文ID ${order.id}');
      return true;
    } catch (e) {
      debugPrint('印刷エラー: $e');
      return false;
    }
  }

  /// 注文伝票（キッチン用）を印刷
  /// 1商品1レシート、数量が複数の場合は個別に出力（例：ビール×3 → ビール1/3, 2/3, 3/3）
  Future<bool> printKitchenTicket(OrderModel order) async {
    try {
      final isEnabled = await _settingsService.isPrinterEnabled();
      if (!isEnabled) return false;

      final ip = await _settingsService.getPrinterIp();
      final port = await _settingsService.getPrinterPort();

      if (ip == null || ip.isEmpty) return false;

      // 各商品を個別に印刷
      for (final item in order.items) {
        // 数量分ループして個別印刷
        for (int i = 1; i <= item.quantity; i++) {
          final bytes = await _generateSingleItemKitchenTicketBytes(
            order: order,
            item: item,
            currentNumber: i,
            totalQuantity: item.quantity,
          );
          await _printToNetwork(ip, port, bytes);
          // プリンター処理のため少し待機
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      return true;
    } catch (e) {
      debugPrint('キッチン伝票印刷エラー: $e');
      return false;
    }
  }

  /// 会計レシートを印刷（預かり金額・お釣り対応）
  Future<bool> printPaymentReceipt({
    required OrderModel order,
    String? shopName,
    List<AdjustmentModel> adjustments = const [],
    required double grandTotal,
    required String paymentMethod,
    double? receivedAmount,
    double? changeAmount,
    // レシート設定
    Map<String, dynamic>? receiptSettings,
    String? shopAddress,
    String? shopPhone,
  }) async {
    try {
      final isEnabled = await _settingsService.isPrinterEnabled();
      if (!isEnabled) return false;

      final ip = await _settingsService.getPrinterIp();
      final port = await _settingsService.getPrinterPort();

      if (ip == null || ip.isEmpty) return false;

      final bytes = await _generatePaymentReceiptBytes(
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

      await _printToNetwork(ip, port, bytes);

      debugPrint('会計レシート印刷成功: 注文ID ${order.id}');
      return true;
    } catch (e) {
      debugPrint('会計レシート印刷エラー: $e');
      return false;
    }
  }

  /// 会計レシート用のESC/POSバイト列を生成
  Future<Uint8List> _generatePaymentReceiptBytes({
    required OrderModel order,
    String? shopName,
    required List<AdjustmentModel> adjustments,
    required double grandTotal,
    required String paymentMethod,
    double? receivedAmount,
    double? changeAmount,
    Map<String, dynamic>? receiptSettings,
    String? shopAddress,
    String? shopPhone,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    final List<int> bytes = [];

    // レシート設定を取得
    final headerMessage = receiptSettings?['headerMessage'] as String? ?? '';
    final footerMessage = receiptSettings?['footerMessage'] as String? ?? 'ありがとうございました';
    final showShopAddress = receiptSettings?['showShopAddress'] as bool? ?? true;
    final showShopPhone = receiptSettings?['showShopPhone'] as bool? ?? true;
    final showTaxDetails = receiptSettings?['showTaxDetails'] as bool? ?? true;
    final registrationNumber = receiptSettings?['showRegistrationNumber'] as String? ?? '';
    final logoUrl = receiptSettings?['logoUrl'] as String?;

    // 漢字モードON
    bytes.addAll([0x1C, 0x26]);

    // ロゴ画像印刷（設定されている場合）
    if (logoUrl != null && logoUrl.isNotEmpty) {
      try {
        final logoImage = await _downloadAndProcessLogo(logoUrl);
        if (logoImage != null) {
          bytes.addAll(generator.image(logoImage, align: PosAlign.center));
          bytes.addAll(generator.feed(1));
        }
      } catch (e) {
        debugPrint('ロゴ画像印刷エラー: $e');
      }
    }

    // ヘッダー（店舗名）
    bytes.addAll(generator.reset());
    bytes.addAll(generator.textEncoded(
      await _encode(shopName ?? '店舗名'),
      styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2),
    ));
    bytes.addAll(generator.feed(1));

    // 店舗住所（設定がONの場合）
    if (showShopAddress && shopAddress != null && shopAddress.isNotEmpty) {
      bytes.addAll(generator.textEncoded(
        await _encode(shopAddress),
        styles: const PosStyles(align: PosAlign.center),
      ));
    }

    // 電話番号（設定がONの場合）
    if (showShopPhone && shopPhone != null && shopPhone.isNotEmpty) {
      bytes.addAll(generator.textEncoded(
        await _encode('TEL: $shopPhone'),
        styles: const PosStyles(align: PosAlign.center),
      ));
    }

    // インボイス登録番号
    if (registrationNumber.isNotEmpty) {
      bytes.addAll(generator.textEncoded(
        await _encode('登録番号: $registrationNumber'),
        styles: const PosStyles(align: PosAlign.center),
      ));
    }

    bytes.addAll(generator.feed(1));

    bytes.addAll(generator.textEncoded(
      await _encode('領収書'),
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.feed(1));

    // ヘッダーメッセージ（設定されている場合）
    if (headerMessage.isNotEmpty) {
      bytes.addAll(generator.textEncoded(
        await _encode(headerMessage),
        styles: const PosStyles(align: PosAlign.center),
      ));
      bytes.addAll(generator.feed(1));
    }

    // 日時
    bytes.addAll(generator.text('Date: ${_formatDateTime(DateTime.now())}'));
    bytes.addAll(generator.textEncoded(await _encode('テーブル: ${order.tableNumber}')));
    bytes.addAll(generator.hr());

    // 商品明細
    for (final item in order.items) {
      bytes.addAll(generator.textEncoded(
        await _encode(item.productName),
        styles: const PosStyles(align: PosAlign.left),
      ));

      bytes.addAll(generator.row([
        PosColumn(text: ' x${item.quantity}', width: 6),
        PosColumn(text: '${item.subtotal.toInt()}', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]));

      if (item.selectedOptions.isNotEmpty) {
        for (final option in item.selectedOptions) {
          bytes.addAll(generator.textEncoded(
            await _encode('  ${option.optionName}: ${option.value}'),
          ));
        }
      }

      if (item.notes != null && item.notes!.isNotEmpty) {
        bytes.addAll(generator.textEncoded(
          await _encode('  備考: ${item.notes}'),
        ));
      }
    }

    bytes.addAll(generator.hr());

    // 小計
    bytes.addAll(generator.row([
      PosColumn(textEncoded: await _encode('小計'), width: 6),
      PosColumn(text: '${order.subtotal.toInt()}', width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]));

    // 調整項目（割引・加算等）
    for (final adj in adjustments) {
      String label = adj.name;
      String valueStr;
      switch (adj.type) {
        case AdjustmentType.discountAmount:
          valueStr = '-${adj.value.toInt()}';
          break;
        case AdjustmentType.discountPercent:
          final discountAmount = order.subtotal * (adj.value / 100);
          valueStr = '-${discountAmount.toInt()} (${adj.value.toInt()}%)';
          break;
        case AdjustmentType.surchargeTaxExcluded:
        case AdjustmentType.surchargeTaxIncluded:
          valueStr = '+${adj.value.toInt()}';
          break;
        case AdjustmentType.paymentVoucher:
          label = '${adj.name}(充当)';
          valueStr = '-${adj.value.toInt()}';
          break;
      }
      bytes.addAll(generator.row([
        PosColumn(textEncoded: await _encode(label), width: 6),
        PosColumn(text: valueStr, width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]));
    }

    // 消費税（設定がONの場合のみ表示）
    if (showTaxDetails) {
      final taxAmount = (grandTotal / 1.1 * 0.1).toInt();
      bytes.addAll(generator.row([
        PosColumn(textEncoded: await _encode('(内消費税)'), width: 6),
        PosColumn(text: '$taxAmount', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]));
    }

    bytes.addAll(generator.hr());

    // 合計
    bytes.addAll(generator.textEncoded(
      await _encode('合計: ¥${grandTotal.toInt()}'),
      styles: const PosStyles(align: PosAlign.right, height: PosTextSize.size2, width: PosTextSize.size2),
    ));
    bytes.addAll(generator.feed(1));

    bytes.addAll(generator.hr());

    // 支払い方法
    final paymentLabel = paymentMethod == 'cash' ? '現金' : 'カード/その他';
    bytes.addAll(generator.textEncoded(
      await _encode('お支払い: $paymentLabel'),
    ));

    // 現金の場合は預かり・お釣りを表示
    if (paymentMethod == 'cash' && receivedAmount != null) {
      bytes.addAll(generator.row([
        PosColumn(textEncoded: await _encode('お預かり'), width: 6),
        PosColumn(text: '${receivedAmount.toInt()}', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]));

      bytes.addAll(generator.textEncoded(
        await _encode('お釣り: ¥${(changeAmount ?? 0).toInt()}'),
        styles: const PosStyles(align: PosAlign.right, height: PosTextSize.size2, width: PosTextSize.size2, bold: true),
      ));
      bytes.addAll(generator.feed(1));
    }

    bytes.addAll(generator.hr());

    // フッター（設定されたメッセージを使用）
    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.textEncoded(
      await _encode(footerMessage),
      styles: const PosStyles(align: PosAlign.center),
    ));

    bytes.addAll(generator.feed(3));

    // 漢字モードOFF
    bytes.addAll([0x1C, 0x2E]);
    bytes.addAll(generator.cut());

    return Uint8List.fromList(bytes);
  }

  /// テキストをShift_JISに変換してバイト列(Uint8List)を取得
  /// ※ここを修正しました（List<int>ではなくUint8Listを返す）
  Future<Uint8List> _encode(String text) async {
    try {
      final encoded = await CharsetConverter.encode('Shift_JIS', text);
      return encoded;
    } catch (e) {
      debugPrint('エンコードエラー: $e');
      // 失敗した場合はUTF-8のまま（Uint8Listに変換して返す）
      return Uint8List.fromList(text.codeUnits);
    }
  }

  /// レシート用のESC/POSバイト列を生成
  Future<Uint8List> _generateReceiptBytes(
    OrderModel order, {
    String? shopName,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    final List<int> bytes = [];

    // 漢字モードON
    bytes.addAll([0x1C, 0x26]);

    // ヘッダー
    bytes.addAll(generator.reset());
    bytes.addAll(generator.textEncoded(
      await _encode(shopName ?? '店舗名'),
      styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2),
    ));
    bytes.addAll(generator.feed(1));

    bytes.addAll(generator.textEncoded(
      await _encode('レシート'),
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.text('Order: ${order.orderNumber ?? order.id}'));
    bytes.addAll(generator.textEncoded(await _encode('テーブル: ${order.tableNumber}')));
    bytes.addAll(generator.text('Date: ${_formatDateTime(order.orderedAt)}'));
    bytes.addAll(generator.hr());

    // アイテム
    for (final item in order.items) {
      bytes.addAll(generator.textEncoded(
        await _encode(item.productName),
        styles: const PosStyles(align: PosAlign.left),
      ));
      
      bytes.addAll(generator.row([
        PosColumn(text: ' x${item.quantity}', width: 6),
        PosColumn(text: '${item.subtotal.toInt()}', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]));

      if (item.selectedOptions.isNotEmpty) {
        for (final option in item.selectedOptions) {
          bytes.addAll(generator.textEncoded(
            await _encode('  ${option.optionName}: ${option.value}'),
          ));
        }
      }
      
      if (item.notes != null && item.notes!.isNotEmpty) {
        bytes.addAll(generator.textEncoded(
          await _encode('  Note: ${item.notes}'),
        ));
      }
    }

    bytes.addAll(generator.hr());

    // 合計
    bytes.addAll(generator.textEncoded(
      await _encode('合計: ¥${order.totalAmount.toInt()}'),
      styles: const PosStyles(align: PosAlign.right, height: PosTextSize.size2, width: PosTextSize.size2),
    ));

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.textEncoded(
      await _encode('ありがとうございました'),
      styles: const PosStyles(align: PosAlign.center),
    ));
    
    bytes.addAll(generator.feed(3));
    
    // 漢字モードOFF
    bytes.addAll([0x1C, 0x2E]);
    bytes.addAll(generator.cut());

    return Uint8List.fromList(bytes);
  }

  /// 1商品1枚のキッチン伝票用ESC/POSバイト列を生成
  Future<Uint8List> _generateSingleItemKitchenTicketBytes({
    required OrderModel order,
    required OrderItem item,
    required int currentNumber,
    required int totalQuantity,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    final List<int> bytes = [];

    // プリンターをリセットして初期状態に戻す（文字サイズ等をリセット）
    bytes.addAll(generator.reset());

    // 漢字モードON
    bytes.addAll([0x1C, 0x26]);

    // 調理伝票（通常フォント）
    bytes.addAll(generator.textEncoded(
      await _encode('調理伝票'),
      styles: const PosStyles(align: PosAlign.center),
    ));

    // テーブル番号を大きく表示（size3 = 3倍）
    bytes.addAll(generator.textEncoded(
      await _encode('【 ${order.tableNumber} 】'),
      styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size3, width: PosTextSize.size3, bold: true),
    ));

    // 時刻（少し大きめ、size2）
    bytes.addAll(generator.textEncoded(
      await _encode(_formatTime(order.orderedAt)),
      styles: const PosStyles(align: PosAlign.left, height: PosTextSize.size2, width: PosTextSize.size2),
    ));
    bytes.addAll(generator.hr());

    // 商品名を特大で表示（size3 = 3倍）
    bytes.addAll(generator.textEncoded(
      await _encode(item.productName),
      styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size3, width: PosTextSize.size3, bold: true),
    ));
    bytes.addAll(generator.feed(1));

    // 数量表示（複数の場合のみ「1/3」形式で表示）
    if (totalQuantity > 1) {
      bytes.addAll(generator.textEncoded(
        await _encode('$currentNumber / $totalQuantity'),
        styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2),
      ));
      bytes.addAll(generator.feed(1));
    }

    // オプション
    if (item.selectedOptions.isNotEmpty) {
      bytes.addAll(generator.hr());
      for (final option in item.selectedOptions) {
        bytes.addAll(generator.textEncoded(
          await _encode('${option.optionName}: ${option.value}'),
          styles: const PosStyles(align: PosAlign.left, bold: true),
        ));
      }
    }

    // 備考（目立つように）
    if (item.notes != null && item.notes!.isNotEmpty) {
      bytes.addAll(generator.hr());
      bytes.addAll(generator.textEncoded(
        await _encode('※ ${item.notes}'),
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ));
    }

    bytes.addAll(generator.feed(2));
    // 漢字モードOFF
    bytes.addAll([0x1C, 0x2E]);
    bytes.addAll(generator.cut());

    return Uint8List.fromList(bytes);
  }

  /// ネットワーク経由で印刷
  Future<void> _printToNetwork(String ip, int port, Uint8List bytes) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      socket.add(bytes);
      await socket.flush();
      await Future.delayed(const Duration(milliseconds: 500));
    } finally {
      await socket?.close();
    }
  }

  /// キャッシュドロワーを開放
  /// ESC p m t1 t2 コマンドを送信
  /// m: ピン番号 (0=ピン2, 1=ピン5)
  /// t1, t2: パルス幅 (25 = 200ms ON, 250 = 200ms OFF)
  Future<bool> openCashDrawer() async {
    try {
      final isDrawerEnabled = await _settingsService.isDrawerEnabled();
      if (!isDrawerEnabled) {
        debugPrint('ドロワーは無効化されています');
        return false;
      }

      final ip = await _settingsService.getPrinterIp();
      final port = await _settingsService.getPrinterPort();

      if (ip == null || ip.isEmpty) {
        debugPrint('プリンターIPが設定されていません');
        return false;
      }

      // ドロワーピン設定を取得
      final drawerPin = await _settingsService.getDrawerPin();
      final pinByte = drawerPin == DrawerPin.pin2 ? 0 : 1;

      // ESC p m t1 t2 コマンド
      // ESC = 0x1B, p = 0x70
      // m = 0 (ピン2) or 1 (ピン5)
      // t1 = 25 (ON時間: 25 * 2ms = 50ms)
      // t2 = 250 (OFF時間: 250 * 2ms = 500ms)
      final bytes = Uint8List.fromList([0x1B, 0x70, pinByte, 25, 250]);

      await _printToNetwork(ip, port, bytes);

      debugPrint('ドロワー開放成功');
      return true;
    } catch (e) {
      debugPrint('ドロワー開放エラー: $e');
      return false;
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// テーブルQRコードを印刷
  /// [shopCode] 店舗コード（QRコードURL用）
  Future<bool> printTableQR(TableModel table, {String? shopCode}) async {
    try {
      final isEnabled = await _settingsService.isPrinterEnabled();
      if (!isEnabled) {
        throw Exception('プリンターが有効になっていません');
      }

      final ip = await _settingsService.getPrinterIp();
      final port = await _settingsService.getPrinterPort();

      if (ip == null || ip.isEmpty) {
        throw Exception('プリンターIPが設定されていません');
      }

      final bytes = await _generateTableQRBytes(table, shopCode: shopCode);
      await _printToNetwork(ip, port, bytes);

      debugPrint('QR印刷成功: テーブル ${table.tableNumber}');
      return true;
    } catch (e) {
      debugPrint('QR印刷エラー: $e');
      rethrow;
    }
  }

  /// テーブルQR用のESC/POSバイト列を生成
  Future<Uint8List> _generateTableQRBytes(TableModel table, {String? shopCode}) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    final List<int> bytes = [];

    // 漢字モードON
    bytes.addAll([0x1C, 0x26]);

    // ヘッダー
    bytes.addAll(generator.reset());
    bytes.addAll(generator.textEncoded(
      await _encode('テーブル ${table.tableNumber}'),
      styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2),
    ));
    bytes.addAll(generator.feed(1));

    // QRコード用URL
    // Shop DashboardのQRコードと同じURL形式を使用
    // https://reservation-customer-booking.web.app/order/{shopCode}/{tableId}
    final qrUrl = shopCode != null
        ? 'https://reservation-customer-booking.web.app/order/$shopCode/${table.id}'
        : 'https://reservation-customer-booking.web.app/order/${table.shopId}/${table.id}';

    bytes.addAll(generator.textEncoded(
      await _encode('モバイルオーダー'),
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.feed(1));

    // QRコードを印刷
    bytes.addAll(generator.qrcode(qrUrl, size: QRSize.size6));
    bytes.addAll(generator.feed(1));

    bytes.addAll(generator.textEncoded(
      await _encode('スマートフォンで'),
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.textEncoded(
      await _encode('読み取ってください'),
      styles: const PosStyles(align: PosAlign.center),
    ));

    bytes.addAll(generator.feed(3));

    // 漢字モードOFF
    bytes.addAll([0x1C, 0x2E]);
    bytes.addAll(generator.cut());

    return Uint8List.fromList(bytes);
  }

  /// URLからロゴ画像をダウンロードして印刷用に変換
  Future<img.Image?> _downloadAndProcessLogo(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        debugPrint('ロゴ画像ダウンロード失敗: ${response.statusCode}');
        return null;
      }

      final imageBytes = response.bodyBytes;
      var image = img.decodeImage(imageBytes);
      if (image == null) {
        debugPrint('ロゴ画像デコード失敗');
        return null;
      }

      // 80mm幅プリンター用にリサイズ（最大幅576px、高さは比率維持）
      const maxWidth = 400; // 中央配置のため少し小さめに
      if (image.width > maxWidth) {
        image = img.copyResize(image, width: maxWidth);
      }

      // グレースケールに変換（サーマルプリンター用）
      image = img.grayscale(image);

      return image;
    } catch (e) {
      debugPrint('ロゴ画像処理エラー: $e');
      return null;
    }
  }
}