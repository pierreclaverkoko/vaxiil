import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/core/locale/locale_manager.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final manager = LocaleManager();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageTitle)),
      body: ListenableBuilder(
        listenable: manager,
        builder: (context, _) {
          final current = manager.languageCode;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.languageSubtitle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              RadioListTile<String>(
                title: Text(l10n.languageEnglish),
                value: 'en',
                groupValue: current,
                onChanged: (value) => _select(context, value),
              ),
              RadioListTile<String>(
                title: Text(l10n.languageFrench),
                value: 'fr',
                groupValue: current,
                onChanged: (value) => _select(context, value),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _select(BuildContext context, String? code) async {
    if (code == null) return;
    await LocaleManager().setLanguageCode(code);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).languageSaved)),
    );
  }
}
