import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../models/order.dart';
import 'printer_settings_service.dart';

/// Wi-Fi経由でESC/POSプリンターに接続して印刷するサービス
class PrinterService {
  final PrinterSettingsService _settingsService = PrinterSettingsService();

  /// 注文レシートを印刷
  Future<bool> printOrderReceipt(OrderModel order, {String? shopName}) async {
    try {
      // プリンター設定を取得
      final isEnabled = await _settingsService.isPrinterEnabled();
      if (!isEnabled) {
        debugPrint('プリンターは無効化されています');
        return false;
      }

      final ip = await _settingsService.getPrinterIp();
      final port = await _settingsService.getPrinterPort();

      if (ip == null || ip.isEmpty) {
        debugPrint('プリンターのIPアドレスが設定されていません');
        return false;
      }

      // ESC/POSコマンドを生成
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
  Future<bool> printKitchenTicket(OrderModel order) async {
    try {
      // プリンター設定を取得
      final isEnabled = await _settingsService.isPrinterEnabled();
      if (!isEnabled) {
        debugPrint('プリンターは無効化されています');
        return false;
      }

      final ip = await _settingsService.getPrinterIp();
      final port = await _settingsService.getPrinterPort();

      if (ip == null || ip.isEmpty) {
        debugPrint('プリンターのIPアドレスが設定されていません');
        return false;
      }

      // ESC/POSコマンドを生成
      final bytes = await _generateKitchenTicketBytes(order);

      // プリンターに接続して印刷
      await _printToNetwork(ip, port, bytes);

      debugPrint('キッチン伝票印刷成功: 注文ID ${order.id}');
      return true;
    } catch (e) {
      debugPrint('キッチン伝票印刷エラー: $e');
      return false;
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

    // ヘッダー
    bytes.addAll(generator.text(
      shopName ?? '店舗名',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    bytes.addAll(generator.emptyLines(1));

    // レシート情報
    bytes.addAll(generator.text(
      'レシート',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.text(
      '注文番号: ${order.orderNumber ?? order.id}',
      styles: const PosStyles(align: PosAlign.left),
    ));
    bytes.addAll(generator.text(
      'テーブル: ${order.tableNumber}',
      styles: const PosStyles(align: PosAlign.left),
    ));
    bytes.addAll(generator.text(
      '日時: ${_formatDateTime(order.orderedAt)}',
      styles: const PosStyles(align: PosAlign.left),
    ));
    bytes.addAll(generator.hr());

    // 注文アイテム
    for (final item in order.items) {
      bytes.addAll(generator.text(
        item.productName,
        styles: const PosStyles(align: PosAlign.left),
      ));
      bytes.addAll(generator.row([
        PosColumn(
          text: '  x${item.quantity}',
          width: 6,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: '¥${item.subtotal.toStringAsFixed(0)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));

      // オプション
      if (item.selectedOptions.isNotEmpty) {
        for (final option in item.selectedOptions) {
          bytes.addAll(generator.text(
            '  ${option.optionName}: ${option.value}',
            styles: const PosStyles(align: PosAlign.left, fontType: PosFontType.fontB),
          ));
        }
      }

      // メモ
      if (item.notes != null && item.notes!.isNotEmpty) {
        bytes.addAll(generator.text(
          '  メモ: ${item.notes}',
          styles: const PosStyles(align: PosAlign.left, fontType: PosFontType.fontB),
        ));
      }
    }

    bytes.addAll(generator.hr());

    // 合計
    bytes.addAll(generator.row([
      PosColumn(
        text: '合計',
        width: 6,
        styles: const PosStyles(
          align: PosAlign.left,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
      PosColumn(
        text: '¥${order.totalAmount.toStringAsFixed(0)}',
        width: 6,
        styles: const PosStyles(
          align: PosAlign.right,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    ]));

    bytes.addAll(generator.emptyLines(2));
    bytes.addAll(generator.text(
      'ありがとうございました',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.emptyLines(3));
    bytes.addAll(generator.cut());

    return Uint8List.fromList(bytes);
  }

  /// キッチン伝票用のESC/POSバイト列を生成
  Future<Uint8List> _generateKitchenTicketBytes(OrderModel order) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    final List<int> bytes = [];

    // ヘッダー
    bytes.addAll(generator.text(
      '【 調理伝票 】',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    bytes.addAll(generator.emptyLines(1));

    // 伝票情報
    bytes.addAll(generator.text(
      'テーブル: ${order.tableNumber}',
      styles: const PosStyles(
        align: PosAlign.left,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    bytes.addAll(generator.text(
      '注文番号: ${order.orderNumber ?? order.id}',
      styles: const PosStyles(align: PosAlign.left),
    ));
    bytes.addAll(generator.text(
      '時刻: ${_formatTime(order.orderedAt)}',
      styles: const PosStyles(align: PosAlign.left),
    ));
    bytes.addAll(generator.hr());

    // 注文アイテム
    for (final item in order.items) {
      bytes.addAll(generator.text(
        '${item.productName} x${item.quantity}',
        styles: const PosStyles(
          align: PosAlign.left,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ));

      // オプション
      if (item.selectedOptions.isNotEmpty) {
        for (final option in item.selectedOptions) {
          bytes.addAll(generator.text(
            '  ${option.optionName}: ${option.value}',
            styles: const PosStyles(align: PosAlign.left),
          ));
        }
      }

      // メモ
      if (item.notes != null && item.notes!.isNotEmpty) {
        bytes.addAll(generator.text(
          '  【メモ】 ${item.notes}',
          styles: const PosStyles(
            align: PosAlign.left,
            bold: true,
          ),
        ));
      }

      bytes.addAll(generator.emptyLines(1));
    }

    bytes.addAll(generator.emptyLines(3));
    bytes.addAll(generator.cut());

    return Uint8List.fromList(bytes);
  }

  /// ネットワーク経由で印刷
  Future<void> _printToNetwork(String ip, int port, Uint8List bytes) async {
    Socket? socket;
    try {
      // ソケット接続
      socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      debugPrint('プリンターに接続しました: $ip:$port');

      // データ送信
      socket.add(bytes);
      await socket.flush();
      debugPrint('印刷データを送信しました (${bytes.length} bytes)');

      // 少し待機してから切断
      await Future.delayed(const Duration(milliseconds: 500));
    } finally {
      await socket?.close();
      debugPrint('プリンター接続を切断しました');
    }
  }

  /// 日時をフォーマット
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 時刻をフォーマット
  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
