import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/features/business/data/business_model.dart';
import 'package:invois/features/business/data/business_repository.dart';
import 'package:invois/features/client/data/client_model.dart';
import 'package:invois/features/client/data/client_repository.dart';
import 'package:invois/features/signature/data/signature_model.dart';
import 'package:invois/features/signature/data/signature_repository.dart';
import 'package:invois/features/tax/data/tax_model.dart';
import 'package:invois/features/term/data/term_model.dart';

import '../data/invoice_model.dart';
import '../data/invoice_query.dart';
import '../data/invoice_repository.dart';

class InvoiceDetailData {
  final Invoice invoice;
  final Business? business;
  final Client? client;
  final Signature? signature;
  final List<Tax> taxes;
  final List<Term> terms;

  const InvoiceDetailData({
    required this.invoice,
    required this.business,
    required this.client,
    required this.signature,
    required this.taxes,
    required this.terms,
  });
}

/// Reactive invoice list (ADR-0003).
///
/// Backed by an ObjectBox `query.watch()` stream, so it re-emits automatically
/// on any matching write — no manual refresh. It rebuilds whenever the active
/// [invoiceQueryProvider] (search/status filter) changes.
///
/// Consumers read this as an `AsyncValue<List<Invoice>>`
/// (`.valueOrNull`, `.isLoading`, `.hasError`).
final invoiceListProvider = StreamProvider.autoDispose<List<Invoice>>((ref) {
  final repo = ref.watch(invoiceRepositoryProvider);
  final query = ref.watch(invoiceQueryProvider);
  return repo.watchInvoices(query);
});

final invoiceDetailProvider = FutureProvider.autoDispose
    .family<InvoiceDetailData, int>((ref, id) async {
      final invoiceRepo = ref.watch(invoiceRepositoryProvider);
      final businessRepo = ref.watch(businessRepositoryProvider);
      final clientRepo = ref.watch(clientRepositoryProvider);
      final signatureRepo = ref.watch(signatureRepositoryProvider);

      final invoice = await invoiceRepo.getCompleteInvoice(id);
      if (invoice == null) {
        throw StateError('Invoice not found');
      }

      Business? business;
      final businessId = invoice.businessId;
      if (businessId != null && businessId > 0) {
        business = await businessRepo.getBusinessById(businessId);
      }

      Client? client;
      final clientId = invoice.clientId;
      if (clientId != null && clientId > 0) {
        client = await clientRepo.getClientById(clientId);
      }

      Signature? signature;
      final signatureId = invoice.signatureId;
      if (signatureId != null && signatureId > 0) {
        signature = await signatureRepo.getSignatureById(signatureId);
      }

      return InvoiceDetailData(
        invoice: invoice,
        business: business,
        client: client,
        signature: signature,
        taxes: invoice.taxes.toList(),
        terms: invoice.terms.toList(),
      );
    });
