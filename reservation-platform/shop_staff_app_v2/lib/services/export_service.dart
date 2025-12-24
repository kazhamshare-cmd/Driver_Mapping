import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// データエクスポートサービス
class ExportService {
  final _firestore = FirebaseFirestore.instance;

  /// 売上データをCSVエクスポート
  Future<void> exportSalesCSV({
    required String shopId,
    required DateTime startDate,
    required DateTime endDate,
    required BuildContext context,
  }) async {
    try {
      // 注文データ取得
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('shopId', isEqualTo: shopId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThan: Timestamp.fromDate(endDate))
          .where('status', whereIn: ['completed', 'paid', 'delivered'])
          .orderBy('createdAt', descending: false)
          .get();

      if (ordersSnapshot.docs.isEmpty) {
        _showMessage(context, '対象期間のデータがありません', isError: true);
        return;
      }

      // CSV作成
      final buffer = StringBuffer();
      buffer.writeln('日時,注文番号,テーブル,商品数,合計金額,支払方法,ステータス');

      for (final doc in ordersSnapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final orderNumber = data['orderNumber'] ?? doc.id.substring(0, 8);
        final tableNumber = data['tableNumber'] ?? '-';
        final items = data['items'] as List? ?? [];
        final total = (data['total'] as num?)?.toDouble() ?? 0;
        final paymentMethod = data['paymentMethod'] ?? '-';
        final status = data['status'] ?? '-';

        buffer.writeln(
          '${createdAt != null ? DateFormat('yyyy/MM/dd HH:mm').format(createdAt) : '-'},'
          '$orderNumber,'
          '$tableNumber,'
          '${items.length},'
          '${total.toInt()},'
          '$paymentMethod,'
          '$status'
        );
      }

      // ファイル保存と共有
      await _shareFile(
        content: buffer.toString(),
        fileName: 'sales_${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}.csv',
        context: context,
      );
    } catch (e) {
      _showMessage(context, 'エクスポートエラー: $e', isError: true);
    }
  }

  /// 顧客データをCSVエクスポート
  Future<void> exportCustomersCSV({
    required String shopId,
    required BuildContext context,
  }) async {
    try {
      final customersSnapshot = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('customers')
          .orderBy('totalSpent', descending: true)
          .get();

      if (customersSnapshot.docs.isEmpty) {
        _showMessage(context, '顧客データがありません', isError: true);
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln('名前,電話番号,メール,来店回数,累計金額,最終来店日,登録日');

      for (final doc in customersSnapshot.docs) {
        final data = doc.data();
        final name = _escapeCsv(data['name'] ?? '');
        final phone = data['phone'] ?? '';
        final email = data['email'] ?? '';
        final visitCount = (data['visitCount'] as num?)?.toInt() ?? 0;
        final totalSpent = (data['totalSpent'] as num?)?.toDouble() ?? 0;
        final lastVisitAt = (data['lastVisitAt'] as Timestamp?)?.toDate();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        buffer.writeln(
          '$name,'
          '$phone,'
          '$email,'
          '$visitCount,'
          '${totalSpent.toInt()},'
          '${lastVisitAt != null ? DateFormat('yyyy/MM/dd').format(lastVisitAt) : '-'},'
          '${createdAt != null ? DateFormat('yyyy/MM/dd').format(createdAt) : '-'}'
        );
      }

      await _shareFile(
        content: buffer.toString(),
        fileName: 'customers_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
        context: context,
      );
    } catch (e) {
      _showMessage(context, 'エクスポートエラー: $e', isError: true);
    }
  }

  /// 売上データをPDFエクスポート
  Future<void> exportSalesPDF({
    required String shopId,
    required String shopName,
    required DateTime startDate,
    required DateTime endDate,
    required BuildContext context,
  }) async {
    try {
      // 注文データ取得
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('shopId', isEqualTo: shopId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThan: Timestamp.fromDate(endDate))
          .where('status', whereIn: ['completed', 'paid', 'delivered'])
          .orderBy('createdAt', descending: false)
          .get();

      if (ordersSnapshot.docs.isEmpty) {
        _showMessage(context, '対象期間のデータがありません', isError: true);
        return;
      }

      // 集計
      double totalSales = 0;
      int orderCount = 0;
      Map<String, double> dailySales = {};
      Map<String, int> paymentMethodCounts = {};

      for (final doc in ordersSnapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final total = (data['total'] as num?)?.toDouble() ?? 0;
        final paymentMethod = data['paymentMethod'] as String? ?? 'other';

        totalSales += total;
        orderCount++;

        if (createdAt != null) {
          final dateKey = DateFormat('yyyy/MM/dd').format(createdAt);
          dailySales[dateKey] = (dailySales[dateKey] ?? 0) + total;
        }

        paymentMethodCounts[paymentMethod] = (paymentMethodCounts[paymentMethod] ?? 0) + 1;
      }

      // PDF作成
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context pdfContext) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ヘッダー
                pw.Center(
                  child: pw.Text(
                    '売上レポート',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    shopName,
                    style: const pw.TextStyle(fontSize: 16),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    '${DateFormat('yyyy/MM/dd').format(startDate)} - ${DateFormat('yyyy/MM/dd').format(endDate)}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
                pw.SizedBox(height: 24),
                pw.Divider(),
                pw.SizedBox(height: 16),

                // サマリー
                pw.Text(
                  'サマリー',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                _buildPdfSummaryRow('総売上', 'Y${NumberFormat('#,###').format(totalSales.toInt())}'),
                _buildPdfSummaryRow('注文件数', '$orderCount件'),
                _buildPdfSummaryRow('平均客単価', 'Y${NumberFormat('#,###').format((totalSales / orderCount).toInt())}'),
                pw.SizedBox(height: 24),

                // 日別売上
                pw.Text(
                  '日別売上',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('日付', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('売上', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...dailySales.entries.map((entry) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(entry.key),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Y${NumberFormat('#,###').format(entry.value.toInt())}'),
                        ),
                      ],
                    )),
                  ],
                ),
              ],
            );
          },
        ),
      );

