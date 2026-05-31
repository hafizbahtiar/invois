import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/error/failure_mapper.dart';
import 'package:invois/core/providers/objectbox_providers.dart';
import 'package:invois/core/result/app_failure.dart';
import 'package:invois/core/result/result.dart';

import 'signature_local_source.dart';
import 'signature_model.dart';
import 'signature_query_provider.dart';

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
/// Note (S2): this is the repository/reactive/template migration only — the
/// signature *data pipeline* (points JSON vs rendered PNG) is intentionally left
/// unchanged here and addressed in S4.
class SignatureRepository {
  final SignatureLocalSource _local;

  SignatureRepository(this._local);

  Stream<List<Signature>> watchSignatures(SignatureQuery query) => _local
      .watchSignatures(query)
      .handleError((Object e) => throw mapException(e));

  Future<Signature?> getSignatureById(int id) => _local.getSignatureById(id);

  Future<Result<Signature>> create(Signature signature) async {
    try {
      final r = await _local.insertSignature(signature);
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
      final r = await _local.updateSignature(signature);
      final data = r.data;
      return (r.success && data != null)
          ? Ok(data)
          : Err(DatabaseFailure(r.message ?? 'Failed to update signature'));
    } catch (e) {
      return Err(mapException(e));
    }
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
