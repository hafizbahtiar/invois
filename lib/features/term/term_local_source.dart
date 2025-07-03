import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/database/objectbox_database.dart';
import 'package:invois/core/database/objectbox_response.dart';

import 'term_model.dart';

class TermLocalSource {
  final Store _store;
  late final Box<Term> _termBox;

  static final TermLocalSource _instance = TermLocalSource._internal();
  factory TermLocalSource() => _instance;

  TermLocalSource._internal() : _store = ObjectBoxDatabase.instance {
    _termBox = _store.box<Term>();
  }

  TermLocalSource.withDependencies({required Store store}) : _store = store {
    _termBox = _store.box<Term>();
  }

  // Get all terms
  Future<List<Term>> getTerms() async {
    return _termBox.getAll();
  }

  // Get term by ID
  Future<Term?> getTermById(int id) async {
    return _termBox.get(id);
  }

  // Helper to unset isDefault for all other terms with the same businessId (or null for general)
  Future<void> unsetDefaultTermsExcept({int? businessId, int? exceptId}) async {
    final queryBuilder = _termBox.query(
      Term_.isDefault.equals(true) &
          ((businessId == null)
              ? Term_.businessId.isNull()
              : Term_.businessId.equals(businessId)),
    );
    final defaults = queryBuilder.build().find();
    for (final tax in defaults) {
      if (tax.id != exceptId) {
        await updateTaxFields(tax.id!, isDefault: false);
      }
    }
  }

  // Insert tax
  Future<ObjectBoxResponse<Term>> insertTerm(Term term) async {
    try {
      if (term.isDefault) {
        await unsetDefaultTermsExcept(
          businessId: term.businessId,
          exceptId: null,
        );
      }
      final result = _termBox.put(term);
      if (result > 0) {
        return ObjectBoxResponse.success(term);
      } else {
        return ObjectBoxResponse.failure(message: 'Failed to insert term');
      }
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  // Update tax
  Future<ObjectBoxResponse<Term>> updateTerm(Term term) async {
    try {
      if (term.isDefault) {
        await unsetDefaultTermsExcept(
          businessId: term.businessId,
          exceptId: term.id,
        );
      }
      final result = _termBox.put(term);
      if (result > 0) {
        return ObjectBoxResponse.success(term);
      } else {
        return ObjectBoxResponse.failure(message: 'Failed to update term');
      }
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  // Delete term
  Future<bool> deleteTermById(int id) async {
    return _termBox.remove(id);
  }

  // Delete term by businessId
  Future<void> deleteTermByBusinessId(int businessId) async {
    final queryBuilder = _termBox.query(Term_.businessId.equals(businessId));
    final terms = queryBuilder.build().find();
    for (final term in terms) {
      await deleteTermById(term.id!);
    }
  }

  // Delete multiple terms
  Future<int> deleteTerms(List<int> ids) async {
    int deletedCount = 0;
    for (int id in ids) {
      if (_termBox.remove(id)) {
        deletedCount++;
      }
    }
    return deletedCount;
  }

  // Search terms by name
  Future<List<Term>> searchTermsByName(String query) async {
    final queryBuilder = _termBox.query(
      Term_.name.contains(query, caseSensitive: false),
    );
    final result = queryBuilder.build().find();
    return result;
  }

  // Search terms (combined search)
  Future<List<Term>> searchTerms(
    String query, {
    bool? isDefault,
    bool? isActive,
  }) async {
    var condition = Term_.name.contains(query, caseSensitive: false);
    if (isDefault != null) {
      condition = condition & Term_.isDefault.equals(isDefault);
    }
    if (isActive != null) {
      condition = condition & Term_.isActive.equals(isActive);
    }
    final builder = _termBox.query(condition);
    final result = builder.build().find();
    return result;
  }

  // Get active terms
  Future<List<Term>> getActiveTerms() async {
    final queryBuilder = _termBox.query(Term_.isActive.equals(true));
    final result = queryBuilder.build().find();
    return result;
  }

  // Get inactive terms
  Future<List<Term>> getInactiveTerms() async {
    final queryBuilder = _termBox.query(Term_.isActive.equals(false));
    final result = queryBuilder.build().find();
    return result;
  }

  // Get default terms
  Future<List<Term>> getDefaultTerms() async {
    final queryBuilder = _termBox.query(Term_.isDefault.equals(true));
    final result = queryBuilder.build().find();
    return result;
  }

  // Get default terms by businessId (or general if null)
  Future<List<Term>> getDefaultTermsByBusinessId(int? businessId) async {
    final queryBuilder = _termBox.query(
      Term_.isDefault.equals(true) &
          ((businessId == null)
              ? Term_.businessId.isNull()
              : Term_.businessId.equals(businessId)),
    );
    return queryBuilder.build().find();
  }

  // Count total terms
  Future<int> countTerms() async {
    return _termBox.count();
  }

  // Update tax fields
  Future<bool> updateTaxFields(
    int id, {
    String? name,
    String? content,
    String? description,
    int? businessId,
    bool? isActive,
    bool? isDefault,
    DateTime? updatedAt,
  }) async {
    final term = _termBox.get(id);
    if (term == null) return false;

    final updatedTerm = term.copyWith(
      name: name,
      description: description,
      content: content,
      businessId: businessId,
      isActive: isActive,
      isDefault: isDefault,
      updatedAt: updatedAt,
    );

    final result = _termBox.put(updatedTerm);
    return result > 0;
  }

  // Expose tax box for repository advanced queries
  // Box<Tax> get taxBox => _taxBox;
}
