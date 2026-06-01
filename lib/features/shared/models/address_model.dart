import 'package:equatable/equatable.dart';
import 'package:invois/features/client/data/client_model.dart';
import 'package:objectbox/objectbox.dart';
import 'package:invois/core/utils/safe_parse.dart';
import 'package:invois/features/business/data/business_model.dart';

@Entity()
// ignore: must_be_immutable
class Address extends Equatable {
  @Id()
  int id;

  final String? label;
  final String? streetAddress1;
  final String? streetAddress2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final String? countryCode;
  final String? notes;
  final bool isDefault;
  final bool isActive;
  final bool isBillingAddress;
  final bool isShippingAddress;
  final double? latitude;
  final double? longitude;

  @Property(type: PropertyType.date)
  final DateTime? createdAt;

  @Property(type: PropertyType.date)
  final DateTime? updatedAt;

  // Many-to-one relationship with Business
  final ToOne<Business> business = ToOne<Business>();

  // Many-to-one relationship with Client
  final ToOne<Client> client = ToOne<Client>();

  Address({
    this.id = 0,
    this.label,
    this.streetAddress1,
    this.streetAddress2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.countryCode,
    this.notes,
    this.isDefault = false,
    this.isActive = true,
    this.isBillingAddress = false,
    this.isShippingAddress = false,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id,
    label,
    streetAddress1,
    streetAddress2,
    city,
    state,
    postalCode,
    country,
    countryCode,
    notes,
    isDefault,
    isActive,
    isBillingAddress,
    isShippingAddress,
    latitude,
    longitude,
    business.target?.id,
    client.target?.id,
    createdAt,
    updatedAt,
  ];

  Address copyWith({
    int? id,
    String? label,
    String? streetAddress1,
    String? streetAddress2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? countryCode,
    String? notes,
    bool? isDefault,
    bool? isActive,
    bool? isBillingAddress,
    bool? isShippingAddress,
    double? latitude,
    double? longitude,
    Business? business,
    Client? client,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Address(
      id: id ?? this.id,
      label: label ?? this.label,
      streetAddress1: streetAddress1 ?? this.streetAddress1,
      streetAddress2: streetAddress2 ?? this.streetAddress2,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      notes: notes ?? this.notes,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      isBillingAddress: isBillingAddress ?? this.isBillingAddress,
      isShippingAddress: isShippingAddress ?? this.isShippingAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    )
      ..business.target = business ?? this.business.target
      ..client.target = client ?? this.client.target;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'streetAddress1': streetAddress1,
      'streetAddress2': streetAddress2,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'country': country,
      'countryCode': countryCode,
      'notes': notes,
      'isDefault': isDefault,
      'isActive': isActive,
      'isBillingAddress': isBillingAddress,
      'isShippingAddress': isShippingAddress,
      'latitude': latitude,
      'longitude': longitude,
      'businessId': business.target?.id,
      'clientId': client.target?.id,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      id: SafeParse.integer(map['id']),
      label: map['label'],
      streetAddress1: map['streetAddress1'],
      streetAddress2: map['streetAddress2'],
      city: map['city'],
      state: map['state'],
      postalCode: map['postalCode'],
      country: map['country'],
      countryCode: map['countryCode'],
      notes: map['notes'],
      isDefault: SafeParse.boolean(map['isDefault']),
      isActive: SafeParse.boolean(map['isActive']),
      isBillingAddress: SafeParse.boolean(map['isBillingAddress']),
      isShippingAddress: SafeParse.boolean(map['isShippingAddress']),
      latitude: SafeParse.decimal(map['latitude']),
      longitude: SafeParse.decimal(map['longitude']),
      createdAt: SafeParse.dateTime(map['createdAt']),
      updatedAt: SafeParse.dateTime(map['updatedAt']),
    );
  }

  /// Returns a formatted address string
  String get formattedAddress {
    final parts = <String>[];

    if (streetAddress1?.isNotEmpty == true) parts.add(streetAddress1!);
    if (streetAddress2?.isNotEmpty == true) parts.add(streetAddress2!);

    final cityStateZip = <String>[];
    if (city?.isNotEmpty == true) cityStateZip.add(city!);
    if (state?.isNotEmpty == true) cityStateZip.add(state!);
    if (postalCode?.isNotEmpty == true) cityStateZip.add(postalCode!);

    if (cityStateZip.isNotEmpty) {
      parts.add(cityStateZip.join(', '));
    }

    if (country?.isNotEmpty == true) parts.add(country!);

    return parts.join('\n');
  }

  /// Returns a single line address string
  String get singleLineAddress {
    final parts = <String>[];

    if (streetAddress1?.isNotEmpty == true) parts.add(streetAddress1!);
    if (streetAddress2?.isNotEmpty == true) parts.add(streetAddress2!);
    if (city?.isNotEmpty == true) parts.add(city!);
    if (state?.isNotEmpty == true) parts.add(state!);
    if (postalCode?.isNotEmpty == true) parts.add(postalCode!);
    if (country?.isNotEmpty == true) parts.add(country!);

    return parts.join(', ');
  }
}
