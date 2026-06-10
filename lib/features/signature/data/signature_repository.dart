import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/result/failure_mapper.dart';
import 'package:invois/core/providers/objectbox_providers.dart';
import 'package:invois/core/result/app_failure.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/core/utils/string_utils.dart';

import 'signature_local_source.dart';
import 'signature_model.dart';
import 'signature_query.dart';

final signatureLocalSourceProvider = Provider<SignatureLocalSource>(
  (ref) =>
      SignatureLocalSource.withDependencies(store: ref.watch(storeProvider)),
);

final signatureRepositoryProvider = Provider<SignatureRepository>(
  (ref) => SignatureRepository(ref.watch(signatureLocalSourceProvider)),
);

/// Single signature repository (ADR-0002). Replaces SignatureListRepository +
/// SignatureFormRepository.
///
/// The signature *data pipeline* (legacy points JSON vs rendered PNG) lives in
/// the model/service layer, not here.
class SignatureRepository {
  final SignatureLocalSource _local;

  SignatureRepository(this._local);

  Stream<List<Signature>> watchSignatures(SignatureQuery query) => _local
      .watchSignatures(query)
      .handleError((Object e) => throw mapException(e));

  Future<Signature?> getSignatureById(int id) => _local.getSignatureById(id);

  Future<Signature?> getDefaultActiveSignatureByBusinessId(int? businessId) =>
      _local.getDefaultActiveSignatureByBusinessId(businessId);

  Future<Result<Signature>> create(Signature signature) async {
    try {
      final r = await _local.insertSignature(_normalizeContact(signature));
      final data = r.data;
      return (r.success && data != null)
          ? Ok(data)
          : Err(DatabaseFailure(r.message ?? 'Failed to insert signature'));
    } catch (e) {
      return Err(mapException(e));
    }
  }

  Future<Result<Signature>> update(Signature signature) async {
    try {
      final r = await _local.updateSignature(_normalizeContact(signature));
      final data = r.data;
      return (r.success && data != null)
          ? Ok(data)
          : Err(DatabaseFailure(r.message ?? 'Failed to update signature'));
    } catch (e) {
      return Err(mapException(e));
    }
  }

  /// Trim contact fields and store blanks as null, so callers that bypass the
  /// form can't persist empty/whitespace email/phone. Returns the input
  /// unchanged when nothing needs normalising. (`copyWith` can't set null, so a
  /// normalised instance is constructed when needed.)
  Signature _normalizeContact(Signature signature) {
    final email = StringUtils.nullIfBlank(signature.email);
    final phone = StringUtils.nullIfBlank(signature.phone);
    if (email == signature.email && phone == signature.phone) return signature;
    return Signature(
      id: signature.id,
      name: signature.name,
      title: signature.title,
      signatureData: signature.signatureData,
      imageBytes: signature.imageBytes,
      email: email,
      phone: phone,
      company: signature.company,
      website: signature.website,
      notes: signature.notes,
      isActive: signature.isActive,
      isDefault: signature.isDefault,
      businessId: signature.businessId,
      createdAt: signature.createdAt,
      updatedAt: signature.updatedAt,
    );
  }

  Future<Result<void>> delete(int id) async {
    try {
      await _local.deleteSignatureById(id);
      return const Ok(null);
    } catch (e) {
      return Err(mapException(e));
    }
  }
}
