import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_star_prnt/flutter_star_prnt.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/printer_config.dart';
import '../models/order.dart';
import '../models/adjustment.dart';
import '../models/table.dart';

/// Star社プリンター（mPOP等）用サービス
/// Bluetooth接続対応
class StarPrinterService {
  /// 周辺のStarプリンターを検索
  Future<List<PortInfo>> searchPrinters() async {
    try {
      // Bluetooth検索（mPOP等）
      final bluetoothPrinters = await StarPrnt.portDiscovery(StarPortType.Bluetooth);

      // LAN検索（TSP100LAN等）
      final lanPrinters = await StarPrnt.portDiscovery(StarPortType.LAN);

      return [...bluetoothPrinters, ...lanPrinters];
    } catch (e) {
      debugPrint('プリンター検索エラー: $e');
      return [];
    }
  }

  /// 接続テスト
  Future<bool> testConnection(PrinterConfig config) async {
    try {
      final portName = _getPortName(config);
      if (portName == null) return false;

      final status = await StarPrnt.getStatus(
        portName: portName,
        emulation: _getEmulation(config.model),
      );

      return status.offline == false;
    } catch (e) {
      debugPrint('接続テストエラー: $e');
      return false;
    }
  }

  /// 会計レシートを印刷
  Future<bool> printPaymentReceipt({
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
    try {
      final portName = _getPortName(config);
      if (portName == null) return false;

      // ロゴ画像をダウンロード（設定されている場合）
      Uint8List? logoImageData;
      final logoUrl = receiptSettings?['logoUrl'] as String?;
      if (logoUrl != null && logoUrl.isNotEmpty) {
        logoImageData = await _downloadLogoImage(logoUrl);
      }

      final commands = _buildPaymentReceiptCommands(
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
        logoImageData: logoImageData,
      );

      final result = await StarPrnt.sendCommands(
        portName: portName,
        emulation: _getEmulation(config.model),
        printCommands: commands,
      );

      return result.isSuccess;
    } catch (e) {
      debugPrint('レシート印刷エラー: $e');
      return false;
    }
  }

  /// 伝票を印刷（1商品1枚）
  Future<bool> printKitchenTicket({
    required PrinterConfig config,
    required OrderModel order,
    required OrderItem item,
    required int currentNumber,
    required int totalQuantity,
  }) async {
    try {
      final portName = _getPortName(config);
      if (portName == null) return false;

      final commands = _buildTicketCommands(
        order: order,
        item: item,
        currentNumber: currentNumber,
        totalQuantity: totalQuantity,
      );

      final result = await StarPrnt.sendCommands(
        portName: portName,
        emulation: _getEmulation(config.model),
        printCommands: commands,
      );

      return result.isSuccess;
    } catch (e) {
      debugPrint('伝票印刷エラー: $e');
      return false;
    }
  }

  /// キャッシュドロワーを開放
  Future<bool> openCashDrawer(PrinterConfig config) async {
    try {
      if (!config.hasDrawer) {
        debugPrint('このプリンターはドロワーを持っていません');
        return false;
      }

      final portName = _getPortName(config);
      if (portName == null) return false;

      final commands = PrintCommands();
      commands.openCashDrawer(1); // Channel 1

      final result = await StarPrnt.sendCommands(
        portName: portName,
        emulation: _getEmulation(config.model),
        printCommands: commands,
      );

      return result.isSuccess;
    } catch (e) {
      debugPrint('ドロワー開放エラー: $e');
      return false;
    }
  }

  /// テーブルQRコードを印刷
  Future<bool> printTableQR({
    required PrinterConfig config,
    required TableModel table,
    String? shopCode,
  }) async {
    try {
      final portName = _getPortName(config);
      if (portName == null) return false;

      // QRコード用URL
      final qrUrl = shopCode != null
          ? 'https://reservation-customer-booking.web.app/order/$shopCode/${table.id}'
          : 'https://reservation-customer-booking.web.app/order/${table.shopId}/${table.id}';

      // QRコード画像を生成
      final qrImageData = await _generateQrImage(qrUrl);
      debugPrint('QR画像生成完了: ${qrImageData?.length ?? 0} bytes');

      if (qrImageData == null) {
        debugPrint('QR画像生成失敗');
        return false;
      }

      final commands = PrintCommands();

      // テーブル番号とQRコードを1つの画像として結合
      final combinedImage = await _createQrPrintImage(table.tableNumber, qrImageData);

      if (combinedImage != null) {
        commands.appendBitmapByte(
          byteData: combinedImage,
          width: 384,
          bothScale: true,
          alignment: StarAlignmentPosition.Center,
        );
      } else {
        // フォールバック: QRコードのみ印刷
        commands.appendBitmapByte(
          byteData: qrImageData,
          width: 384,
          bothScale: true,
          alignment: StarAlignmentPosition.Center,
        );
      }

      commands.appendCutPaper(StarCutPaperAction.PartialCutWithFeed);

      final result = await StarPrnt.sendCommands(
        portName: portName,
        emulation: _getEmulation(config.model),
        printCommands: commands,
      );

      return result.isSuccess;
    } catch (e) {
      debugPrint('QR印刷エラー: $e');
      return false;
    }
  }

  /// テーブル番号とQRコードを結合した印刷用画像を生成
  Future<Uint8List?> _createQrPrintImage(String tableNumber, Uint8List qrImageData) async {
    try {
      // QR画像をデコード
      final codec = await ui.instantiateImageCodec(qrImageData);
      final frame = await codec.getNextFrame();
      final qrImage = frame.image;

      // 印刷用キャンバスサイズ（幅384px、高さはQR + テキスト分）
      const canvasWidth = 384.0;
      final qrSize = qrImage.width.toDouble();
      final textHeight = 60.0; // テーブル番号用
      final padding = 20.0;
      final totalHeight = textHeight + qrSize + padding * 2;

      // PictureRecorderで描画
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 白背景
      final bgPaint = Paint()..color = const ui.Color(0xFFFFFFFF);
      canvas.drawRect(Rect.fromLTWH(0, 0, canvasWidth, totalHeight), bgPaint);

      // テーブル番号テキスト
      final textPainter = TextPainter(
        text: TextSpan(
          text: tableNumber,
          style: const TextStyle(
            color: ui.Color(0xFF000000),
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout(maxWidth: canvasWidth);
      final textX = (canvasWidth - textPainter.width) / 2;
      textPainter.paint(canvas, Offset(textX, padding));

      // QRコード画像
      final qrX = (canvasWidth - qrSize) / 2;
      final qrY = textHeight + padding;
      canvas.drawImage(qrImage, Offset(qrX, qrY), Paint());

      // 画像に変換
      final picture = recorder.endRecording();
      final img = await picture.toImage(canvasWidth.toInt(), totalHeight.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('結合画像生成エラー: $e');
      return null;
    }
  }

  /// QRコード画像をPNG形式で生成
  Future<Uint8List?> _generateQrImage(String data) async {
    try {
      // QrPainterのtoImageDataを使用してPNG画像を生成
      final qrValidationResult = QrValidator.validate(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );

      if (qrValidationResult.status != QrValidationStatus.valid) {
        debugPrint('QRコード検証エラー: ${qrValidationResult.status}');
        return null;
      }

      final qrCode = qrValidationResult.qrCode!;
      final painter = QrPainter.withQr(
        qr: qrCode,
        color: const ui.Color(0xFF000000),
        emptyColor: const ui.Color(0xFFFFFFFF),
        gapless: true,
      );

      // 200x200のQRコード画像を生成
      final imageData = await painter.toImageData(200);
      if (imageData == null) {
        debugPrint('QRコード画像データ生成失敗');
        return null;
      }

      return imageData.buffer.asUint8List();
    } catch (e) {
      debugPrint('QRコード画像生成エラー: $e');
      return null;
    }
  }

  /// テスト印刷
  Future<bool> printTest(PrinterConfig config) async {
    try {
      final portName = _getPortName(config);
      if (portName == null) return false;

      final commands = PrintCommands();

      // テスト印刷用のテキストを構築
      final testText = StringBuffer();
      testText.writeln('=== Connection Test ===');
      testText.writeln('');
      testText.writeln('Model: ${config.model.name}');
      testText.writeln('Connection: ${config.connectionType.name}');
      if (config.connectionType == PrinterConnectionType.bluetooth) {
        testText.writeln('Address: ${config.bluetoothAddress ?? "N/A"}');
      } else {
        testText.writeln('IP: ${config.ipAddress}:${config.port}');
      }
      testText.writeln('Has Drawer: ${config.hasDrawer}');
      testText.writeln('');
      testText.writeln('Print test successful!');
      testText.writeln('');

      commands.appendBitmapText(text: testText.toString(), fontSize: 13, width: 384);
      commands.appendCutPaper(StarCutPaperAction.PartialCutWithFeed);

      final result = await StarPrnt.sendCommands(
        portName: portName,
        emulation: _getEmulation(config.model),
        printCommands: commands,
      );

      return result.isSuccess;
    } catch (e) {
      debugPrint('テスト印刷エラー: $e');
      return false;
    }
  }

  /// 会計レシートコマンドを構築
  PrintCommands _buildPaymentReceiptCommands({
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
    Uint8List? logoImageData,
  }) {
    final commands = PrintCommands();

    // ロゴ画像を印刷（設定されている場合）
    if (logoImageData != null) {
      commands.appendBitmapByte(
        byteData: logoImageData,
        diffusion: true,
        width: 384,
        bothScale: true,
        alignment: StarAlignmentPosition.Center,
      );
    }

    // レシート設定を取得
    final headerMessage = receiptSettings?['headerMessage'] as String? ?? '';
    final footerMessage = receiptSettings?['footerMessage'] as String? ?? 'ありがとうございました';
    final showShopAddress = receiptSettings?['showShopAddress'] as bool? ?? true;
    final showShopPhone = receiptSettings?['showShopPhone'] as bool? ?? true;
    final showTaxDetails = receiptSettings?['showTaxDetails'] as bool? ?? true;
    final registrationNumber = receiptSettings?['showRegistrationNumber'] as String? ?? '';

    // レシート全体のテキストを構築
    // 58mm幅: 半角約32文字、全角約16文字
    final receipt = StringBuffer();

    // ヘッダー（16文字）
    receipt.writeln('----------------');
    receipt.writeln(_centerText(shopName ?? '店舗名', 16));
    receipt.writeln('----------------');

    // 店舗情報
    if (showShopAddress && shopAddress != null && shopAddress.isNotEmpty) {
      receipt.writeln(shopAddress);
    }
    if (showShopPhone && shopPhone != null && shopPhone.isNotEmpty) {
      receipt.writeln('TEL:$shopPhone');
    }
    if (registrationNumber.isNotEmpty) {
      receipt.writeln('登録番号:$registrationNumber');
    }

    receipt.writeln('');
    receipt.writeln(_centerText('【領収書】', 16));
    receipt.writeln('');

    // ヘッダーメッセージ
    if (headerMessage.isNotEmpty) {
      receipt.writeln(headerMessage);
      receipt.writeln('');
    }

    // 日時・テーブル
    receipt.writeln('${_formatDateTime(DateTime.now())}');
    receipt.writeln('テーブル: ${order.tableNumber}');
    receipt.writeln('----------------');

    // 商品明細
    for (final item in order.items) {
      receipt.writeln(item.productName);
      receipt.writeln(' x${item.quantity}  ¥${item.subtotal.toInt()}');

      // オプション
      for (final option in item.selectedOptions) {
        receipt.writeln(' ${option.optionName}:${option.value}');
      }

      // 備考
      if (item.notes != null && item.notes!.isNotEmpty) {
        receipt.writeln(' 備考:${item.notes}');
      }
    }

    receipt.writeln('----------------');

    // 小計
    receipt.writeln('小計    ¥${order.subtotal.toInt()}');

    // 調整項目
    for (final adj in adjustments) {
      String label = adj.name;
      String valueStr;
      switch (adj.type) {
        case AdjustmentType.discountAmount:
          valueStr = '-¥${adj.value.toInt()}';
          break;
        case AdjustmentType.discountPercent:
          final discountAmount = order.subtotal * (adj.value / 100);
          valueStr = '-¥${discountAmount.toInt()}(${adj.value.toInt()}%)';
          break;
        case AdjustmentType.surchargeTaxExcluded:
        case AdjustmentType.surchargeTaxIncluded:
          valueStr = '+¥${adj.value.toInt()}';
          break;
        case AdjustmentType.paymentVoucher:
          label = '${adj.name}(充当)';
          valueStr = '-¥${adj.value.toInt()}';
          break;
      }
      receipt.writeln('$label $valueStr');
    }

    // 消費税
    if (showTaxDetails) {
      final taxAmount = (grandTotal / 1.1 * 0.1).toInt();
      receipt.writeln('(税) ¥$taxAmount');
    }

    receipt.writeln('----------------');

    // 合計
    receipt.writeln('');
    receipt.writeln('【合計】¥${grandTotal.toInt()}');
    receipt.writeln('');
    receipt.writeln('----------------');

    // 支払い方法
    final paymentLabel = paymentMethod == 'cash' ? '現金' : 'カード他';
    receipt.writeln('支払: $paymentLabel');

    // 現金の場合
    if (paymentMethod == 'cash' && receivedAmount != null) {
      receipt.writeln('お預り ¥${receivedAmount.toInt()}');
      receipt.writeln('');
      receipt.writeln('【お釣】¥${(changeAmount ?? 0).toInt()}');
    }

    receipt.writeln('----------------');
    receipt.writeln('');

    // フッター
    receipt.writeln(_centerText(footerMessage, 16));
    receipt.writeln('');
    receipt.writeln('');

    // mPOPは58mm幅（印刷幅約384ドット）
    // fontSize: 12〜14が58mmレシートに適切
    commands.appendBitmapText(
      text: receipt.toString(),
      fontSize: 13,
      width: 384,
    );
    commands.appendCutPaper(StarCutPaperAction.PartialCutWithFeed);

    return commands;
  }

  /// 伝票コマンドを構築
  PrintCommands _buildTicketCommands({
    required OrderModel order,
    required OrderItem item,
    required int currentNumber,
    required int totalQuantity,
  }) {
    final commands = PrintCommands();

    // 伝票のテキストを構築
    final ticket = StringBuffer();

    ticket.writeln('================================');
    ticket.writeln('        【 伝  票 】');
    ticket.writeln('================================');
    ticket.writeln('');

    // テーブル番号（大きく）
    ticket.writeln('  テーブル: ${order.tableNumber}');
    ticket.writeln('');

    // 時刻
    ticket.writeln('  ${_formatTime(order.orderedAt)}');
    ticket.writeln('');
    ticket.writeln('--------------------------------');
    ticket.writeln('');

    // 商品名
    ticket.writeln('  ${item.productName}');
    ticket.writeln('');

    // 数量（複数の場合）
    if (totalQuantity > 1) {
      ticket.writeln('    [ $currentNumber / $totalQuantity ]');
      ticket.writeln('');
    }

    // オプション
    if (item.selectedOptions.isNotEmpty) {
      ticket.writeln('--------------------------------');
      for (final option in item.selectedOptions) {
        ticket.writeln('  ${option.optionName}: ${option.value}');
      }
      ticket.writeln('');
    }

    // 備考
    if (item.notes != null && item.notes!.isNotEmpty) {
      ticket.writeln('--------------------------------');
      ticket.writeln('  ※ ${item.notes}');
      ticket.writeln('');
    }

    ticket.writeln('');

    // mPOPは58mm幅（印刷幅約384ドット）
    // 伝票は視認性重視でレシートより少し大きめ（fontSize: 16）
    commands.appendBitmapText(
      text: ticket.toString(),
      fontSize: 16,
      width: 384,
    );
    commands.appendCutPaper(StarCutPaperAction.PartialCutWithFeed);

    return commands;
  }

  /// 接続先ポート名を取得
  String? _getPortName(PrinterConfig config) {
    debugPrint('StarPrinter: Getting portName for config: starPortName=${config.starPortName}, bluetoothAddress=${config.bluetoothAddress}, ipAddress=${config.ipAddress}');

    // Star SDK用のポート名が保存されている場合は優先的に使用
    if (config.starPortName != null && config.starPortName!.isNotEmpty) {
      debugPrint('StarPrinter: Using saved portName: ${config.starPortName}');
      return config.starPortName;
    }

    // フォールバック: 各フィールドからポート名を構築
    switch (config.connectionType) {
      case PrinterConnectionType.bluetooth:
        if (config.bluetoothAddress != null && config.bluetoothAddress!.isNotEmpty) {
          final portName = 'BT:${config.bluetoothAddress}';
          debugPrint('StarPrinter: Constructed BT portName: $portName');
          return portName;
        }
        debugPrint('StarPrinter: No bluetooth address available');
        return null;
      case PrinterConnectionType.network:
        if (config.ipAddress != null && config.ipAddress!.isNotEmpty) {
          final portName = 'TCP:${config.ipAddress}';
          debugPrint('StarPrinter: Constructed TCP portName: $portName');
          return portName;
        }
        debugPrint('StarPrinter: No IP address available');
        return null;
    }
  }

  /// プリンターモデルに応じたエミュレーションを取得
  String _getEmulation(PrinterModel model) {
    switch (model) {
      case PrinterModel.starMpop:
      case PrinterModel.starTsp100:
        return 'StarPRNT';
      case PrinterModel.epsonTm:
        return 'EscPosMobile';
      case PrinterModel.generic:
      default:
        return 'StarPRNT';
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

  /// テキストを指定幅で中央揃え（全角文字考慮）
  String _centerText(String text, int width) {
    // 全角文字は2、半角文字は1としてカウント
    int textWidth = 0;
    for (final char in text.runes) {
      // 全角文字の範囲（日本語、全角記号など）
      if (char > 0xFF) {
        textWidth += 2;
      } else {
        textWidth += 1;
      }
    }

    // テキストが幅を超える場合はそのまま返す
    if (textWidth >= width) return text;

    // パディングを計算（半角スペース数）
    final padding = (width - textWidth) ~/ 2;
    return ' ' * padding + text;
  }

  /// URLからロゴ画像をダウンロード
  Future<Uint8List?> _downloadLogoImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      debugPrint('ロゴ画像ダウンロード失敗: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('ロゴ画像ダウンロードエラー: $e');
      return null;
    }
  }
}
