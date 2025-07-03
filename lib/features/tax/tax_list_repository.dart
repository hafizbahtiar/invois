import 'package:invois/core/database/objectbox_response.dart';

import 'tax_local_source.dart';
import 'tax_model.dart';

class TaxListRepository {
  final TaxLocalSource _localSource;

  // Singleton pattern
  static final TaxListRepository _instance =
      TaxListRepository._internal();
  factory TaxListRepository() => _instance;

  TaxListRepository._internal() : _localSource = TaxLocalSource();

  // Constructor for dependency injection (useful for testing)
  TaxListRepository.withDependencies({
    required TaxLocalSource localService,
  }) : _localSource = localService;

  Future<ObjectBoxResponse<List<Tax>>> getTaxes() async {
    try {
      final result = await _localSource.getTaxes();
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Tax>>> searchTaxes(
    String query, {
    bool? isDefault,
    bool? isActive,
  }) async {
    try {
      final result = await _localSource.searchTaxes(
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

  Future<ObjectBoxResponse<List<Tax>>> searchTaxesByName(
    String query,
  ) async {
    try {
      final result = await _localSource.searchTaxesByName(query);
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Tax>>> getActiveTaxes() async {
    try {
      final result = await _localSource.getActiveTaxes();
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Tax>>> getInactiveTaxes() async {
    try {
      final result = await _localSource.getInactiveTaxes();
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Tax>>> getDefaultTaxes() async {
    try {
      final result = await _localSource.getDefaultTaxes();
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<int> countTaxes() async {
    return await _localSource.countTaxes();
  }
}
