import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// CSV一括インポートサービス
class CsvImportService {
  static final CsvImportService _instance = CsvImportService._internal();
  factory CsvImportService() => _instance;
  CsvImportService._internal();

  /// CSVファイルを選択して商品をインポート
  Future<CsvImportResult> importProducts(String shopId) async {
    try {
      // ファイル選択
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return CsvImportResult(
          success: false,
          message: 'ファイルが選択されませんでした',
          importedCount: 0,
          errorCount: 0,
          errors: [],
        );
      }

      final file = result.files.first;
      if (file.bytes == null) {
        return CsvImportResult(
          success: false,
          message: 'ファイルを読み込めませんでした',
          importedCount: 0,
          errorCount: 0,
          errors: [],
        );
      }

      // CSVをパース
      final content = utf8.decode(file.bytes!);
      final lines = const LineSplitter().convert(content);

      if (lines.isEmpty) {
        return CsvImportResult(
          success: false,
          message: 'CSVファイルが空です',
          importedCount: 0,
          errorCount: 0,
          errors: [],
        );
      }

      // ヘッダー行を解析
      final headers = _parseCsvLine(lines[0]);
      final headerMap = <String, int>{};
      for (var i = 0; i < headers.length; i++) {
        headerMap[headers[i].toLowerCase().trim()] = i;
      }

      // 必須カラムのチェック
      final requiredColumns = ['name', '商品名'];
      final hasNameColumn = requiredColumns.any(
        (col) => headerMap.containsKey(col.toLowerCase()),
      );

      if (!hasNameColumn) {
        return CsvImportResult(
          success: false,
          message: '必須カラム（name または 商品名）が見つかりません',
          importedCount: 0,
          errorCount: 0,
          errors: [],
        );
      }

      // データ行を処理
      int importedCount = 0;
      int errorCount = 0;
      final errors = <String>[];
      final batch = FirebaseFirestore.instance.batch();

      for (var i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;

        try {
          final values = _parseCsvLine(lines[i]);
          final product = _parseProductFromCsv(headerMap, values, shopId);

          if (product['name'] == null || (product['name'] as String).isEmpty) {
            errors.add('行${i + 1}: 商品名が空です');
            errorCount++;
            continue;
          }

          // Firestoreに追加
          final docRef = FirebaseFirestore.instance.collection('products').doc();
          batch.set(docRef, {
            ...product,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          importedCount++;
        } catch (e) {
          errors.add('行${i + 1}: $e');
          errorCount++;
        }
      }

      // バッチコミット
      if (importedCount > 0) {
        await batch.commit();
      }

      return CsvImportResult(
        success: importedCount > 0,
        message: importedCount > 0
            ? '$importedCount件の商品をインポートしました'
            : 'インポートできる商品がありませんでした',
        importedCount: importedCount,
        errorCount: errorCount,
        errors: errors,
      );
    } catch (e) {
      debugPrint('CSVインポートエラー: $e');
      return CsvImportResult(
        success: false,
        message: 'エラー: $e',
        importedCount: 0,
        errorCount: 0,
        errors: [],
      );
    }
  }

  /// CSV行をパース（カンマ区切り、ダブルクォート対応）
  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }

    result.add(current.toString().trim());
    return result;
  }

  /// CSVデータから商品データを生成
  Map<String, dynamic> _parseProductFromCsv(
    Map<String, int> headerMap,
    List<String> values,
    String shopId,
  ) {
    String? getValue(List<String> keys) {
      for (final key in keys) {
        final index = headerMap[key.toLowerCase()];
        if (index != null && index < values.length) {
          final value = values[index].trim();
          if (value.isNotEmpty) return value;
        }
      }
      return null;
    }

    int? getIntValue(List<String> keys) {
      final value = getValue(keys);
      if (value == null) return null;
      return int.tryParse(value.replaceAll(RegExp(r'[,¥$]'), ''));
    }

    double? getDoubleValue(List<String> keys) {
      final value = getValue(keys);
      if (value == null) return null;
      return double.tryParse(value.replaceAll(RegExp(r'[,¥$]'), ''));
    }

    bool? getBoolValue(List<String> keys) {
      final value = getValue(keys)?.toLowerCase();
      if (value == null) return null;
      return value == 'true' || value == '1' || value == 'yes' || value == 'はい';
    }

    return {
      'shopId': shopId,
      'name': getValue(['name', '商品名', 'product_name']),
      'description': getValue(['description', '説明', '商品説明']),
      'price': getIntValue(['price', '価格', '値段']),
      'category': getValue(['category', 'カテゴリ', 'カテゴリー']),
      'imageUrl': getValue(['image_url', 'imageurl', '画像URL', '画像']),
      'isAvailable': getBoolValue(['available', 'is_available', '販売中', '有効']) ?? true,
      'isTakeoutAvailable': getBoolValue(['takeout', 'takeout_available', 'テイクアウト']) ?? false,
      'sortOrder': getIntValue(['sort_order', 'sortorder', '並び順', '表示順']) ?? 0,
      'stock': getIntValue(['stock', '在庫', '在庫数']),
      // 多言語対応
      'translations': {
        'en': {
          'name': getValue(['name_en', '英語名', 'english_name']),
          'description': getValue(['description_en', '英語説明']),
        },
        'th': {
          'name': getValue(['name_th', 'タイ語名', 'thai_name']),
          'description': getValue(['description_th', 'タイ語説明']),
        },
        'zh': {
          'name': getValue(['name_zh', '中国語名', 'chinese_name']),
          'description': getValue(['description_zh', '中国語説明']),
        },
      },
    };
  }

  /// CSVテンプレートを生成
  String generateProductCsvTemplate() {
    const headers = [
      '商品名',
      '説明',
      '価格',
      'カテゴリ',
      '販売中',
      'テイクアウト',
      '並び順',
      '在庫',
      '英語名',
      '英語説明',
      'タイ語名',
      'タイ語説明',
    ];

    const sampleRow1 = [
      'サンプル商品A',
      '美味しい一品です',
      '1000',
      'メイン',
      'はい',
      'はい',
      '1',
      '',
      'Sample Product A',
      'Delicious dish',
      'สินค้าตัวอย่าง A',
      'อาหารอร่อย',
    ];

    const sampleRow2 = [
      'サンプル商品B',
      'おすすめです',
      '1500',
      'ドリンク',
      'はい',
      'いいえ',
      '2',
      '50',
      'Sample Product B',
      'Recommended',
      'สินค้าตัวอย่าง B',
      'แนะนำ',
    ];

    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));
    buffer.writeln(sampleRow1.join(','));
    buffer.writeln(sampleRow2.join(','));

    return buffer.toString();
  }
}

/// CSVインポート結果
class CsvImportResult {
  final bool success;
  final String message;
  final int importedCount;
  final int errorCount;
  final List<String> errors;

  CsvImportResult({
    required this.success,
    required this.message,
    required this.importedCount,
    required this.errorCount,
    required this.errors,
  });
}
