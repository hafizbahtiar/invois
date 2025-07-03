import 'package:invois/features/business/business_module.dart';
import 'package:invois/features/client/client_model.dart';
import 'package:invois/features/item/item_model.dart';
import 'package:invois/features/signature/signature_model.dart';
import 'package:invois/features/tax/tax_model.dart';
import 'package:invois/features/term/term_model.dart';

import 'invoice_model.dart';

class InvoiceFormState {
  final Invoice? invoice;
  final Business? business;
  final Client? client;
  final List<Term>? terms;
  final List<Tax>? taxes;
  final List<Item>? items;
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
    Signature? signature,
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
      signature: signature ?? this.signature,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
