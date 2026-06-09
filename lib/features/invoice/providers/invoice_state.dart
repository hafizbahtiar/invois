import 'package:invois/features/business/business.dart';
import 'package:invois/features/client/data/client_model.dart';
import 'package:invois/features/signature/data/signature_model.dart';
import 'package:invois/features/tax/data/tax_model.dart';
import 'package:invois/features/term/data/term_model.dart';

import '../data/invoice_model.dart';
import '../invoice_form_line.dart';

class InvoiceFormState {
  final Invoice? invoice;
  final Business? business;
  final Client? client;
  final List<Term>? terms;
  final List<Tax>? taxes;

  /// In-memory line drafts carrying the precise decimal quantity
  /// (`quantityMilli`). These are plain Dart values, not ObjectBox entities.
  final List<InvoiceFormLine>? lines;
  final Signature? signature;
  final bool isLoading;
  final String? error;

  InvoiceFormState({
    this.invoice,
    this.business,
    this.client,
    this.terms,
    this.taxes,
    this.lines = const [],
    this.signature,
    this.isLoading = false,
    this.error,
  });

  InvoiceFormState copyWith({
    Invoice? invoice,
    Business? business,
    Client? client,
    List<Term>? terms,
    List<Tax>? taxes,
    List<InvoiceFormLine>? lines,
    Signature? signature,
    bool clearSignature = false,
    bool? isLoading,
    String? error,
  }) {
    return InvoiceFormState(
      invoice: invoice ?? this.invoice,
      business: business ?? this.business,
      client: client ?? this.client,
      terms: terms ?? this.terms,
      taxes: taxes ?? this.taxes,
      lines: lines ?? this.lines,
      signature: clearSignature ? null : signature ?? this.signature,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
