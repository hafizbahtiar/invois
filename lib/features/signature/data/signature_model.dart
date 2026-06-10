import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:objectbox/objectbox.dart';
import '../../../../core/utils/safe_parse.dart';
import '../../../../core/utils/date_utils.dart';

@Entity()
// ignore: must_be_immutable
class Signature extends Equatable {
  @Id()
  int? id;

  final String name;
  final String? title;

  /// Vector drawing points (JSON), kept for re-editing the signature.
  final String? signatureData;

  /// Canonical render-ready PNG bytes embedded directly into PDFs (ADR-0004).
  /// Null for legacy rows captured before the PNG migration — those fall back to rendering
  /// [signatureData] points at PDF time.
  @Property(type: PropertyType.byteVector)
  final Uint8List? imageBytes;

  // Contact fields, not identity fields: intentionally NOT unique. Multiple
  // signatures (across or within businesses) may share an email/phone.
  // (Step 3B — removed the former global `@Unique` constraint.)
  final String? email;

  final String? phone;
  final String? company;
  final String? website;
  final String? notes;
  final bool isActive;
  final bool isDefault;
  final int? businessId;

  @Property(type: PropertyType.date)
  final DateTime? createdAt;

  @Property(type: PropertyType.date)
  final DateTime? updatedAt;

  Signature({
    this.id = 0,
    required this.name,
    this.title,
    this.signatureData,
    this.imageBytes,
    this.email,
    this.phone,
    this.company,
    this.website,
    this.notes,
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
    title,
    signatureData,
    imageBytes,
    email,
    phone,
    company,
    website,
    notes,
    isActive,
    isDefault,
    businessId,
    createdAt,
    updatedAt,
  ];

  String get formattedCreatedAt =>
      createdAt != null ? DateUtils.formatReadable(createdAt!) : '';
  String get formattedUpdatedAt =>
      updatedAt != null ? DateUtils.formatReadable(updatedAt!) : '';

  Signature copyWith({
    int? id,
    String? name,
    String? title,
    String? signatureData,
    Uint8List? imageBytes,
    String? email,
    String? phone,
    String? company,
    String? website,
    String? notes,
    bool? isActive,
    bool? isDefault,
    int? businessId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Signature(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      signatureData: signatureData ?? this.signatureData,
      imageBytes: imageBytes ?? this.imageBytes,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      company: company ?? this.company,
      website: website ?? this.website,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
      businessId: businessId ?? this.businessId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'title': title,
      'signatureData': signatureData,
      'imageBytes': imageBytes == null ? null : base64Encode(imageBytes!),
      'email': email,
      'phone': phone,
      'company': company,
      'website': website,
      'notes': notes,
      'isActive': isActive,
      'isDefault': isDefault,
      'businessId': businessId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Signature.fromJson(Map<String, dynamic> json) {
    return Signature(
      id: SafeParse.integer(json['id']),
      name: SafeParse.string(json['name']),
      title: SafeParse.string(json['title']),
      signatureData: SafeParse.string(json['signatureData']),
      imageBytes: json['imageBytes'] == null
          ? null
          : base64Decode(json['imageBytes'] as String),
      email: SafeParse.string(json['email']),
      phone: SafeParse.string(json['phone']),
      company: SafeParse.string(json['company']),
      website: SafeParse.string(json['website']),
      notes: SafeParse.string(json['notes']),
      isActive: SafeParse.boolean(json['isActive'], fallback: true),
      isDefault: SafeParse.boolean(json['isDefault'], fallback: false),
      businessId: SafeParse.integer(json['businessId']),
      createdAt: SafeParse.dateTime(json['createdAt']),
      updatedAt: SafeParse.dateTime(json['updatedAt']),
    );
  }
}
