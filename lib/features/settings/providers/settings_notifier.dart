import 'package:flutter_riverpod/legacy.dart';
import '../data/settings_repository.dart';
import 'settings_state.dart';

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsRepository _repository;

  SettingsNotifier(this._repository) : super(const SettingsState()) {
    loadSettings();
  }

  // Load settings
  Future<void> loadSettings() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final languageCode = await _repository.getLanguageCode();
      final themeMode = await _repository.getThemeMode();
      final currencyCode = await _repository.getCurrencyCode();

      state = state.copyWith(
        languageCode: languageCode,
        themeMode: themeMode,
        currencyCode: currencyCode,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Update language code
  Future<void> updateLanguageCode(LanguageCode languageCode) async {
    if (state.languageCode == languageCode) return;
    try {
      await _repository.updateLanguageCode(languageCode);
      state = state.copyWith(languageCode: languageCode, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Update theme mode
  Future<void> updateThemeMode(AppThemeMode themeMode) async {
    if (state.themeMode == themeMode) return;
    try {
      await _repository.updateThemeMode(themeMode);
      state = state.copyWith(themeMode: themeMode, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Update currency code
  Future<void> updateCurrency(String currencyCode) async {
    if (state.currencyCode == currencyCode) return;
    try {
      await _repository.updateCurrency(currencyCode);
      state = state.copyWith(currencyCode: currencyCode, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Reset settings to default
  Future<void> resetSettings() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.resetSettings();
      state = const SettingsState(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  // Getters for current values
  LanguageCode get currentLanguageCode => state.languageCode;
  AppThemeMode get currentThemeMode => state.themeMode;
  String get currentCurrencyCode => state.currencyCode;
}

// Provider for SettingsNotifier
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(SettingsRepository()),
);
