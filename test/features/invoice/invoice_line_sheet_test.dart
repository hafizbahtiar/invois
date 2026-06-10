import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/invoice_form_line.dart';
import 'package:invois/features/invoice/presentation/widgets/invoice_line_sheet.dart';
import 'package:invois/features/shared/widgets/app_bottom_sheet.dart';

/// Pumps an app (optionally with a simulated keyboard inset), opens
/// [InvoiceLineSheet.show], settles, and returns a getter for the result the
/// sheet eventually pops with.
Future<InvoiceLineSheetResult? Function()> _pumpAndOpenSheet(
  WidgetTester tester, {
  InvoiceFormLine? existingLine,
  double keyboardInset = 0,
}) async {
  InvoiceLineSheetResult? result;

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(viewInsets: EdgeInsets.only(bottom: keyboardInset)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await InvoiceLineSheet.show(
                  context,
                  existingLine: existingLine,
                  currencyCode: 'MYR',
                  temporaryLineId: -7,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  return () => result;
}

void main() {
  testWidgets('valid input returns a saved line with exact cents/milli', (
    tester,
  ) async {
    final getResult = await _pumpAndOpenSheet(tester);

    expect(find.text('Add Item'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Coffee',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Price'),
      '12.50',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quantity'),
      '2.5',
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final result = getResult();
    expect(result, isNotNull);
    expect(result!.removed, isFalse);
    expect(result.line!.id, -7);
    expect(result.line!.name, 'Coffee');
    expect(result.line!.unitPriceCents, 1250);
    expect(result.line!.quantityMilli, 2500);
    expect(result.line!.currency, 'MYR');
  });

  testWidgets('invalid input shows validation errors and stays open', (
    tester,
  ) async {
    await _pumpAndOpenSheet(tester);

    // Name and price empty; quantity cleared to be invalid too.
    await tester.enterText(find.widgetWithText(TextFormField, 'Quantity'), '');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter item name'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('Enter a quantity'), findsOneWidget);
    // Still open, no layout exceptions.
    expect(find.text('Add Item'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'small phone with keyboard open: fields and actions stay usable',
    (tester) async {
      // iPhone-SE-class logical surface.
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pumpAndOpenSheet(tester, keyboardInset: 260);

      // The sheet surface is lifted above the keyboard: the visible Material's
      // bottom edge sits at or above the inset line, and the primary action is
      // hittable.
      final surfaceRect = tester.getRect(
        find
            .descendant(
              of: find.byType(AppBottomSheet),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(surfaceRect.bottom, lessThanOrEqualTo(568 - 260 + 0.01));
      expect(find.text('Add'), findsOneWidget);
      await tester.tap(find.text('Add')); // empty form -> validation, no crash
      await tester.pumpAndSettle();

      expect(find.text('Please enter item name'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long item names render without layout exceptions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpAndOpenSheet(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Professional consulting services for the full migration of the legacy '
              'invoicing platform including discovery, planning, and delivery' *
          2,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('edit mode prefills, updates, and supports Remove', (
    tester,
  ) async {
    const existing = InvoiceFormLine(
      id: -3,
      name: 'Design work',
      description: 'Logo refresh',
      unitPriceCents: 50000,
      quantityMilli: 1500,
      currency: 'MYR',
      sortOrder: 2,
    );

    final getResult = await _pumpAndOpenSheet(tester, existingLine: existing);

    expect(find.text('Edit Item'), findsOneWidget);
    expect(find.text('Design work'), findsOneWidget);
    expect(find.text('500.00'), findsOneWidget);
    expect(find.text('1.5'), findsOneWidget);

    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    final result = getResult();
    expect(result!.removed, isFalse);
    // Identity and ordering snapshot fields survive the round-trip.
    expect(result.line!.id, -3);
    expect(result.line!.sortOrder, 2);
    expect(result.line!.unitPriceCents, 50000);
    expect(result.line!.quantityMilli, 1500);
  });

  testWidgets('Remove returns a removed result', (tester) async {
    const existing = InvoiceFormLine(
      id: -3,
      name: 'Design work',
      unitPriceCents: 50000,
      quantityMilli: 1000,
    );

    final getResult = await _pumpAndOpenSheet(tester, existingLine: existing);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    final result = getResult();
    expect(result!.removed, isTrue);
    expect(result.line, isNull);
  });

  testWidgets('Cancel dismisses without a result', (tester) async {
    final getResult = await _pumpAndOpenSheet(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(getResult(), isNull);
  });
}
