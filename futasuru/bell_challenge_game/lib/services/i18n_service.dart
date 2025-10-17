import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class I18nService {
  static final I18nService _instance = I18nService._internal();
  factory I18nService() => _instance;
  I18nService._internal();

  static Map<String, Map<String, dynamic>> _translations = {};
  static String _currentLanguage = 'ja';

  static const List<Locale> supportedLocales = [
    Locale('ja', 'JP'),
    Locale('en', 'US'),
    Locale('pt', 'BR'),
    Locale('zh', 'CN'),
    Locale('th', 'TH'),
  ];

  static const Map<String, Map<String, String>> languageOptions = {
    'ja': {'name': 'Japanese', 'nativeName': '日本語', 'flag': '🇯🇵'},
    'en': {'name': 'English', 'nativeName': 'English', 'flag': '🇺🇸'},
    'pt': {'name': 'Portuguese', 'nativeName': 'Português', 'flag': '🇧🇷'},
    'zh': {'name': 'Chinese', 'nativeName': '中文', 'flag': '🇨🇳'},
    'th': {'name': 'Thai', 'nativeName': 'ไทย', 'flag': '🇹🇭'},
  };

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('selected_language') ?? 'ja';

    await _loadTranslations();
  }

  static Future<void> _loadTranslations() async {
    for (final locale in supportedLocales) {
      try {
        print('📖 Loading translation file: lib/i18n/${locale.languageCode}.json');
        final String jsonString = await rootBundle.loadString('lib/i18n/${locale.languageCode}.json');
        _translations[locale.languageCode] = json.decode(jsonString);
        print('✅ Loaded translation for ${locale.languageCode}');
      } catch (e) {
        print('❌ 翻訳ファイル読み込みエラー ${locale.languageCode}: $e');
        _translations[locale.languageCode] = {};
      }
    }
  }

  static String translate(String key, {Map<String, dynamic>? params}) {
    try {
      final keys = key.split('.');
      dynamic value = _translations[_currentLanguage];

      for (final k in keys) {
        if (value is Map<String, dynamic> && value.containsKey(k)) {
          value = value[k];
        } else {
          print('Translation key not found: $key');
          return key;
        }
      }

      String result = value?.toString() ?? key;

      if (params != null) {
        params.forEach((paramKey, paramValue) {
          result = result.replaceAll('{$paramKey}', paramValue.toString());
        });
      }

      return result;
    } catch (e) {
      print('Translation error for key "$key": $e');
      return key;
    }
  }

  static String get currentLanguage => _currentLanguage;

  static Future<void> setLanguage(String languageCode) async {
    if (supportedLocales.any((locale) => locale.languageCode == languageCode)) {
      _currentLanguage = languageCode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_language', languageCode);
    }
  }

  static Future<Locale> getCurrentLocale() async {
    return supportedLocales.firstWhere(
      (locale) => locale.languageCode == _currentLanguage,
      orElse: () => supportedLocales.first,
    );
  }

  static String getLanguageName(String languageCode) {
    return languageOptions[languageCode]?['nativeName'] ?? languageCode;
  }

  static String getLanguageFlag(String languageCode) {
    return languageOptions[languageCode]?['flag'] ?? '🌐';
  }
}

String t(String key, {Map<String, dynamic>? params}) {
  return I18nService.translate(key, params: params);
}