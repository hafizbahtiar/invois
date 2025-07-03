import 'package:invois/core/database/objectbox_response.dart';
import 'term_local_source.dart';
import 'term_model.dart';

class TermFormRepository {
  final TermLocalSource _localSource;

  // Singleton pattern
  static final TermFormRepository _instance = TermFormRepository._internal();
  factory TermFormRepository() => _instance;

  TermFormRepository._internal() : _localSource = TermLocalSource();

  // Constructor for dependency injection (useful for testing)
  TermFormRepository.withDependencies({required TermLocalSource localService})
    : _localSource = localService;

  Future<List<Term>> getTerms() async {
    return await _localSource.getTerms();
  }

  Future<Term?> getTermById(int id) async {
    return await _localSource.getTermById(id);
  }

  Future<ObjectBoxResponse<Term>> insertTerm(Term term) async {
    // Set creation timestamp
    final termWithTimestamp = term.copyWith(
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return await _localSource.insertTerm(termWithTimestamp);
  }

  Future<ObjectBoxResponse<Term>> updateTerm(Term term) async {
    // Set update timestamp
    final termWithTimestamp = term.copyWith(updatedAt: DateTime.now());
    return await _localSource.updateTerm(termWithTimestamp);
  }

  Future<bool> deleteTerm(int id) async {
    return await _localSource.deleteTermById(id);
  }

  Future<int> deleteTaxes(List<int> ids) async {
    int deletedCount = 0;
    for (int id in ids) {
      if (await deleteTerm(id)) {
        deletedCount++;
      }
    }
    return deletedCount;
  }

  Future<List<Term>> searchTermsByName(String query) async {
    return await _localSource.searchTermsByName(query);
  }

  Future<List<Term>> getActiveTerms() async {
    return await _localSource.getActiveTerms();
  }

  Future<List<Term>> getInactiveTerms() async {
    return await _localSource.getInactiveTerms();
  }

  Future<int> countTerms() async {
    return await _localSource.countTerms();
  }

  Future<bool> updateTaxFields(
    int id, {
    String? name,
    String? content,
    String? description,
    bool? isActive,
    bool? isDefault,
    DateTime? updatedAt,
  }) async {
    return await _localSource.updateTaxFields(
      id,
      name: name,
      content: content,
      description: description,
      isActive: isActive,
      isDefault: isDefault,
      updatedAt: updatedAt,
    );
  }
}
