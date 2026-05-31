import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/configs/routes/generate_route.dart';
import 'package:invois/configs/routes/routes_name.dart';
import 'package:invois/core/database/objectbox_database.dart';
import 'package:invois/features/invoice/invoice_money_backfill.dart';
import 'package:invois/features/setting/presentation/providers/settings_provider.dart';
import 'package:invois/features/setting/presentation/providers/settings_state.dart';
import 'package:invois/features/splash/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ObjectBoxDatabase.init();
  final moneyBackfill = S3MoneyBackfill(ObjectBoxDatabase.instance).run();
  if (moneyBackfill.hasChanges) {
    debugPrint('S3 money backfill completed: $moneyBackfill');
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
      // themeMode: settings.materialThemeMode,
      themeMode: state.themeMode == AppThemeMode.dark
          ? ThemeMode.dark
          : ThemeMode.light,
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

      // Route configuration
      onGenerateRoute: generateRoute,
      initialRoute: RoutesName.splash,
      home: const SplashPage(),
    );
  }
}
