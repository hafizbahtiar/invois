import 'package:invois/core/database/objectbox_response.dart';

import 'term_local_source.dart';
import 'term_model.dart';

class TermListRepository {
  final TermLocalSource _localSource;

  // Singleton pattern
  static final TermListRepository _instance =
      TermListRepository._internal();
  factory TermListRepository() => _instance;

  TermListRepository._internal() : _localSource = TermLocalSource();

  // Constructor for dependency injection (useful for testing)
  TermListRepository.withDependencies({
    required TermLocalSource localService,
  }) : _localSource = localService;

  Future<ObjectBoxResponse<List<Term>>> getTerms() async {
    try {
      final result = await _localSource.getTerms();
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Term>>> searchTerms(
    String query, {
    bool? isDefault,
    bool? isActive,
  }) async {
    try {
      final result = await _localSource.searchTerms(
        query,
        isDefault: isDefault,
        isActive: isActive,
      );
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Term>>> searchTermsByName(
    String query,
  ) async {
    try {
      final result = await _localSource.searchTermsByName(query);
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Term>>> getActiveTerms() async {
    try {
      final result = await _localSource.getActiveTerms();
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Term>>> getInactiveTerms() async {
    try {
      final result = await _localSource.getInactiveTerms();
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Term>>> getDefaultTerms() async {
    try {
      final result = await _localSource.getDefaultTerms();
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<int> countTerms() async {
    return await _localSource.countTerms();
  }
}
