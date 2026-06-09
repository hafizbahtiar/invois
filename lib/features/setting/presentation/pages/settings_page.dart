import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/configs/routes/routes_name.dart';
import 'package:invois/features/setting/providers/settings_state.dart';
import 'package:invois/features/shared/widgets/app_bottom_sheet.dart';
import 'package:invois/features/shared/widgets/my_tile.dart';
import '../../../shared/widgets/simple_header_section.dart';
import '../../providers/settings_notifier.dart';
import 'package:invois/core/utils/currency_utils.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        centerTitle: false,
        title: Text('Settings'),
        actions: [
          if (state.error != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => notifier.loadSettings(),
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Appearance Section
                  SimpleHeaderSection(
                    title: 'Appearance',
                    variant: SimpleHeaderVariant.iconic,
                    icon: Icons.brightness_6,
                    subtitle: 'Customize app appearance',
                  ),
                  MyTile(
                    icon: Icons.brightness_6,
                    title: 'Theme Mode',
                    subtitle: state.themeMode.displayName,
                    isRounded: true,
                    onTap: () async {
                      final selected =
                          await AppDynamicBottomSheet.showRadio<AppThemeMode>(
                            context: context,
                            title: 'Theme Mode',
                            items: AppThemeMode.values,
                            value: state.themeMode,
                            labelBuilder: (mode) => mode.displayName,
                            onChanged: (mode) => Navigator.pop(context, mode),
                          );
                      if (selected != null && selected != state.themeMode) {
                        notifier.updateThemeMode(selected);
                      }
                    },
                  ),

                  const SizedBox(height: 18),

                  // Reset Section
                  SimpleHeaderSection(
                    title: 'Invoice',
                    variant: SimpleHeaderVariant.iconic,
                    icon: Icons.receipt_long,
                    subtitle: 'Invoice settings',
                  ),
                  MyTile(
                    icon: Icons.business,
                    title: 'Business',
                    subtitle: 'Business settings',
                    isRounded: true,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(RoutesName.businessList),
                  ),
                  MyTile(
                    icon: Icons.group,
                    title: 'Client',
                    subtitle: 'Client settings',
                    isRounded: true,
                    onTap: () =>
                        Navigator.of(context).pushNamed(RoutesName.clientList),
                  ),
                  MyTile(
                    icon: Icons.draw,
                    title: 'Signature',
                    subtitle: 'Signature settings',
                    isRounded: true,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(RoutesName.signatureList),
                  ),
                  MyTile(
                    icon: Icons.percent,
                    title: 'Tax',
                    subtitle: 'Tax settings',
                    isRounded: true,
                    onTap: () =>
                        Navigator.pushNamed(context, RoutesName.taxList),
                  ),
                  MyTile(
                    icon: Icons.description,
                    title: 'Terms & Conditions',
                    subtitle: 'Terms & Conditions settings',
                    isRounded: true,
                    onTap: () =>
                        Navigator.pushNamed(context, RoutesName.termList),
                  ),
                  MyTile(
                    icon: Icons.payments,
                    title: 'Default Currency',
                    subtitle:
                        '${CurrencyUtils.getName(state.currencyCode)} (${CurrencyUtils.getSymbol(state.currencyCode)})',
                    isRounded: true,
                    onTap: () async {
                      final codes = CurrencyUtils.currencies.keys.toList();
                      String labelFor(String code) {
                        final info = CurrencyUtils.currencies[code]!;
                        return '${info.code} - ${info.name} (${info.symbol})';
                      }

                      final selected = await AppDynamicBottomSheet.show<String>(
                        context: context,
                        title: 'Select Currency',
                        items: codes,
                        selectedValue: state.currencyCode,
                        searchable: true,
                        searchText: labelFor,
                        searchHint: 'Search currency',
                        itemBuilder: (context, code, selected) => Text(
                          labelFor(code),
                          style: TextStyle(
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        onItemSelected: (code) => Navigator.pop(context, code),
                      );
                      if (selected != null && selected != state.currencyCode) {
                        notifier.updateCurrency(selected);
                      }
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
