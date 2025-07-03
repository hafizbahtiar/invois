import 'package:invois/core/utils/safe_parse.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class Business {
  @Id()
  int? id;

  @Unique()
  final String name;

  final String? description;

  @Unique()
  final String? phone;

  @Unique()
  final String? email;

  final String? website;

  final String? streetAddress1;
  final String? streetAddress2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;

  final bool isDefault;
  final bool isActive;

  @Property(type: PropertyType.date)
  DateTime? createdAt;

  @Property(type: PropertyType.date)
  DateTime? updatedAt;

  Business({
    this.id = 0,
    required this.name,
    this.description,
    this.phone,
    this.email,
    this.website,
    this.streetAddress1,
    this.streetAddress2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.isDefault = false,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  Business copyWith({
    int? id,
    String? name,
    String? description,
    String? phone,
    String? email,
    String? website,
    String? streetAddress1,
    String? streetAddress2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    bool? isDefault,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Business(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      streetAddress1: streetAddress1 ?? this.streetAddress1,
      streetAddress2: streetAddress2 ?? this.streetAddress2,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Business.fromJson(Map<String, dynamic> json) {
    return Business(
      id: SafeParse.integer(json['id']),
      name: SafeParse.string(json['name']),
      description: SafeParse.string(json['description']),
      phone: SafeParse.string(json['phone']),
      email: SafeParse.string(json['email']),
      website: SafeParse.string(json['website']),
      streetAddress1: SafeParse.string(json['streetAddress1']),
      streetAddress2: SafeParse.string(json['streetAddress2']),
      city: SafeParse.string(json['city']),
      state: SafeParse.string(json['state']),
      postalCode: SafeParse.string(json['postalCode']),
      country: SafeParse.string(json['country']),
      isDefault: SafeParse.boolean(json['isDefault'], fallback: false),
      isActive: SafeParse.boolean(json['isActive'], fallback: true),
      createdAt: SafeParse.dateTime(json['createdAt']),
      updatedAt: SafeParse.dateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'phone': phone,
      'email': email,
      'website': website,
      'streetAddress1': streetAddress1,
      'streetAddress2': streetAddress2,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'country': country,
      'isDefault': isDefault,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
