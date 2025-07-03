import 'package:invois/core/database/objectbox_response.dart';
import 'signature_local_source.dart';
import 'signature_model.dart';

class SignatureFormRepository {
  final SignatureLocalSource _localSource;

  // Singleton pattern
  static final SignatureFormRepository _instance =
      SignatureFormRepository._internal();
  factory SignatureFormRepository() => _instance;

  SignatureFormRepository._internal() : _localSource = SignatureLocalSource();

  // Constructor for dependency injection (useful for testing)
  SignatureFormRepository.withDependencies({
    required SignatureLocalSource localService,
  }) : _localSource = localService;

  Future<List<Signature>> getSignatures() async {
    return await _localSource.getSignatures();
  }

  Future<Signature?> getSignatureById(int id) async {
    return await _localSource.getSignatureById(id);
  }

  Future<ObjectBoxResponse<Signature>> insertSignature(
    Signature signature,
  ) async {
    // Set creation timestamp
    final signatureWithTimestamp = signature.copyWith(
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return await _localSource.insertSignature(signatureWithTimestamp);
  }

  Future<ObjectBoxResponse<Signature>> updateSignature(
    Signature signature,
  ) async {
    // Set update timestamp
    final signatureWithTimestamp = signature.copyWith(
      updatedAt: DateTime.now(),
    );
    return await _localSource.updateSignature(signatureWithTimestamp);
  }

  Future<bool> deleteSignature(int id) async {
    return await _localSource.deleteSignatureById(id);
  }

  Future<int> deleteBusinesses(List<int> ids) async {
    int deletedCount = 0;
    for (int id in ids) {
      if (await deleteSignature(id)) {
        deletedCount++;
      }
    }
    return deletedCount;
  }

  Future<List<Signature>> searchSignaturesByName(String query) async {
    return await _localSource.searchSignaturesByName(query);
  }

  Future<List<Signature>> getActiveSignatures() async {
    return await _localSource.getActiveSignatures();
  }

  Future<List<Signature>> getInactiveSignatures() async {
    return await _localSource.getInactiveSignatures();
  }

  Future<int> countSignatures() async {
    return await _localSource.countSignatures();
  }

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
    return await _localSource.updateSignatureFields(
      id,
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
  }
}
