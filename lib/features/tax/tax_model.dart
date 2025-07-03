import 'package:equatable/equatable.dart';
import 'package:invois/core/utils/safe_parse.dart';
import 'package:invois/features/invoice/invoice_model.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
// ignore: must_be_immutable
class Tax extends Equatable {
  @Id()
  int? id;

  final String name;
  final String? description;
  final String? taxType;
  final double rate;
  final bool isActive;
  final bool isDefault;
  final int? businessId;

  // Invoice relationship
  final ToOne<Invoice> invoice = ToOne<Invoice>();

  @Property(type: PropertyType.date)
  final DateTime? createdAt;

  @Property(type: PropertyType.date)
  final DateTime? updatedAt;

  Tax({
    this.id = 0,
    required this.name,
    this.description,
    this.taxType,
    this.rate = 0.0,
    this.isActive = true,
    this.isDefault = false,
    this.businessId,
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    taxType,
    rate,
    isActive,
    isDefault,
    businessId,
    createdAt,
    updatedAt,
  ];

  Tax copyWith({
    int? id,
    String? name,
    String? description,
    String? taxType,
    double? rate,
    bool? isActive,
    bool? isDefault,
    int? businessId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tax(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      taxType: taxType ?? this.taxType,
      rate: rate ?? this.rate,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
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
      'taxType': taxType,
      'rate': rate,
      'isActive': isActive,
      'isDefault': isDefault,
      'businessId': businessId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Tax.fromMap(Map<String, dynamic> map) {
    return Tax(
      id: SafeParse.integer(map['id']),
      name: map['name'] ?? '',
      description: map['description'],
      taxType: SafeParse.string(map['taxType']),
      rate: SafeParse.decimal(map['rate']),
      isActive: SafeParse.boolean(map['isActive']),
      isDefault: SafeParse.boolean(map['isDefault']),
      businessId: SafeParse.integer(map['businessId']),
      createdAt: SafeParse.dateTime(map['createdAt']),
      updatedAt: SafeParse.dateTime(map['updatedAt']),
    );
  }

  @override
  String toString() {
    return 'Tax(id: $id, name: $name, description: $description, rate: $rate, isActive: $isActive, isDefault: $isDefault, businessId: $businessId, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
