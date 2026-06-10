import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum LanguageCode {
  en('en', 'English'),
  id('id', 'Bahasa Indonesia'),
  ms('ms', 'Bahasa Melayu');

  const LanguageCode(this.code, this.displayName);
  final String code;
  final String displayName;
}

enum AppThemeMode {
  system('system', 'System'),
  light('light', 'Light'),
  dark('dark', 'Dark');

  const AppThemeMode(this.value, this.displayName);
  final String value;
  final String displayName;
}

class SettingsState extends Equatable {
  final LanguageCode languageCode;
  final AppThemeMode themeMode;
  final String currencyCode;
  final bool isLoading;
  final String? error;

  const SettingsState({
    this.languageCode = LanguageCode.en,
    this.themeMode = AppThemeMode.system,
    this.currencyCode = 'USD',
    this.isLoading = false,
    this.error,
  });

  SettingsState copyWith({
    LanguageCode? languageCode,
    AppThemeMode? themeMode,
    String? currencyCode,
    bool? isLoading,
    String? error,
  }) {
    return SettingsState(
      languageCode: languageCode ?? this.languageCode,
      themeMode: themeMode ?? this.themeMode,
      currencyCode: currencyCode ?? this.currencyCode,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  /// Get the theme mode for MaterialApp
  ThemeMode get materialThemeMode {
    switch (themeMode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  /// Get the locale for MaterialApp
  Locale get locale => Locale(languageCode.code);

  @override
  List<Object?> get props => [
    languageCode,
    themeMode,
    currencyCode,
    isLoading,
    error,
  ];
}
