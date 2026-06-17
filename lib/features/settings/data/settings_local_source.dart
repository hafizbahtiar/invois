import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_state.dart';

class SettingsLocalSource {
  static const String _settingsKey = 'app_settings';
  static const String _languageKey = 'language_code';
  static const String _themeKey = 'theme_mode';
  static const String _currencyKey = 'currency_code';

  // Individual getter methods
  Future<LanguageCode> getLanguageCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_languageKey);

      if (languageCode != null) {
        return LanguageCode.values.firstWhere(
          (lang) => lang.code == languageCode,
          orElse: () => LanguageCode.en,
        );
      }

      return LanguageCode.en;
    } catch (e) {
      return LanguageCode.en;
    }
  }

  Future<AppThemeMode> getThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeMode = prefs.getString(_themeKey);

      if (themeMode != null) {
        return AppThemeMode.values.firstWhere(
          (theme) => theme.value == themeMode,
          orElse: () => AppThemeMode.system,
        );
      }

      return AppThemeMode.system;
    } catch (e) {
      return AppThemeMode.system;
    }
  }

  Future<String> getCurrencyCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currencyKey) ?? 'USD';
    } catch (e) {
      return 'USD';
    }
  }

  // Update methods
  Future<void> updateLanguageCode(LanguageCode languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode.code);
    } catch (e) {
      throw Exception('Failed to update language code.');
    }
  }

  Future<void> updateThemeMode(AppThemeMode themeMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, themeMode.value);
    } catch (e) {
      throw Exception('Failed to update theme mode.');
    }
  }

  Future<void> updateCurrency(String currencyCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currencyKey, currencyCode);
    } catch (e) {
      throw Exception('Failed to update currency.');
    }
  }

  Future<void> resetSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_languageKey);
      await prefs.remove(_themeKey);
      await prefs.remove(_currencyKey);
      await prefs.remove(_settingsKey);
    } catch (e) {
      throw Exception('Failed to reset settings.');
    }
  }
}
