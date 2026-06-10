import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/settings/providers/settings_notifier.dart';
import 'package:invois/features/settings/data/settings_repository.dart';
import 'package:invois/features/settings/providers/settings_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SHOULD-tier coverage (blueprint §14): SettingsNotifier state transitions
/// over a mocked SharedPreferences backend. No native libs required.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The notifier loads asynchronously in its constructor; pump microtasks
  /// until loading settles.
  Future<SettingsNotifier> loadedNotifier() async {
    final notifier = SettingsNotifier(SettingsRepository());
    while (notifier.state.isLoading) {
      await Future<void>.delayed(Duration.zero);
    }
    return notifier;
  }

  test('loads defaults when nothing is persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = await loadedNotifier();

    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.error, isNull);
    expect(notifier.state.languageCode, LanguageCode.en);
    expect(notifier.state.themeMode, AppThemeMode.system);
    expect(notifier.state.currencyCode, 'USD');
  });

  test('hydrates persisted values on load', () async {
    SharedPreferences.setMockInitialValues({
      'language_code': 'ms',
      'theme_mode': 'dark',
      'currency_code': 'MYR',
    });
    final notifier = await loadedNotifier();

    expect(notifier.state.languageCode, LanguageCode.ms);
    expect(notifier.state.themeMode, AppThemeMode.dark);
    expect(notifier.state.currencyCode, 'MYR');
  });

  test('updateThemeMode persists and reflects in state', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = await loadedNotifier();

    await notifier.updateThemeMode(AppThemeMode.dark);
    expect(notifier.state.themeMode, AppThemeMode.dark);

    // Persisted: a fresh notifier rehydrates the new value.
    final reloaded = await loadedNotifier();
    expect(reloaded.state.themeMode, AppThemeMode.dark);
  });

  test('updateCurrency is a no-op when unchanged', () async {
    SharedPreferences.setMockInitialValues({'currency_code': 'MYR'});
    final notifier = await loadedNotifier();

    await notifier.updateCurrency('MYR');
    expect(notifier.state.currencyCode, 'MYR');
  });

  test('resetSettings returns state to defaults', () async {
    SharedPreferences.setMockInitialValues({
      'language_code': 'id',
      'theme_mode': 'light',
      'currency_code': 'IDR',
    });
    final notifier = await loadedNotifier();
    expect(notifier.state.languageCode, LanguageCode.id);

    await notifier.resetSettings();
    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.languageCode, LanguageCode.en);
    expect(notifier.state.themeMode, AppThemeMode.system);
    expect(notifier.state.currencyCode, 'USD');
  });
}
