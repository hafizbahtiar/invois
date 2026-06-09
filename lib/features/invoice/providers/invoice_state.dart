import 'package:invois/features/business/business.dart';
import 'package:invois/features/client/data/client_model.dart';
import 'package:invois/features/item/item_model.dart';
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
  final List<Item>? items;

  /// Step 4C-4D-2A: in-memory line snapshots carrying the precise decimal
  /// quantity (`quantityMilli`), kept in sync with [items]. Not yet consumed by
  /// the UI / write / subtotal — those still use [items].
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
    this.items = const [],
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
    List<Item>? items,
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
      items: items ?? this.items,
      lines: lines ?? this.lines,
      signature: clearSignature ? null : signature ?? this.signature,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
