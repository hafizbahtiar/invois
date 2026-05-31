import 'package:equatable/equatable.dart';
import 'package:invois/core/money/money.dart';
import 'package:invois/core/utils/safe_parse.dart';
import 'package:invois/features/invoice/invoice_model.dart';
import 'package:objectbox/objectbox.dart';

/// Enum to define the type of item (product, service, etc.)
enum ItemType { product, service, other }

/// Enum to define the unit of measurement
enum ItemUnit {
  piece,
  hour,
  day,
  week,
  month,
  year,
  kg,
  gram,
  liter,
  meter,
  squareMeter,
  cubicMeter,
  custom,
}

@Entity()
// ignore: must_be_immutable
class Item extends Equatable {
  @Id()
  int? id;

  final String name;
  final String? description;
  final String? sku; // Stock Keeping Unit
  final String? barcode;
  final String? category;
  final String? brand;
  final String? model;
  final String? color;
  final String? size;
  final String? weight;
  final String? dimensions;

  // Pricing
  final double unitPrice;
  final double? costPrice;
  final double? wholesalePrice;
  final String? currency;
  final bool isTaxable;
  final double? taxRate;
  final bool isTaxInclusive;

  // Stage A S3: additive integer minor-unit fields. Old double fields remain
  // during S3 for rollback-compatible dual writes.
  int? unitPriceCents;
  int? costPriceCents;
  int? wholesalePriceCents;

  // Inventory
  final int? stockQuantity;
  final int? minStockLevel;
  final int? maxStockLevel;
  final bool trackInventory;
  final bool isActive;
  final bool isDefault;

  // Item Type and Unit (store as int for ObjectBox)
  final String? itemType;
  final String? unit;
  final String? customUnit;

  // Business relationship
  final int? businessId;

  // Invoice relationship
  final ToOne<Invoice> invoice = ToOne<Invoice>();

  // Timestamps
  @Property(type: PropertyType.date)
  final DateTime? createdAt;

  @Property(type: PropertyType.date)
  final DateTime? updatedAt;

