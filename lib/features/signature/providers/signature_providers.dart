import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/signature_model.dart';
import '../data/signature_query.dart';
import '../data/signature_repository.dart';

/// Reactive signature list (ADR-0003), parameterized by [SignatureQuery].
///
/// - List page: `ref.watch(signatureListProvider(ref.watch(signatureQueryProvider)))`.
/// - Invoice form: `ref.watch(signatureListProvider(const SignatureQuery(isActive: true)))`.
final signatureListProvider = StreamProvider.autoDispose
    .family<List<Signature>, SignatureQuery>((ref, query) {
      return ref.watch(signatureRepositoryProvider).watchSignatures(query);
    });
