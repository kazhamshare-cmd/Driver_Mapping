import 'package:flutter/material.dart';

/// 言語コードに応じて多言語フィールドから適切なテキストを取得するヘルパー
class LocalizedTextHelper {
  /// 言語コードに応じて商品名を取得
  /// product は Firestore から取得した Map<String, dynamic>
  static String getProductName(Map<String, dynamic> product, String languageCode) {
    switch (languageCode) {
      case 'en':
        return product['nameEn'] as String? ?? product['name'] as String? ?? '';
      case 'th':
        return product['nameTh'] as String? ?? product['name'] as String? ?? '';
      case 'zh':
        return product['nameZh'] as String? ?? product['name'] as String? ?? '';
      case 'ko':
        return product['nameKo'] as String? ?? product['name'] as String? ?? '';
      default:
        return product['name'] as String? ?? '';
    }
  }

  /// 言語コードに応じて商品説明を取得
  static String getProductDescription(Map<String, dynamic> product, String languageCode) {
    switch (languageCode) {
      case 'en':
        return product['descriptionEn'] as String? ?? product['description'] as String? ?? '';
      case 'th':
        return product['descriptionTh'] as String? ?? product['description'] as String? ?? '';
      case 'zh':
        return product['descriptionZh'] as String? ?? product['description'] as String? ?? '';
      case 'ko':
        return product['descriptionKo'] as String? ?? product['description'] as String? ?? '';
      default:
        return product['description'] as String? ?? '';
    }
  }

  /// 言語コードに応じてカテゴリ名を取得
  static String getCategoryName(Map<String, dynamic> category, String languageCode) {
    switch (languageCode) {
      case 'en':
        return category['nameEn'] as String? ?? category['name'] as String? ?? '';
      case 'th':
        return category['nameTh'] as String? ?? category['name'] as String? ?? '';
      case 'zh':
        return category['nameZh'] as String? ?? category['name'] as String? ?? '';
      case 'ko':
        return category['nameKo'] as String? ?? category['name'] as String? ?? '';
      default:
        return category['name'] as String? ?? '';
    }
  }

  /// 言語コードに応じてオプション名を取得
  static String getOptionName(Map<String, dynamic> option, String languageCode) {
    switch (languageCode) {
      case 'en':
        return option['nameEn'] as String? ?? option['name'] as String? ?? '';
      case 'th':
        return option['nameTh'] as String? ?? option['name'] as String? ?? '';
      case 'zh':
        return option['nameZh'] as String? ?? option['name'] as String? ?? '';
      case 'ko':
        return option['nameKo'] as String? ?? option['name'] as String? ?? '';
      default:
        return option['name'] as String? ?? '';
    }
  }

  /// 言語コードに応じて選択肢名を取得
  static String getChoiceName(Map<String, dynamic> choice, String languageCode) {
    switch (languageCode) {
      case 'en':
        return choice['nameEn'] as String? ?? choice['name'] as String? ?? '';
      case 'th':
        return choice['nameTh'] as String? ?? choice['name'] as String? ?? '';
      case 'zh':
        return choice['nameZh'] as String? ?? choice['name'] as String? ?? '';
      case 'ko':
        return choice['nameKo'] as String? ?? choice['name'] as String? ?? '';
      default:
        return choice['name'] as String? ?? '';
    }
  }

  /// 言語コードに応じてメニュー名を取得
  static String getMenuName(Map<String, dynamic> menu, String languageCode) {
    switch (languageCode) {
      case 'en':
        return menu['nameEn'] as String? ?? menu['name'] as String? ?? '';
      case 'th':
        return menu['nameTh'] as String? ?? menu['name'] as String? ?? '';
      case 'zh':
        return menu['nameZh'] as String? ?? menu['name'] as String? ?? '';
      case 'ko':
        return menu['nameKo'] as String? ?? menu['name'] as String? ?? '';
      default:
        return menu['name'] as String? ?? '';
    }
  }

  /// 言語コードに応じてメニュー説明を取得
  static String getMenuDescription(Map<String, dynamic> menu, String languageCode) {
    switch (languageCode) {
      case 'en':
        return menu['descriptionEn'] as String? ?? menu['description'] as String? ?? '';
      case 'th':
        return menu['descriptionTh'] as String? ?? menu['description'] as String? ?? '';
      case 'zh':
        return menu['descriptionZh'] as String? ?? menu['description'] as String? ?? '';
      case 'ko':
        return menu['descriptionKo'] as String? ?? menu['description'] as String? ?? '';
      default:
        return menu['description'] as String? ?? '';
    }
  }
}
