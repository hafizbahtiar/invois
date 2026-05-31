import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/database/objectbox_database.dart';
import 'package:invois/core/database/objectbox_response.dart';

import 'business_model.dart';
import 'business_query_provider.dart';

class BusinessLocalSource {
  final Store _store;
  late final Box<Business> _businessBox;

  static final BusinessLocalSource _instance = BusinessLocalSource._internal();
  factory BusinessLocalSource() => _instance;

  BusinessLocalSource._internal() : _store = ObjectBoxDatabase.instance {
    _businessBox = _store.box<Business>();
  }

  BusinessLocalSource.withDependencies({required Store store})
    : _store = store {
    _businessBox = _store.box<Business>();
  }

  // Get all businesses
  Future<List<Business>> getAllBusinesses() async {
    return _businessBox.getAll();
  }

  /// Reactive, filtered business stream (ADR-0003). Emits on every matching write.
  Stream<List<Business>> watchBusinesses(BusinessQuery q) {
    Condition<Business>? condition;
    final search = q.search;
    if (search != null && search.isNotEmpty) {
      condition = Business_.name.contains(search, caseSensitive: false);
    }
    if (q.isActive != null) {
      final c = Business_.isActive.equals(q.isActive!);
      condition = condition == null ? c : condition.and(c);
    }
    if (q.isDefault != null) {
      final c = Business_.isDefault.equals(q.isDefault!);
      condition = condition == null ? c : condition.and(c);
    }
    final builder = condition == null
        ? _businessBox.query()
        : _businessBox.query(condition);
    builder.order(Business_.name);
    return builder.watch(triggerImmediately: true).map((query) => query.find());
  }

  // Get business by ID
  Future<Business?> getBusinessById(int id) async {
    return _businessBox.get(id);
  }

  // Helper to unset isDefault for all other businesses except the one being set
  Future<void> unsetDefaultBusinessesExcept({int? exceptId}) async {
    final queryBuilder = _businessBox.query(Business_.isDefault.equals(true));
    final defaults = queryBuilder.build().find();
    for (final b in defaults) {
      if (b.id != exceptId) {
        await updateBusinessFields(b.id!, isDefault: false);
      }
    }
  }

  // Insert business
  Future<ObjectBoxResponse<Business>> insertBusiness(Business business) async {
    try {
      if (business.isDefault) {
        await unsetDefaultBusinessesExcept(exceptId: null);
      }
      final result = _businessBox.put(business);
      if (result > 0) {
        return ObjectBoxResponse.success(business);
      } else {
        return ObjectBoxResponse.failure(message: 'Failed to insert business');
      }
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  // Update business
  Future<ObjectBoxResponse<Business>> updateBusiness(Business business) async {
    try {
      if (business.isDefault) {
        await unsetDefaultBusinessesExcept(exceptId: business.id);
      }
      final result = _businessBox.put(business);
      if (result > 0) {
        return ObjectBoxResponse.success(business);
      } else {
        return ObjectBoxResponse.failure(message: 'Failed to update business');
      }
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  // Delete business
  Future<bool> deleteBusinessById(int id) async {
    return _businessBox.remove(id);
  }

  // Delete multiple businesses
  Future<int> deleteBusinesses(List<int> ids) async {
    int deletedCount = 0;
    for (int id in ids) {
      if (_businessBox.remove(id)) {
        deletedCount++;
      }
    }
    return deletedCount;
  }

  // Search businesses by name
  Future<List<Business>> searchBusinessesByName(String query) async {
    final queryBuilder = _businessBox.query(
      Business_.name.contains(query, caseSensitive: false),
    );
    final result = queryBuilder.build().find();
    return result;
  }

  // Search businesses (combined search)
  Future<List<Business>> searchBusinesses(
    String query, {
    bool? isDefault,
    bool? isActive,
  }) async {
    var condition = Business_.name.contains(query, caseSensitive: false);
    if (isDefault != null) {
      condition = condition & Business_.isDefault.equals(isDefault);
    }
    if (isActive != null) {
      condition = condition & Business_.isActive.equals(isActive);
    }
    final builder = _businessBox.query(condition);
    final result = builder.build().find();
    return result;
  }

  // Get active businesses
  Future<List<Business>> getActiveBusinesses() async {
    final queryBuilder = _businessBox.query(Business_.isActive.equals(true));
    final result = queryBuilder.build().find();
    return result;
  }

  // Get inactive businesses
  Future<List<Business>> getInactiveBusinesses() async {
    final queryBuilder = _businessBox.query(Business_.isActive.equals(false));
    final result = queryBuilder.build().find();
    return result;
  }

  // Get default businesses
  Future<List<Business>> getDefaultBusiness() async {
    final queryBuilder = _businessBox.query(Business_.isDefault.equals(true));
    final result = queryBuilder.build().find();
    return result;
  }

  // Count total businesses
  Future<int> countBusinesses() async {
    return _businessBox.count();
  }

  // Update business fields
  Future<bool> updateBusinessFields(
    int id, {
    String? name,
    String? website,
    String? email,
    String? phone,
    String? streetAddress1,
    String? streetAddress2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    bool? isActive,
    bool? isDefault,
    DateTime? updatedAt,
  }) async {
    final business = _businessBox.get(id);
    if (business == null) return false;

    final updatedBusiness = business.copyWith(
      name: name,
      website: website,
      email: email,
      phone: phone,
      streetAddress1: streetAddress1,
      streetAddress2: streetAddress2,
      city: city,
      state: state,
      postalCode: postalCode,
      country: country,
      isActive: isActive,
      isDefault: isDefault,
      updatedAt: updatedAt,
    );

    final result = _businessBox.put(updatedBusiness);
    return result > 0;
  }
}
