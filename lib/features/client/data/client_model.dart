import 'package:equatable/equatable.dart';
import 'package:invois/core/utils/safe_parse.dart';
import 'package:invois/features/shared/models/address_model.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
// ignore: must_be_immutable
class Client extends Equatable {
  @Id()
  int? id;

  final String name;
  final String? description;

  // Contact field, not an identity field: intentionally NOT unique (Step 3C).
  final String? email;

  final String? phone;
  final String? company;
  final String? website;

  // Address
  final String? streetAddress1;
  final String? streetAddress2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;

  final bool isActive;
  final bool isDefault;
  final int? businessId;

  @Property(type: PropertyType.date)
  final DateTime? createdAt;

  @Property(type: PropertyType.date)
  final DateTime? updatedAt;

  @Backlink()
  final ToMany<Address> addresses = ToMany<Address>();

  Client({
    this.id = 0,
    required this.name,
    this.description,
    this.email,
    this.phone,
    this.company,
    this.website,
    this.streetAddress1,
    this.streetAddress2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
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
    email,
    phone,
    company,
    website,
    streetAddress1,
    streetAddress2,
    city,
    state,
    postalCode,
    country,
    isActive,
    isDefault,
    businessId,
    createdAt,
    updatedAt,
  ];

  Client copyWith({
    int? id,
    String? name,
    String? description,
    String? email,
    String? phone,
    String? company,
    String? website,
    String? streetAddress1,
    String? streetAddress2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    bool? isActive,
    bool? isDefault,
    int? businessId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearEmail = false,
    bool clearPhone = false,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      email: clearEmail ? null : (email ?? this.email),
      phone: clearPhone ? null : (phone ?? this.phone),
      company: company ?? this.company,
      website: website ?? this.website,
      streetAddress1: streetAddress1 ?? this.streetAddress1,
      streetAddress2: streetAddress2 ?? this.streetAddress2,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
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
      'email': email,
      'phone': phone,
      'company': company,
      'website': website,
      'streetAddress1': streetAddress1,
      'streetAddress2': streetAddress2,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'country': country,
      'isActive': isActive,
      'isDefault': isDefault,
      'businessId': businessId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: SafeParse.integer(map['id']),
      name: SafeParse.string(map['name']),
      description: SafeParse.string(map['description']),
      email: SafeParse.string(map['email']),
      phone: SafeParse.string(map['phone']),
      company: SafeParse.string(map['company']),
      website: SafeParse.string(map['website']),
      streetAddress1: SafeParse.string(map['streetAddress1']),
      streetAddress2: SafeParse.string(map['streetAddress2']),
      city: SafeParse.string(map['city']),
      state: SafeParse.string(map['state']),
      postalCode: SafeParse.string(map['postalCode']),
      country: SafeParse.string(map['country']),
      isActive: SafeParse.boolean(map['isActive']),
      isDefault: SafeParse.boolean(map['isDefault']),
      businessId: SafeParse.integer(map['businessId']),
      createdAt: SafeParse.dateTime(map['createdAt']),
      updatedAt: SafeParse.dateTime(map['updatedAt']),
    );
  }

  @override
  String toString() {
    return 'Client(id: $id, name: $name, description: $description, email: $email, phone: $phone, company: $company, website: $website, streetAddress1: $streetAddress1, streetAddress2: $streetAddress2, city: $city, state: $state, postalCode: $postalCode, country: $country, isActive: $isActive, isDefault: $isDefault, businessId: $businessId, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
