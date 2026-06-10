import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/configs/routes/generate_route.dart';
import 'package:invois/configs/routes/routes_name.dart';
import 'package:invois/core/database/objectbox_database.dart';
import 'package:invois/features/invoice/data/invoice_money_backfill.dart';
import 'package:invois/features/setting/providers/settings_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ObjectBoxDatabase.init();
  await _runMoneyBackfillOnce();
  runApp(const ProviderScope(child: MyApp()));
}

/// Run the S3 money backfill at most once per install (P2-004).
///
/// The backfill is idempotent but scans every invoice before `runApp`. After
/// one complete pass nothing is left to convert — every write path dual-writes
/// cents — so later launches skip the scan. (Restoring a pre-S3 database
/// backup over an existing install would need this flag cleared; see
/// doc/audits.)
Future<void> _runMoneyBackfillOnce() async {
  const doneFlag = 's3_money_backfill_done_v1';
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(doneFlag) ?? false) return;

  final report = S3MoneyBackfill(ObjectBoxDatabase.instance).run();
  if (report.hasChanges) {
    debugPrint('S3 money backfill completed: $report');
  }
  await prefs.setBool(doneFlag, true);
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Invois',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      // Honour System / Light / Dark (SettingsState exposes the mapping).
      themeMode: state.materialThemeMode,
      locale: Locale(state.languageCode.code),
      localeResolutionCallback: (locale, supportedLocales) {
        // Check if the current device locale is supported
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
            return supportedLocale;
          }
        }
        // If not supported, return the first supported locale (English)
        return supportedLocales.first;
      },

      // Route configuration — single source of truth. `generateRoute` resolves
      // `initialRoute` (the splash) and every named push; no `home:` override.
      onGenerateRoute: generateRoute,
      initialRoute: RoutesName.splash,
    );
  }
}
