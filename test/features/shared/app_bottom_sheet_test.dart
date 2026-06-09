import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/shared/widgets/app_bottom_sheet.dart';

/// Pumps a button that opens [open] when tapped, then taps it.
Future<void> _openVia(
  WidgetTester tester,
  Future<void> Function(BuildContext context) open,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('AppDynamicBottomSheet.show', () {
    testWidgets('renders a short list and returns the tapped item', (
      tester,
    ) async {
      String? result;
      await _openVia(tester, (context) async {
        result = await AppDynamicBottomSheet.show<String>(
          context: context,
          title: 'Select Customer',
          items: const ['Alice', 'Bob', 'Carol'],
          itemBuilder: (context, item, selected) => Text(item),
          onItemSelected: (item) => Navigator.pop(context, item),
        );
      });

      expect(find.text('Select Customer'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Carol'), findsOneWidget);

      await tester.tap(find.text('Bob'));
      await tester.pumpAndSettle();
      expect(result, 'Bob');
    });

    testWidgets('short content does not occupy the full screen height', (
      tester,
    ) async {
      await _openVia(tester, (context) async {
        await AppDynamicBottomSheet.show<String>(
          context: context,
          items: const ['One', 'Two', 'Three'],
          itemBuilder: (context, item, selected) => Text(item),
          onItemSelected: (_) {},
        );
      });

      final screenHeight = tester.view.physicalSize.height /
          tester.view.devicePixelRatio;
      final sheetHeight = tester.getSize(find.byType(AppBottomSheet)).height;
      // A 3-item sheet should be well under the 95% cap.
      expect(sheetHeight, lessThan(screenHeight * 0.6));
    });

    testWidgets('filters items via the search field', (tester) async {
      await _openVia(tester, (context) async {
        await AppDynamicBottomSheet.show<String>(
          context: context,
          title: 'Currency',
          items: const ['MYR', 'USD', 'EUR'],
          searchable: true,
          searchText: (c) => c,
          itemBuilder: (context, item, selected) => Text(item),
          onItemSelected: (_) {},
        );
      });

      await tester.enterText(find.byType(TextField), 'us');
      await tester.pumpAndSettle();
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('MYR'), findsNothing);
    });
  });

  group('AppDynamicBottomSheet.showRadio', () {
    testWidgets('marks the current value as selected', (tester) async {
      await _openVia(tester, (context) async {
        await AppDynamicBottomSheet.showRadio<int>(
          context: context,
          title: 'Pick',
          items: const [1, 2, 3],
          value: 2,
          labelBuilder: (v) => 'Item $v',
          onChanged: (_) {},
        );
      });

      expect(find.text('Item 2'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
    });
  });

  group('AppDynamicBottomSheet.showInfo', () {
    testWidgets('renders description and footer actions', (tester) async {
      var pressed = false;
      await _openVia(tester, (context) async {
        await AppDynamicBottomSheet.showInfo(
          context: context,
          title: 'Delete Invoice?',
          description: 'This action cannot be undone.',
          primaryAction: AppBottomSheetAction(
            label: 'Delete',
            isDestructive: true,
            onPressed: () => pressed = true,
          ),
          secondaryAction: AppBottomSheetAction(
            label: 'Cancel',
            isPrimary: false,
            onPressed: () => Navigator.pop(context),
          ),
        );
      });

      expect(find.text('This action cannot be undone.'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(pressed, isTrue);
    });
  });
}
