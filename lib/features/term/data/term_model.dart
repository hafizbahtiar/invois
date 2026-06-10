import 'package:equatable/equatable.dart';
import 'package:invois/core/utils/safe_parse.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
// ignore: must_be_immutable
class Term extends Equatable {
  @Id()
  int? id;

  final String name;
  final String content;
  final String? description;
  final bool isActive;
  final bool isDefault;
  final int? businessId;

  // Invoice relationship
  final ToOne<Invoice> invoice = ToOne<Invoice>();

  @Property(type: PropertyType.date)
  final DateTime? createdAt;

  @Property(type: PropertyType.date)
  final DateTime? updatedAt;

  Term({
    this.id = 0,
    required this.name,
    required this.content,
    this.description,
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
    content,
    isActive,
    isDefault,
    businessId,
    createdAt,
    updatedAt,
  ];

  Term copyWith({
    int? id,
    String? name,
    String? description,
    String? content,
    bool? isActive,
    bool? isDefault,
    int? businessId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Term(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      content: content ?? this.content,
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
      'content': content,
      'description': description,
      'isActive': isActive,
      'isDefault': isDefault,
      'businessId': businessId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Term.fromMap(Map<String, dynamic> map) {
    return Term(
      id: SafeParse.integer(map['id']),
      name: map['name'] ?? '',
      content: map['content'] ?? '',
      description: map['description'],
      isActive: SafeParse.boolean(map['isActive']),
      isDefault: SafeParse.boolean(map['isDefault']),
      businessId: SafeParse.integer(map['businessId']),
      createdAt: SafeParse.dateTime(map['createdAt']),
      updatedAt: SafeParse.dateTime(map['updatedAt']),
    );
  }

  @override
  String toString() {
    return 'Term(id: $id, name: $name, description: $description, content: $content, isActive: $isActive, isDefault: $isDefault, businessId: $businessId, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