  Item({
    this.id = 0,
    required this.name,
    this.description,
    this.sku,
    this.barcode,
    this.category,
    this.brand,
    this.model,
    this.color,
    this.size,
    this.weight,
    this.dimensions,
    required this.unitPrice,
    this.costPrice,
    this.wholesalePrice,
    this.currency,
    this.isTaxable = true,
    this.taxRate,
    this.isTaxInclusive = false,
    this.unitPriceCents,
    this.costPriceCents,
    this.wholesalePriceCents,
    this.stockQuantity,
    this.minStockLevel,
    this.maxStockLevel,
    this.trackInventory = false,
    this.isActive = true,
    this.isDefault = false,
    this.itemType,
    this.unit,
    this.customUnit,
    this.businessId,
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    sku,
    barcode,
    category,
    brand,
    model,
    color,
    size,
    weight,
    dimensions,
    unitPrice,
    costPrice,
    wholesalePrice,
    currency,
    isTaxable,
    taxRate,
    isTaxInclusive,
    unitPriceCents,
    costPriceCents,
    wholesalePriceCents,
    stockQuantity,
    minStockLevel,
    maxStockLevel,
    trackInventory,
    isActive,
    isDefault,
    itemType,
    unit,
    customUnit,
    businessId,
    createdAt,
    updatedAt,
  ];

  Item copyWith({
    int? id,
    String? name,
    String? description,
    String? sku,
    String? barcode,
    String? category,
    String? brand,
    String? model,
    String? color,
    String? size,
    String? weight,
    String? dimensions,
    double? unitPrice,
    double? costPrice,
    double? wholesalePrice,
    String? currency,
    bool? isTaxable,
    double? taxRate,
    bool? isTaxInclusive,
    int? unitPriceCents,
    int? costPriceCents,
    int? wholesalePriceCents,
    int? stockQuantity,
    int? minStockLevel,
    int? maxStockLevel,
    bool? trackInventory,
    bool? isActive,
    bool? isDefault,
    String? itemType,
    String? unit,
    String? customUnit,
    int? businessId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      color: color ?? this.color,
      size: size ?? this.size,
      weight: weight ?? this.weight,
      dimensions: dimensions ?? this.dimensions,
      unitPrice: unitPrice ?? this.unitPrice,
      costPrice: costPrice ?? this.costPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      currency: currency ?? this.currency,
      isTaxable: isTaxable ?? this.isTaxable,
      taxRate: taxRate ?? this.taxRate,
      isTaxInclusive: isTaxInclusive ?? this.isTaxInclusive,
      unitPriceCents: unitPriceCents ?? this.unitPriceCents,
      costPriceCents: costPriceCents ?? this.costPriceCents,
      wholesalePriceCents: wholesalePriceCents ?? this.wholesalePriceCents,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      maxStockLevel: maxStockLevel ?? this.maxStockLevel,
      trackInventory: trackInventory ?? this.trackInventory,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
      itemType: itemType ?? this.itemType,
      unit: unit ?? this.unit,
      customUnit: customUnit ?? this.customUnit,
      businessId: businessId ?? this.businessId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'sku': sku,
      'barcode': barcode,
      'category': category,
      'brand': brand,
      'model': model,
      'color': color,
      'size': size,
      'weight': weight,
      'dimensions': dimensions,
      'unitPrice': unitPrice,
      'costPrice': costPrice,
      'wholesalePrice': wholesalePrice,
      'currency': currency,
      'isTaxable': isTaxable,
      'taxRate': taxRate,
      'isTaxInclusive': isTaxInclusive,
      'unitPriceCents': unitPriceCents,
      'costPriceCents': costPriceCents,
      'wholesalePriceCents': wholesalePriceCents,
      'stockQuantity': stockQuantity,
      'minStockLevel': minStockLevel,
      'maxStockLevel': maxStockLevel,
      'trackInventory': trackInventory,
      'isActive': isActive,
      'isDefault': isDefault,
      'itemType': itemType,
      'unit': unit,
      'customUnit': customUnit,
      'businessId': businessId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: SafeParse.integer(map['id']),
      name: SafeParse.string(map['name']),
      description: SafeParse.string(map['description']),
      sku: SafeParse.string(map['sku']),
      barcode: SafeParse.string(map['barcode']),
      category: SafeParse.string(map['category']),
      brand: SafeParse.string(map['brand']),
      model: SafeParse.string(map['model']),
      color: SafeParse.string(map['color']),
      size: SafeParse.string(map['size']),
      weight: SafeParse.string(map['weight']),
      dimensions: SafeParse.string(map['dimensions']),
      unitPrice: SafeParse.decimal(map['unitPrice'], fallback: 0.0),
      costPrice: SafeParse.decimal(map['costPrice']),
      wholesalePrice: SafeParse.decimal(map['wholesalePrice']),
      currency: SafeParse.string(map['currency']),
      isTaxable: SafeParse.boolean(map['isTaxable'], fallback: true),
      taxRate: SafeParse.decimal(map['taxRate']),
      isTaxInclusive: SafeParse.boolean(map['isTaxInclusive'], fallback: false),
      unitPriceCents: SafeParse.integer(map['unitPriceCents']),
      costPriceCents: SafeParse.integer(map['costPriceCents']),
      wholesalePriceCents: SafeParse.integer(map['wholesalePriceCents']),
      stockQuantity: SafeParse.integer(map['stockQuantity']),
      minStockLevel: SafeParse.integer(map['minStockLevel']),
      maxStockLevel: SafeParse.integer(map['maxStockLevel']),
      trackInventory: SafeParse.boolean(map['trackInventory'], fallback: false),
      isActive: SafeParse.boolean(map['isActive'], fallback: true),
      isDefault: SafeParse.boolean(map['isDefault'], fallback: false),
      itemType: SafeParse.string(map['itemType']),
      unit: SafeParse.string(map['unit']),
      customUnit: SafeParse.string(map['customUnit']),
      businessId: SafeParse.integer(map['businessId']),
      createdAt: SafeParse.dateTime(map['createdAt']),
      updatedAt: SafeParse.dateTime(map['updatedAt']),
    );
  }

  @override
  String toString() {
    return 'Item(id: $id, name: $name, description: $description, sku: $sku, barcode: $barcode, category: $category, brand: $brand, model: $model, color: $color, size: $size, weight: $weight, dimensions: $dimensions, unitPrice: $unitPrice, costPrice: $costPrice, wholesalePrice: $wholesalePrice, currency: $currency, isTaxable: $isTaxable, taxRate: $taxRate, isTaxInclusive: $isTaxInclusive, stockQuantity: $stockQuantity, minStockLevel: $minStockLevel, maxStockLevel: $maxStockLevel, trackInventory: $trackInventory, isActive: $isActive, isDefault: $isDefault, itemType: $itemType, unit: $unit, customUnit: $customUnit, businessId: $businessId, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  // ================================
  //    MARK: Helper Methods
  // ================================

  String get moneyCurrencyCode => currency ?? 'MYR';

  int get effectiveUnitPriceCents =>
      unitPriceCents ?? Money.fromDouble(unitPrice).minorUnits;
  int? get effectiveCostPriceCents =>
      costPriceCents ??
      (costPrice == null ? null : Money.fromDouble(costPrice!).minorUnits);
  int? get effectiveWholesalePriceCents =>
      wholesalePriceCents ??
      (wholesalePrice == null
          ? null
          : Money.fromDouble(wholesalePrice!).minorUnits);

  /// Get the display unit (custom unit if specified, otherwise enum name)
  String get displayUnit {
    if (ItemUnit.values.byName(unit ?? '') == ItemUnit.custom &&
        customUnit != null) {
      return customUnit!;
    }
    return unit ?? '';
  }

  /// Calculate price with tax
  double get priceWithTax {
    if (!isTaxable || taxRate == null || taxRate == 0) {
      return Money(effectiveUnitPriceCents).toDouble();
    }

    if (isTaxInclusive) {
      return Money(effectiveUnitPriceCents).toDouble();
    } else {
      return Money(effectiveUnitPriceCents).percent(100 + taxRate!).toDouble();
    }
  }

  /// Calculate tax amount
  double get taxAmount {
    if (!isTaxable || taxRate == null || taxRate == 0) {
      return 0.0;
    }

    if (isTaxInclusive) {
      final gross = Money(effectiveUnitPriceCents);
      final netCents = (gross.minorUnits / (1 + taxRate! / 100)).round();
      return Money(gross.minorUnits - netCents).toDouble();
    } else {
      return Money(effectiveUnitPriceCents).percent(taxRate!).toDouble();
    }
  }

  /// Check if item is in stock
  bool get isInStock {
    if (!trackInventory || stockQuantity == null) {
      return true; // If not tracking inventory, assume in stock
    }
    return stockQuantity! > 0;
  }

  /// Check if item is low in stock
  bool get isLowStock {
    if (!trackInventory || stockQuantity == null || minStockLevel == null) {
      return false;
    }
    return stockQuantity! <= minStockLevel!;
  }

  /// Get profit margin percentage
  double? get profitMargin {
    final costCents = effectiveCostPriceCents;
    if (costCents == null || costCents == 0) return null;
    return ((effectiveUnitPriceCents - costCents) / costCents) * 100;
  }

  /// Get formatted price with currency
  String get formattedPrice {
    final currencySymbol = currency ?? '\$';
    return Money(effectiveUnitPriceCents).format(symbol: currencySymbol);
  }

  /// Get formatted price with tax
  String get formattedPriceWithTax {
    final currencySymbol = currency ?? '\$';
    return Money.fromDouble(priceWithTax).format(symbol: currencySymbol);
  }

  /// Get stock status text
  String get stockStatus {
    if (!trackInventory) return 'Not tracked';
    if (stockQuantity == null) return 'Unknown';
    if (stockQuantity! <= 0) return 'Out of stock';
    if (isLowStock) return 'Low stock';
    return 'In stock';
  }

  /// Check if item has all required fields for invoice
  bool get isCompleteForInvoice {
    return name.isNotEmpty && effectiveUnitPriceCents > 0;
  }

  /// Get a short description for display
  String get shortDescription {
    if (description != null && description!.isNotEmpty) {
      return description!.length > 50
          ? '${description!.substring(0, 47)}...'
          : description!;
    }
    return '';
  }

  /// Get item type display name
  String get itemTypeDisplay {
    switch (ItemType.values.byName(itemType ?? '')) {
      case ItemType.product:
        return 'Product';
      case ItemType.service:
        return 'Service';
      case ItemType.other:
        return 'Other';
    }
  }

  /// Get unit display name
  String get unitDisplay {
    switch (ItemUnit.values.byName(unit ?? '')) {
      case ItemUnit.piece:
        return 'Piece';
      case ItemUnit.hour:
        return 'Hour';
      case ItemUnit.day:
        return 'Day';
      case ItemUnit.week:
        return 'Week';
      case ItemUnit.month:
        return 'Month';
      case ItemUnit.year:
        return 'Year';
      case ItemUnit.kg:
        return 'Kilogram';
      case ItemUnit.gram:
        return 'Gram';
      case ItemUnit.liter:
        return 'Liter';
      case ItemUnit.meter:
        return 'Meter';
      case ItemUnit.squareMeter:
        return 'Square Meter';
      case ItemUnit.cubicMeter:
        return 'Cubic Meter';
      case ItemUnit.custom:
        return customUnit ?? 'Custom';
    }
  }
}
