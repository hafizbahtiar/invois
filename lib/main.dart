import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/configs/routes/generate_route.dart';
import 'package:invois/configs/routes/routes_name.dart';
import 'package:invois/core/database/objectbox_database.dart';
import 'package:invois/features/invoice/data/invoice_line_backfill.dart';
import 'package:invois/features/invoice/data/invoice_money_backfill.dart';
import 'package:invois/features/setting/providers/settings_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ObjectBoxDatabase.init();
  final moneyBackfill = S3MoneyBackfill(ObjectBoxDatabase.instance).run();
  if (moneyBackfill.hasChanges) {
    debugPrint('S3 money backfill completed: $moneyBackfill');
  }
  // Step 4B (additive): create InvoiceLine snapshots from legacy items. Runs
  // after the money backfill so unit-price cents are populated. Idempotent.
  final lineBackfill = InvoiceLineBackfill(ObjectBoxDatabase.instance).run();
  if (lineBackfill.hasChanges) {
    debugPrint('S4 invoice line backfill completed: $lineBackfill');
  }
  runApp(const ProviderScope(child: MyApp()));
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
