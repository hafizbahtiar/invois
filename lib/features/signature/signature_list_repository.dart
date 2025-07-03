import 'package:invois/core/database/objectbox_response.dart';

import 'signature_local_source.dart';
import 'signature_model.dart';

class SignatureListRepository {
  final SignatureLocalSource _localSource;

  // Singleton pattern
  static final SignatureListRepository _instance =
      SignatureListRepository._internal();
  factory SignatureListRepository() => _instance;

  SignatureListRepository._internal() : _localSource = SignatureLocalSource();

  // Constructor for dependency injection (useful for testing)
  SignatureListRepository.withDependencies({
    required SignatureLocalSource localService,
  }) : _localSource = localService;

  Future<ObjectBoxResponse<List<Signature>>> getSignatures() async {
    try {
      final result = await _localSource.getSignatures();
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Signature>>> searchSignatures(
    String query, {
    bool? isDefault,
    bool? isActive,
  }) async {
    try {
      final result = await _localSource.searchSignatures(
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

  Future<ObjectBoxResponse<List<Signature>>> searchSignaturesByName(
    String query,
  ) async {
    try {
      final result = await _localSource.searchSignaturesByName(query);
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Signature>>> getActiveSignatures() async {
    try {
      final result = await _localSource.getActiveSignatures();
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Signature>>> getInactiveSignatures() async {
    try {
      final result = await _localSource.getInactiveSignatures();
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Signature>>> getDefaultSignatures() async {
    try {
      final result = await _localSource.getDefaultSignatures();
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<int> countSignatures() async {
    return await _localSource.countSignatures();
  }
}
