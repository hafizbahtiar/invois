import 'package:invois/core/database/objectbox_response.dart';

import 'business_local_source.dart';
import 'business_model.dart';

class BusinessListRepository {
  final BusinessLocalSource _localSource;

  // Singleton pattern
  static final BusinessListRepository _instance =
      BusinessListRepository._internal();
  factory BusinessListRepository() => _instance;

  BusinessListRepository._internal() : _localSource = BusinessLocalSource();

  // Constructor for dependency injection (useful for testing)
  BusinessListRepository.withDependencies({
    required BusinessLocalSource localService,
  }) : _localSource = localService;

  Future<ObjectBoxResponse<List<Business>>> getAllBusinesses() async {
    try {
      final result = await _localSource.getAllBusinesses();
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<Business>> getBusinessById(int id) async {
    try {
      final result = await _localSource.getBusinessById(id);
      if (result == null) {
        return ObjectBoxResponse.failure(message: 'Business not found');
      }
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Business>>> searchBusinesses(
    String query, {
    bool? isDefault,
    bool? isActive,
  }) async {
    try {
      final result = await _localSource.searchBusinesses(
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

  Future<ObjectBoxResponse<List<Business>>> searchBusinessesByName(
    String query,
  ) async {
    try {
      final result = await _localSource.searchBusinessesByName(query);
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Business>>> getActiveBusinesses() async {
    try {
      final result = await _localSource.getActiveBusinesses();
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Business>>> getInactiveBusinesses() async {
    try {
      final result = await _localSource.getInactiveBusinesses();
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Business>>> getDefaultBusiness() async {
    try {
      final result = await _localSource.getDefaultBusiness();
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<int> countBusinesses() async {
    return await _localSource.countBusinesses();
  }
}
