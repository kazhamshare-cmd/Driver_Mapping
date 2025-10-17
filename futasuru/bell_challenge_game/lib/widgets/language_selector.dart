import 'package:flutter/material.dart';
import '../services/i18n_service.dart';
import '../services/sound_service.dart';

class LanguageSelector extends StatefulWidget {
  final Function(Locale) onLanguageChanged;
  final VoidCallback? onLanguageChangeRequested;

  const LanguageSelector({
    super.key,
    required this.onLanguageChanged,
    this.onLanguageChangeRequested,
  });

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector> {
  String _currentLanguage = 'ja';
  final SoundService _soundService = SoundService();

  @override
  void initState() {
    super.initState();
    _currentLanguage = I18nService.currentLanguage;
  }

  void _selectLanguage(String languageCode) async {
    if (_currentLanguage != languageCode) {
      _soundService.playButtonClick();

      setState(() {
        _currentLanguage = languageCode;
      });

      await I18nService.setLanguage(languageCode);
      final locale = await I18nService.getCurrentLocale();
      widget.onLanguageChanged(locale);

      // 親ウィジェットに言語変更を通知
      widget.onLanguageChangeRequested?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('settings.language'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: I18nService.languageOptions.entries.map((entry) {
              final languageCode = entry.key;
              final languageInfo = entry.value;
              final isSelected = _currentLanguage == languageCode;

              return GestureDetector(
                onTap: () => _selectLanguage(languageCode),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.green.withOpacity(0.3)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.green : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        languageInfo['flag'] ?? '🌐',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        languageInfo['nativeName'] ?? languageCode,
                        style: TextStyle(
                          color: isSelected ? Colors.green : Colors.white,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}