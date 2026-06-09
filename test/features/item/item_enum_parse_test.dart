import 'package:flutter_test/flutter_test.dart';
import 'package:invois/core/utils/currency_utils.dart';
import 'package:invois/features/item/item_model.dart';

/// Stage 1 (P1-001 / P2-005): the item getters used to call
/// `Enum.values.byName(... ?? '')` (throws on unknown/legacy values) and used
/// the currency *code* as the display symbol. These tests lock in the safe
/// parsing and the symbol fix.
void main() {
  Item itemWith({
    String? unit,
    String? customUnit,
    String? itemType,
    String? currency,
    int unitPriceCents = 1000,
  }) {
    return Item(
      name: 'Widget',
      unitPrice: unitPriceCents / 100,
      unitPriceCents: unitPriceCents,
      unit: unit,
      customUnit: customUnit,
      itemType: itemType,
      currency: currency,
    );
  }

  group('Item enum getters do not throw on null/legacy values', () {
    test('unknown unit falls back to the raw stored string', () {
      final item = itemWith(unit: 'furlong');
      expect(() => item.unitDisplay, returnsNormally);
      expect(() => item.displayUnit, returnsNormally);
      expect(item.unitDisplay, 'furlong');
      expect(item.displayUnit, 'furlong');
    });

    test('null unit is handled', () {
      final item = itemWith();
      expect(() => item.unitDisplay, returnsNormally);
      expect(item.displayUnit, '');
    });

    test('known unit resolves to display name', () {
      expect(itemWith(unit: 'hour').unitDisplay, 'Hour');
    });

    test('custom unit uses customUnit value', () {
      expect(itemWith(unit: 'custom', customUnit: 'box').displayUnit, 'box');
    });

    test('unknown item type falls back to Other', () {
      final item = itemWith(itemType: 'mystery');
      expect(() => item.itemTypeDisplay, returnsNormally);
      expect(item.itemTypeDisplay, 'Other');
    });

    test('known item type resolves', () {
      expect(itemWith(itemType: 'service').itemTypeDisplay, 'Service');
    });
  });

  group('Item.formattedPrice uses the currency symbol, not the code', () {
    test('MYR renders with its symbol', () {
      final item = itemWith(currency: 'MYR', unitPriceCents: 1000);
      final symbol = CurrencyUtils.getSymbol('MYR');
      expect(item.formattedPrice, '${symbol}10.00');
      // Guard against regressing to the raw code as the symbol.
      expect(item.formattedPrice.startsWith('MYR'), isFalse);
    });

    test('null currency defaults to MYR symbol', () {
      final item = itemWith(currency: null, unitPriceCents: 500);
      expect(item.formattedPrice, '${CurrencyUtils.getSymbol('MYR')}5.00');
    });
  });
}