      // PDFをファイルとして保存
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/sales_report_${DateFormat('yyyyMMdd').format(startDate)}.pdf');
      await file.writeAsBytes(await pdf.save());

      // 共有
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '売上レポート ${DateFormat('yyyy/MM/dd').format(startDate)} - ${DateFormat('yyyy/MM/dd').format(endDate)}',
      );

      _showMessage(context, 'PDFを作成しました');
    } catch (e) {
      _showMessage(context, 'エクスポートエラー: $e', isError: true);
    }
  }

  pw.Widget _buildPdfSummaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text(
            value,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// 勤怠データをCSVエクスポート
  Future<void> exportAttendanceCSV({
    required String shopId,
    required DateTime startDate,
    required DateTime endDate,
    required BuildContext context,
  }) async {
    try {
      final attendanceSnapshot = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('attendances')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThan: Timestamp.fromDate(endDate))
          .orderBy('date', descending: false)
          .get();

      if (attendanceSnapshot.docs.isEmpty) {
        _showMessage(context, '対象期間のデータがありません', isError: true);
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln('日付,スタッフ名,出勤時間,退勤時間,休憩時間,実働時間,ステータス');

      for (final doc in attendanceSnapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp?)?.toDate();
        final staffName = data['staffName'] ?? '';
        final clockIn = (data['clockIn'] as Timestamp?)?.toDate();
        final clockOut = (data['clockOut'] as Timestamp?)?.toDate();
        final breakMinutes = (data['breakMinutes'] as num?)?.toInt() ?? 0;
        final status = data['status'] ?? '';

        int workMinutes = 0;
        if (clockIn != null && clockOut != null) {
          workMinutes = clockOut.difference(clockIn).inMinutes - breakMinutes;
        }

        buffer.writeln(
          '${date != null ? DateFormat('yyyy/MM/dd').format(date) : '-'},'
          '$staffName,'
          '${clockIn != null ? DateFormat('HH:mm').format(clockIn) : '-'},'
          '${clockOut != null ? DateFormat('HH:mm').format(clockOut) : '-'},'
          '${breakMinutes}分,'
          '${workMinutes > 0 ? '${workMinutes ~/ 60}時間${workMinutes % 60}分' : '-'},'
          '$status'
        );
      }

      await _shareFile(
        content: buffer.toString(),
        fileName: 'attendance_${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}.csv',
        context: context,
      );
    } catch (e) {
      _showMessage(context, 'エクスポートエラー: $e', isError: true);
    }
  }

  /// ファイルを共有
  Future<void> _shareFile({
    required String content,
    required String fileName,
    required BuildContext context,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(content);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: fileName,
    );

    _showMessage(context, 'ファイルを作成しました');
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  void _showMessage(BuildContext context, String message, {bool isError = false}) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }
}
