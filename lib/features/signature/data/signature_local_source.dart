import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/database/objectbox_database.dart';
import 'package:invois/core/database/objectbox_response.dart';

import '../signature_model.dart';
import '../signature_query_provider.dart';

class SignatureLocalSource {
  final Store _store;
  late final Box<Signature> _signatureBox;

  static final SignatureLocalSource _instance =
      SignatureLocalSource._internal();
  factory SignatureLocalSource() => _instance;

  SignatureLocalSource._internal() : _store = ObjectBoxDatabase.instance {
    _signatureBox = _store.box<Signature>();
  }

  SignatureLocalSource.withDependencies({required Store store})
    : _store = store {
    _signatureBox = _store.box<Signature>();
  }

  // Get all signatures
  Future<List<Signature>> getSignatures() async {
    return _signatureBox.getAll();
  }

  /// Reactive, filtered signature stream (ADR-0003). Emits on every matching write.
  Stream<List<Signature>> watchSignatures(SignatureQuery q) {
    Condition<Signature>? condition;
    final search = q.search;
    if (search != null && search.isNotEmpty) {
      condition = Signature_.name.contains(search, caseSensitive: false);
    }
    if (q.isActive != null) {
      final c = Signature_.isActive.equals(q.isActive!);
      condition = condition == null ? c : condition.and(c);
    }
    if (q.isDefault != null) {
      final c = Signature_.isDefault.equals(q.isDefault!);
      condition = condition == null ? c : condition.and(c);
    }
    final builder = condition == null
        ? _signatureBox.query()
        : _signatureBox.query(condition);
    builder.order(Signature_.name);
    return builder.watch(triggerImmediately: true).map((query) => query.find());
  }

  // Get signature by ID
  Future<Signature?> getSignatureById(int id) async {
    return _signatureBox.get(id);
  }

  // Helper to unset isDefault for all other signatures with the same businessId (or null for general)
  Future<void> unsetDefaultSignaturesExcept({
    int? businessId,
    int? exceptId,
  }) async {
    final queryBuilder = _signatureBox.query(
      Signature_.isDefault.equals(true) &
          ((businessId == null)
              ? Signature_.businessId.isNull()
              : Signature_.businessId.equals(businessId)),
    );
    final defaults = queryBuilder.build().find();
    for (final sig in defaults) {
      if (sig.id != exceptId) {
        await updateSignatureFields(sig.id!, isDefault: false);
      }
    }
  }

  // Insert signature
  Future<ObjectBoxResponse<Signature>> insertSignature(
    Signature signature,
  ) async {
    try {
      if (signature.isDefault) {
        await unsetDefaultSignaturesExcept(
          businessId: signature.businessId,
          exceptId: null,
        );
      }
      final result = _signatureBox.put(signature);
      if (result > 0) {
        return ObjectBoxResponse.success(signature);
      } else {
        return ObjectBoxResponse.failure(message: 'Failed to insert signature');
      }
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  // Update signature
  Future<ObjectBoxResponse<Signature>> updateSignature(
    Signature signature,
  ) async {
    try {
      if (signature.isDefault) {
        await unsetDefaultSignaturesExcept(
          businessId: signature.businessId,
          exceptId: signature.id,
        );
      }
      final result = _signatureBox.put(signature);
      if (result > 0) {
        return ObjectBoxResponse.success(signature);
      } else {
        return ObjectBoxResponse.failure(message: 'Failed to update signature');
      }
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  // Delete signature
  Future<bool> deleteSignatureById(int id) async {
    return _signatureBox.remove(id);
  }

  // Delete signature by businessId
  Future<void> deleteSignatureByBusinessId(int businessId) async {
    final queryBuilder = _signatureBox.query(
      Signature_.businessId.equals(businessId),
    );
    final signatures = queryBuilder.build().find();
    for (final signature in signatures) {
      await deleteSignatureById(signature.id!);
    }
  }

  // Delete multiple signatures
  Future<int> deleteSignatures(List<int> ids) async {
    int deletedCount = 0;
    for (int id in ids) {
      if (_signatureBox.remove(id)) {
        deletedCount++;
      }
    }
    return deletedCount;
  }

  // Search signatures by name
  Future<List<Signature>> searchSignaturesByName(String query) async {
    final queryBuilder = _signatureBox.query(
      Signature_.name.contains(query, caseSensitive: false),
    );
    final result = queryBuilder.build().find();
    return result;
  }

  // Search signatures (combined search)
  Future<List<Signature>> searchSignatures(
    String query, {
    bool? isDefault,
    bool? isActive,
  }) async {
    var condition = Signature_.name.contains(query, caseSensitive: false);
    if (isDefault != null) {
      condition = condition & Signature_.isDefault.equals(isDefault);
    }
    if (isActive != null) {
      condition = condition & Signature_.isActive.equals(isActive);
    }
    final builder = _signatureBox.query(condition);
    final result = builder.build().find();
    return result;
  }

  // Get active signatures
  Future<List<Signature>> getActiveSignatures() async {
    final queryBuilder = _signatureBox.query(Signature_.isActive.equals(true));
    final result = queryBuilder.build().find();
    return result;
  }

  // Get inactive signatures
  Future<List<Signature>> getInactiveSignatures() async {
    final queryBuilder = _signatureBox.query(Signature_.isActive.equals(false));
    final result = queryBuilder.build().find();
    return result;
  }

  // Get default signatures
  Future<List<Signature>> getDefaultSignatures() async {
    final queryBuilder = _signatureBox.query(Signature_.isDefault.equals(true));
    final result = queryBuilder.build().find();
    return result;
  }

  // Get default signatures by businessId (or general if null)
  Future<List<Signature>> getDefaultSignaturesByBusinessId(
    int? businessId,
  ) async {
    final queryBuilder = _signatureBox.query(
      Signature_.isDefault.equals(true) &
          ((businessId == null)
              ? Signature_.businessId.isNull()
              : Signature_.businessId.equals(businessId)),
    );
    return queryBuilder.build().find();
  }

  // Count total signatures
  Future<int> countSignatures() async {
    return _signatureBox.count();
  }

  // Update signature fields
  Future<bool> updateSignatureFields(
    int id, {
    String? name,
    String? title,
    String? signatureData,
    String? email,
    String? phone,
    String? company,
    String? website,
    String? notes,
    int? businessId,
    bool? isActive,
    bool? isDefault,
    DateTime? updatedAt,
  }) async {
    final business = _signatureBox.get(id);
    if (business == null) return false;

    final updatedBusiness = business.copyWith(
      name: name,
      title: title,
      signatureData: signatureData,
      email: email,
      phone: phone,
      company: company,
      website: website,
      notes: notes,
      businessId: businessId,
      isActive: isActive,
      isDefault: isDefault,
      updatedAt: updatedAt,
    );

    final result = _signatureBox.put(updatedBusiness);
    return result > 0;
  }

  // Expose signature box for repository advanced queries
  // Box<Signature> get signatureBox => _signatureBox;
}
