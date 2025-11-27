import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Otomatik Check-In/Out - Her Zaman Aktif (Kullanıcılar değiştiremez)
          // Check-in: 100m yakınlık, 2dk bekleme
          // Check-out: 100m uzaklık, 5dk ayrılma
          
          // Language Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.language,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLanguageOption(
                    context,
                    l10n.turkish,
                    'tr',
                    Icons.flag,
                  ),
                  _buildLanguageOption(
                    context,
                    l10n.english,
                    'en',
                    Icons.flag,
                  ),
                  _buildLanguageOption(
                    context,
                    l10n.german,
                    'de',
                    Icons.flag,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    String title,
    String languageCode,
    IconData icon,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = Localizations.localeOf(context);
    final isSelected = currentLocale.languageCode == languageCode;

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: isSelected
          ? const Icon(Icons.check, color: Color(0xFF1976D2))
          : null,
      onTap: () {
        if (!isSelected) {
          // LocaleNotifier'ı main.dart'tan al
          final localeNotifier = Provider.of<LocaleNotifier>(context, listen: false);
          localeNotifier.changeLocale(Locale(languageCode));
        }
      },
    );
  }
}
