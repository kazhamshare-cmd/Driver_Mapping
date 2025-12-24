import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/locale_provider.dart';

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final t = ref.watch(translationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.text('selectLanguage')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: ListView(
        children: [
          _buildLanguageItem(
            context,
            ref,
            title: '日本語',
            subtitle: 'Japanese',
            targetLocale: AppLocale.ja,
            isSelected: currentLocale.languageCode == 'ja',
          ),
          _buildLanguageItem(
            context,
            ref,
            title: 'English',
            subtitle: 'English',
            targetLocale: AppLocale.en,
            isSelected: currentLocale.languageCode == 'en',
          ),
          _buildLanguageItem(
            context,
            ref,
            title: 'ไทย',
            subtitle: 'Thai',
            targetLocale: AppLocale.th,
            isSelected: currentLocale.languageCode == 'th',
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageItem(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String subtitle,
    required AppLocale targetLocale,
    required bool isSelected,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.orange) : null,
      onTap: () {
        ref.read(localeProvider.notifier).setLocale(targetLocale);
      },
    );
  }
}