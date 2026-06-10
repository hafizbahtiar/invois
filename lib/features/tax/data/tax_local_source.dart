import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/database/objectbox_database.dart';
import 'package:invois/core/database/objectbox_response.dart';

import 'tax_model.dart';
import 'tax_query.dart';

class TaxLocalSource {
  final Store _store;
  late final Box<Tax> _taxBox;

  static final TaxLocalSource _instance = TaxLocalSource._internal();
  factory TaxLocalSource() => _instance;

  TaxLocalSource._internal() : _store = ObjectBoxDatabase.instance {
    _taxBox = _store.box<Tax>();
  }

  TaxLocalSource.withDependencies({required Store store}) : _store = store {
    _taxBox = _store.box<Tax>();
  }

  // Get all taxes
  Future<List<Tax>> getTaxes() async {
    return _taxBox.getAll();
  }

  /// Reactive, filtered tax stream (ADR-0003). Emits on every matching write.
  Stream<List<Tax>> watchTaxes(TaxQuery q) {
    Condition<Tax>? condition;
    final search = q.search;
    if (search != null && search.isNotEmpty) {
      condition = Tax_.name.contains(search, caseSensitive: false);
    }
    if (q.isActive != null) {
      final c = Tax_.isActive.equals(q.isActive!);
      condition = condition == null ? c : condition.and(c);
    }
    if (q.isDefault != null) {
      final c = Tax_.isDefault.equals(q.isDefault!);
      condition = condition == null ? c : condition.and(c);
    }
    final builder = condition == null
        ? _taxBox.query()
        : _taxBox.query(condition);
    builder.order(Tax_.name);
    return builder.watch(triggerImmediately: true).map((query) => query.find());
  }

  // Get tax by ID
  Future<Tax?> getTaxById(int id) async {
    return _taxBox.get(id);
  }

  // Helper to unset isDefault for all other taxes with the same businessId (or null for general)
  Future<void> unsetDefaultTaxesExcept({int? businessId, int? exceptId}) async {
    final queryBuilder = _taxBox.query(
      Tax_.isDefault.equals(true) &
          ((businessId == null)
              ? Tax_.businessId.isNull()
              : Tax_.businessId.equals(businessId)),
    );
    final defaults = queryBuilder.build().find();
    for (final tax in defaults) {
      if (tax.id != exceptId) {
        await updateTaxFields(tax.id!, isDefault: false);
      }
    }
  }

  // Insert tax
  Future<ObjectBoxResponse<Tax>> insertTax(Tax tax) async {
    try {
      if (tax.isDefault) {
        await unsetDefaultTaxesExcept(
          businessId: tax.businessId,
          exceptId: null,
        );
      }
      final result = _taxBox.put(tax);
      if (result > 0) {
        return ObjectBoxResponse.success(tax);
      } else {
        return ObjectBoxResponse.failure(message: 'Failed to insert tax');
      }
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  // Update tax
  Future<ObjectBoxResponse<Tax>> updateTax(Tax tax) async {
    try {
      if (tax.isDefault) {
        await unsetDefaultTaxesExcept(
          businessId: tax.businessId,
          exceptId: tax.id,
        );
      }
      final result = _taxBox.put(tax);
      if (result > 0) {
        return ObjectBoxResponse.success(tax);
      } else {
        return ObjectBoxResponse.failure(message: 'Failed to update tax');
      }
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  // Delete tax
  Future<bool> deleteTaxById(int id) async {
    return _taxBox.remove(id);
  }

  // Delete tax by businessId
  Future<void> deleteTaxByBusinessId(int businessId) async {
    final queryBuilder = _taxBox.query(Tax_.businessId.equals(businessId));
    final taxes = queryBuilder.build().find();
    for (final tax in taxes) {
      await deleteTaxById(tax.id!);
    }
  }

  // Delete multiple taxes
  Future<int> deleteTaxes(List<int> ids) async {
    int deletedCount = 0;
    for (int id in ids) {
      if (_taxBox.remove(id)) {
        deletedCount++;
      }
    }
    return deletedCount;
  }

  // Search taxes by name
  Future<List<Tax>> searchTaxesByName(String query) async {
    final queryBuilder = _taxBox.query(
      Tax_.name.contains(query, caseSensitive: false),
    );
    final result = queryBuilder.build().find();
    return result;
  }

  // Search taxes (combined search)
  Future<List<Tax>> searchTaxes(
    String query, {
    bool? isDefault,
    bool? isActive,
  }) async {
    var condition = Tax_.name.contains(query, caseSensitive: false);
    if (isDefault != null) {
      condition = condition & Tax_.isDefault.equals(isDefault);
    }
    if (isActive != null) {
      condition = condition & Tax_.isActive.equals(isActive);
    }
    final builder = _taxBox.query(condition);
    final result = builder.build().find();
    return result;
  }

  // Get active taxes
  Future<List<Tax>> getActiveTaxes() async {
    final queryBuilder = _taxBox.query(Tax_.isActive.equals(true));
    final result = queryBuilder.build().find();
    return result;
  }

  // Get inactive taxes
  Future<List<Tax>> getInactiveTaxes() async {
    final queryBuilder = _taxBox.query(Tax_.isActive.equals(false));
    final result = queryBuilder.build().find();
    return result;
  }

  // Get default taxes
  Future<List<Tax>> getDefaultTaxes() async {
    final queryBuilder = _taxBox.query(Tax_.isDefault.equals(true));
    final result = queryBuilder.build().find();
    return result;
  }

  // Get default taxes by businessId (or general if null)
  Future<List<Tax>> getDefaultTaxesByBusinessId(int? businessId) async {
    final queryBuilder = _taxBox.query(
      Tax_.isDefault.equals(true) &
          ((businessId == null)
              ? Tax_.businessId.isNull()
              : Tax_.businessId.equals(businessId)),
    );
    return queryBuilder.build().find();
  }

  // Count total taxes
  Future<int> countTaxes() async {
    return _taxBox.count();
  }

  // Update tax fields
  Future<bool> updateTaxFields(
    int id, {
    String? name,
    String? description,
    String? taxType,
    double? rate,
    int? businessId,
    bool? isActive,
    bool? isDefault,
    DateTime? updatedAt,
  }) async {
    final tax = _taxBox.get(id);
    if (tax == null) return false;

    final updatedTax = tax.copyWith(
      name: name,
      description: description,
      taxType: taxType,
      rate: rate,
      businessId: businessId,
      isActive: isActive,
      isDefault: isDefault,
      updatedAt: updatedAt,
    );

    final result = _taxBox.put(updatedTax);
    return result > 0;
  }

  // Expose tax box for repository advanced queries
  // Box<Tax> get taxBox => _taxBox;
}
