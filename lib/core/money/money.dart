import 'package:equatable/equatable.dart';

/// Lightweight money value object backed by integer minor units.
///
/// ObjectBox entities should persist [minorUnits] in primitive `int` fields
/// (currently named `*Cents`). The currency is kept alongside money fields so
/// arithmetic can reject accidental cross-currency operations.
class Money extends Equatable implements Comparable<Money> {
  final int minorUnits;
  final String currencyCode;
  final int fractionDigits;

  const Money(
    this.minorUnits, {
    this.currencyCode = 'MYR',
    this.fractionDigits = 2,
  });

  factory Money.zero({String currencyCode = 'MYR', int fractionDigits = 2}) {
    return Money(0, currencyCode: currencyCode, fractionDigits: fractionDigits);
  }

  factory Money.fromDouble(
    double value, {
    String currencyCode = 'MYR',
    int fractionDigits = 2,
  }) {
    return Money(
      (value * _pow10(fractionDigits)).round(),
      currencyCode: currencyCode,
      fractionDigits: fractionDigits,
    );
  }

  factory Money.fromDecimalString(
    String value, {
    String currencyCode = 'MYR',
    int fractionDigits = 2,
  }) {
    final parsed = Money.tryParseDecimalString(
      value,
      currencyCode: currencyCode,
      fractionDigits: fractionDigits,
    );
    if (parsed == null) {
      throw FormatException('Invalid money amount', value);
    }
    return parsed;
  }

  static Money? tryParseDecimalString(
    String value, {
    String currencyCode = 'MYR',
    int fractionDigits = 2,
  }) {
    final cleaned = value
        .replaceAll(',', '')
        .replaceAll(RegExp(r'[^0-9.\-]'), '')
        .trim();
    if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') return null;
    if (!RegExp(r'^-?\d*(\.\d*)?$').hasMatch(cleaned)) return null;

    final isNegative = cleaned.startsWith('-');
    final unsigned = isNegative ? cleaned.substring(1) : cleaned;
    final parts = unsigned.split('.');
    if (parts.length > 2) return null;

    final wholeText = parts[0].isEmpty ? '0' : parts[0];
    final whole = int.tryParse(wholeText);
    if (whole == null) return null;

    final scale = _pow10(fractionDigits);
    final fractionText = parts.length == 2 ? parts[1] : '';
    final padded = (fractionText + '0' * (fractionDigits + 1));
    final keptText = padded.substring(0, fractionDigits);
    final nextDigitText = padded.substring(fractionDigits, fractionDigits + 1);
    final kept = int.tryParse(keptText) ?? 0;
    final nextDigit = int.tryParse(nextDigitText) ?? 0;
    final roundedFraction = kept + (nextDigit >= 5 ? 1 : 0);

    final unsignedUnits = whole * scale + roundedFraction;
    final units = isNegative ? -unsignedUnits : unsignedUnits;
    return Money(
      units,
      currencyCode: currencyCode,
      fractionDigits: fractionDigits,
    );
  }

  Money operator +(Money other) {
    _assertCompatible(other);
    return Money(
      minorUnits + other.minorUnits,
      currencyCode: currencyCode,
      fractionDigits: fractionDigits,
    );
  }

  Money operator -(Money other) {
    _assertCompatible(other);
    return Money(
      minorUnits - other.minorUnits,
      currencyCode: currencyCode,
      fractionDigits: fractionDigits,
    );
  }

  Money multiplyInt(int quantity) {
    return Money(
      minorUnits * quantity,
      currencyCode: currencyCode,
      fractionDigits: fractionDigits,
    );
  }

  Money percent(double rate) {
    return Money(
      (minorUnits * rate / 100).round(),
      currencyCode: currencyCode,
      fractionDigits: fractionDigits,
    );
  }

  double toDouble() => minorUnits / _pow10(fractionDigits);

  String format({String symbol = 'RM'}) {
    final scale = _pow10(fractionDigits);
    final absUnits = minorUnits.abs();
    final whole = absUnits ~/ scale;
    final fraction = (absUnits % scale).toString().padLeft(fractionDigits, '0');
    final sign = minorUnits < 0 ? '-' : '';

    if (fractionDigits == 0) return '$sign$symbol$whole';
    return '$sign$symbol$whole.$fraction';
  }

  void _assertCompatible(Money other) {
    if (currencyCode != other.currencyCode ||
        fractionDigits != other.fractionDigits) {
      throw ArgumentError(
        'Money values are not compatible: '
        '$currencyCode/$fractionDigits vs '
        '${other.currencyCode}/${other.fractionDigits}',
      );
    }
  }

  @override
  int compareTo(Money other) {
    _assertCompatible(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  List<Object?> get props => [minorUnits, currencyCode, fractionDigits];
}

class MoneyCalculator {
  const MoneyCalculator._();

  static Money lineTotal({required Money unitPrice, required int quantity}) {
    return unitPrice.multiplyInt(quantity);
  }

  static Money discountForRate({
    required Money subtotal,
    required double rate,
  }) {
    return subtotal.percent(rate);
  }

  static double discountRate({
    required Money subtotal,
    required Money discount,
  }) {
    if (subtotal.minorUnits == 0) return 0;
    return (discount.minorUnits / subtotal.minorUnits) * 100;
  }

  static Money taxForRate({
    required Money taxableAmount,
    required double rate,
  }) {
    return taxableAmount.percent(rate);
  }

  static Money sum(Iterable<Money> values) {
    final iterator = values.iterator;
    if (!iterator.moveNext()) return Money.zero();

    var total = iterator.current;
    while (iterator.moveNext()) {
      total += iterator.current;
    }
    return total;
  }
}

int _pow10(int exponent) {
  var result = 1;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}
