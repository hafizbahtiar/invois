import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/configs/routes/routes_name.dart';
import 'package:invois/features/setting/providers/settings_state.dart';
import 'package:invois/features/shared/widgets/my_selector_field.dart';
import 'package:invois/features/shared/widgets/my_tile.dart';
import '../../../shared/widgets/simple_header_section.dart';
import '../../providers/settings_notifier.dart';
import 'package:invois/core/utils/currency_utils.dart';
import 'package:invois/features/shared/widgets/my_select_bottom_sheet.dart';

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
              padding: const EdgeInsets.all(36),
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
                    icon: Icons.language,
                    title: 'Theme Mode',
                    subtitle: 'Enable dark mode',
                    trailing: Switch.adaptive(
                      value: state.themeMode == AppThemeMode.dark,
                      onChanged: (value) => notifier.updateThemeMode(
                        value ? AppThemeMode.dark : AppThemeMode.light,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

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
                    icon: Icons.language,
                    title: 'Default Currency',
                    subtitle:
                        '${CurrencyUtils.getName(state.currencyCode)} (${CurrencyUtils.getSymbol(state.currencyCode)})',
                    isRounded: true,
                    onTap: () async {
                      final items = CurrencyUtils.currencies.entries.map((
                        entry,
                      ) {
                        final info = entry.value;
                        return SelectItem<String>(
                          value: info.code,
                          label: '${info.code} - ${info.name} (${info.symbol})',
                        );
                      }).toList();
                      final selected = await MySelectBottomSheet.show<String>(
                        context: context,
                        title: 'Select Currency',
                        items: items,
                        initialSelectedValue: state.currencyCode,
                        searchable: true,
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
