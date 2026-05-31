import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/constants/form_type.dart';
import 'package:invois/core/result/app_failure.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/features/business/business_form_provider.dart';
import 'package:invois/features/business/business_repository.dart';
import 'package:invois/features/client/client_form_provider.dart';
import 'package:invois/features/client/client_repository.dart';
import 'package:invois/features/item/item_model.dart';
import 'package:invois/features/tax/tax_model.dart';
import 'package:invois/features/term/term_model.dart';

import 'invoice_form_state.dart';
import 'invoice_model.dart';
import 'invoice_repository.dart';

class InvoiceFormNotifier extends StateNotifier<InvoiceFormState> {
  final InvoiceRepository _repository;
  final Ref _ref;

  InvoiceFormNotifier(this._repository, this._ref) : super(InvoiceFormState());

  //============================================
  // MARK: - Init
  //============================================

  Future<void> init(int? invoiceId, FormType type) async {
    resetItems();
    if (invoiceId != null && invoiceId > 0) {
      await getInvoiceById(invoiceId);
    } else {
      setInvoice();
      await getDefaultBusiness();
    }
  }

  // Set the invoice to a new invoice
  Future<void> setInvoice() async {
    state = state.copyWith(
      invoice: Invoice(
        invoiceNumber: '',
        issueDate: DateTime.now(),
        dueDate: DateTime.now(),
      ),
    );
  }

  void setBusiness(business) {
    state = state.copyWith(business: business);
  }

  void setClient(client) {
    state = state.copyWith(client: client);
  }

  // Get the invoice by id
  Future<void> getInvoiceById(int id) async {
    final invoice = await _repository.getCompleteInvoice(id);
    if (invoice != null) {
      final businessId = invoice.businessId;
      final clientId = invoice.clientId;
      if (businessId != null && businessId > 0) {
        final business = await _ref
            .read(businessFormProvider.notifier)
            .getBusinessById(businessId);
        state = state.copyWith(business: business);
      }

      if (clientId != null && clientId > 0) {
        final client = await _ref
            .read(clientFormProvider.notifier)
            .getClientById(clientId);
        state = state.copyWith(client: client);
      }

      // Load items, taxes, and terms
      final items = invoice.items.toList();
      final taxes = invoice.taxes.toList();
      final terms = invoice.terms.toList();

      state = state.copyWith(
        invoice: invoice,
        items: items,
        taxes: taxes,
        terms: terms,
      );
    } else {
      state = state.copyWith(invoice: invoice);
    }
  }

  // Get the default business
  Future<void> getDefaultBusiness() async {
    final business = await _ref
        .read(businessRepositoryProvider)
        .getDefaultBusiness();
    state = state.copyWith(business: business);
    if (business != null) {
      await getDefaultClient(business.id!);
    }
  }

  // Get the default client
  Future<void> getDefaultClient(int businessId) async {
    final client = await _ref
        .read(clientRepositoryProvider)
        .getDefaultClientByBusinessId(businessId);
    state = state.copyWith(client: client);
  }

  void setTerms(List<Term> terms) {
    state = state.copyWith(terms: terms);
    // Update the invoice terms relationship if invoice exists
    if (state.invoice != null) {
      state.invoice!.terms.clear();
      state.invoice!.terms.addAll(terms);
    }
  }

  void setTaxes(List<Tax> taxes) {
    state = state.copyWith(taxes: taxes);
    // Update the invoice taxes relationship if invoice exists
    if (state.invoice != null) {
      state.invoice!.taxes.clear();
      state.invoice!.taxes.addAll(taxes);
    }
  }

  void setSignature(signature) {
    state = state.copyWith(signature: signature);
  }

  void resetItems() {
    state = state.copyWith(items: []);
  }

  // Add a new item to the temporary items list
  void addItem(Item item) {
    final List<Item> updatedItems = [...state.items!, item];
    state = state.copyWith(items: updatedItems);
  }

  // Update an existing item in the temporary items list
  void updateItem(Item updatedItem) {
    if (state.items == null) return;

    final List<Item> updatedItems = state.items!.map((item) {
      // Using a temporary ID to identify items in the list
      if (item.id == updatedItem.id) {
        return updatedItem;
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
  }

  // Remove an item from the temporary items list
  void removeItem(Item itemToRemove) {
    if (state.items == null) return;

    final List<Item> updatedItems = state.items!
        .where((item) => item.id != itemToRemove.id)
        .toList();

    state = state.copyWith(items: updatedItems);
  }

  // Calculate the subtotal of all items
  double calculateSubtotal() {
    if (state.items == null || state.items!.isEmpty) return 0.0;

    return state.items!.fold(
      0.0,
      (sum, item) => sum + (item.unitPrice * (item.stockQuantity ?? 1)),
    );
  }

  // Save the current invoice. List updates reactively (ADR-0003) — no refresh.
  Future<Result<Invoice>> onUpsert(Invoice invoice) async {
    state = state.copyWith(isLoading: true, error: null);

    // Guard against missing business/client before force-unwrapping.
    final business = state.business;
    final client = state.client;
    if (business == null || client == null) {
      final message = business == null && client == null
          ? 'Please select a business and a client before saving.'
          : business == null
          ? 'Please select a business before saving.'
          : 'Please select a client before saving.';
      state = state.copyWith(isLoading: false, error: message);
      return Err(ValidationFailure(message));
    }

    // Update the invoice with business and client IDs
    final updatedInvoice = invoice.copyWith(
      businessId: business.id,
      clientId: client.id,
      subtotal: calculateSubtotal(),
      total: calculateSubtotal(),
    );

    // Save the invoice first
    final result = (updatedInvoice.id == null || updatedInvoice.id == 0)
        ? await _repository.create(updatedInvoice)
        : await _repository.update(updatedInvoice);

    if (result is Err<Invoice>) {
      state = state.copyWith(isLoading: false, error: result.failure.message);
      return result;
    }

    final savedInvoice = (result as Ok<Invoice>).value;

    // Save items — always clear first so removals persist.
    await _repository.clearItemsFromInvoice(savedInvoice.id!);
    if (state.items != null && state.items!.isNotEmpty) {
      for (final item in state.items!) {
        await _repository.addItemToInvoice(savedInvoice.id!, item);
      }
    }

    // Save taxes — always clear first so removals persist.
    await _repository.clearTaxesFromInvoice(savedInvoice.id!);
    if (state.taxes != null && state.taxes!.isNotEmpty) {
      for (final tax in state.taxes!) {
        await _repository.addTaxToInvoice(savedInvoice.id!, tax);
      }
    }

    // Save terms — always clear first so removals persist.
    await _repository.clearTermsFromInvoice(savedInvoice.id!);
    if (state.terms != null && state.terms!.isNotEmpty) {
      for (final term in state.terms!) {
        await _repository.addTermToInvoice(savedInvoice.id!, term);
      }
    }

    state = state.copyWith(isLoading: false, error: null);
    return Ok(savedInvoice);
  }

  Future<bool> deleteInvoiceById(int id) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.delete(id);
    return result.fold(
      (_) {
        state = state.copyWith(isLoading: false, error: null);
        return true;
      },
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  Future<void> updateInvoiceStatus(int id, InvoiceStatus status) async {
    final result = await _repository.updateStatus(id, status);
    state = state.copyWith(isLoading: false, error: result.failureOrNull?.message);
  }
}

// Provider for InvoiceFormNotifier
final invoiceFormProvider =
    StateNotifierProvider<InvoiceFormNotifier, InvoiceFormState>(
      (ref) => InvoiceFormNotifier(ref.watch(invoiceRepositoryProvider), ref),
    );
