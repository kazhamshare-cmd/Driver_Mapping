import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// AI翻訳サービス（Cloud Functions経由）
class TranslationService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-northeast1');

  /// 単一アイテムを翻訳
  /// [text] 翻訳するテキスト
  /// [sourceLanguage] 元の言語コード (ja, en, th, zh-TW, ko)
  /// [targetLanguages] 翻訳先の言語コードリスト
  /// [shopName] 店舗名（コンテキスト用）
  /// [businessTypeCode] 業種コード（コンテキスト用）
  Future<Map<String, String>> translateSingleText({
    required String text,
    required String sourceLanguage,
    required List<String> targetLanguages,
    String? shopName,
    String? businessTypeCode,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'translateMenuItems',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 2)),
      );

      final result = await callable.call({
        'shopName': shopName ?? '',
        'businessTypeCode': businessTypeCode ?? 'restaurant',
        'sourceLanguage': sourceLanguage,
        'targetLanguages': targetLanguages,
        'items': [
          {
            'id': 'single',
            'name': text,
            'description': '',
          }
        ],
        'batchSize': 1,
        'forceRetranslate': true,
      });

      final data = result.data as Map<String, dynamic>;
      final translations = data['translations'] as List<dynamic>?;

      if (translations != null && translations.isNotEmpty) {
        final item = translations[0] as Map<String, dynamic>;
        final Map<String, String> results = {};

        for (final lang in targetLanguages) {
          final key = 'name_$lang'.replaceAll('-', '_').toLowerCase();
          if (item[key] != null) {
            results[lang] = item[key] as String;
          }
        }
        return results;
      }

      return {};
    } catch (e) {
      debugPrint('翻訳エラー: $e');
      rethrow;
    }
  }

  /// 名前と説明を一括翻訳
  Future<Map<String, Map<String, String>>> translateNameAndDescription({
    required String name,
    required String description,
    required String sourceLanguage,
    required List<String> targetLanguages,
    String? shopName,
    String? businessTypeCode,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'translateMenuItems',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 2)),
      );

      final result = await callable.call({
        'shopName': shopName ?? '',
        'businessTypeCode': businessTypeCode ?? 'restaurant',
        'sourceLanguage': sourceLanguage,
        'targetLanguages': targetLanguages,
        'items': [
          {
            'id': 'single',
            'name': name,
            'description': description,
          }
        ],
        'batchSize': 1,
        'forceRetranslate': true,
      });

      final data = result.data as Map<String, dynamic>;
      final translations = data['translations'] as List<dynamic>?;

      if (translations != null && translations.isNotEmpty) {
        final item = translations[0] as Map<String, dynamic>;
        final Map<String, String> nameResults = {};
        final Map<String, String> descResults = {};

        for (final lang in targetLanguages) {
          final langKey = lang.replaceAll('-', '_').toLowerCase();
          final nameKey = 'name_$langKey';
          final descKey = 'description_$langKey';

          if (item[nameKey] != null) {
            nameResults[lang] = item[nameKey] as String;
          }
          if (item[descKey] != null) {
            descResults[lang] = item[descKey] as String;
          }
        }

        return {
          'name': nameResults,
          'description': descResults,
        };
      }

      return {'name': {}, 'description': {}};
    } catch (e) {
      debugPrint('翻訳エラー: $e');
      rethrow;
    }
  }

  /// 複数アイテムを一括翻訳（商品一覧など）
  Future<List<Map<String, dynamic>>> translateBatch({
    required List<Map<String, dynamic>> items,
    required String sourceLanguage,
    required List<String> targetLanguages,
    String? shopName,
    String? businessTypeCode,
    int batchSize = 20,
  }) async {
    try {
      // 50件以上はバックグラウンド処理
      if (items.length >= 50) {
        final callable = _functions.httpsCallable(
          'startBatchTranslation',
          options: HttpsCallableOptions(timeout: const Duration(minutes: 1)),
        );

        final result = await callable.call({
          'shopName': shopName ?? '',
          'businessTypeCode': businessTypeCode ?? 'restaurant',
          'sourceLanguage': sourceLanguage,
          'targetLanguages': targetLanguages,
          'items': items,
          'batchSize': batchSize,
        });

        final data = result.data as Map<String, dynamic>;
        // バックグラウンド処理のジョブIDを返す
        return [{'jobId': data['jobId'], 'isBackground': true}];
      }

      // 50件未満は同期処理
      final callable = _functions.httpsCallable(
        'translateMenuItems',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 10)),
      );

      final result = await callable.call({
        'shopName': shopName ?? '',
        'businessTypeCode': businessTypeCode ?? 'restaurant',
        'sourceLanguage': sourceLanguage,
        'targetLanguages': targetLanguages,
        'items': items,
        'batchSize': batchSize,
        'forceRetranslate': true,
      });

      final data = result.data as Map<String, dynamic>;
      final translations = data['translations'] as List<dynamic>?;

      return translations?.map((t) => t as Map<String, dynamic>).toList() ?? [];
    } catch (e) {
      debugPrint('一括翻訳エラー: $e');
      rethrow;
    }
  }
}
