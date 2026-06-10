import 'settings_local_source.dart';
import '../providers/settings_state.dart';

class SettingsRepository {
  final SettingsLocalSource _localSource;

  SettingsRepository({SettingsLocalSource? localSource})
    : _localSource = localSource ?? SettingsLocalSource();

  // Individual getter methods
  Future<LanguageCode> getLanguageCode() async {
    return await _localSource.getLanguageCode();
  }

  Future<AppThemeMode> getThemeMode() async {
    return await _localSource.getThemeMode();
  }

  Future<String> getCurrencyCode() async {
    return await _localSource.getCurrencyCode();
  }

  // Update methods
  Future<void> updateLanguageCode(LanguageCode languageCode) async {
    await _localSource.updateLanguageCode(languageCode);
  }

  Future<void> updateThemeMode(AppThemeMode themeMode) async {
    await _localSource.updateThemeMode(themeMode);
  }

  Future<void> updateCurrency(String currencyCode) async {
    await _localSource.updateCurrency(currencyCode);
  }

  Future<void> resetSettings() async {
    await _localSource.resetSettings();
  }
}
