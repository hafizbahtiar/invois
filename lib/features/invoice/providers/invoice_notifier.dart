import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:invois/core/constants/form_type.dart';
import 'package:invois/core/money/money.dart';
import 'package:invois/core/result/app_failure.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/features/business/providers/business_notifier.dart';
import 'package:invois/features/business/data/business_repository.dart';
import 'package:invois/features/client/providers/client_notifier.dart';
import 'package:invois/features/client/data/client_repository.dart';
import 'package:invois/features/item/item_model.dart';
import 'package:invois/features/signature/data/signature_model.dart';
import 'package:invois/features/signature/data/signature_repository.dart';
import 'package:invois/features/tax/data/tax_model.dart';
import 'package:invois/features/term/data/term_model.dart';

import '../invoice_form_line.dart';
import '../invoice_line_builder.dart';
import '../invoice_line_view.dart';
import 'invoice_state.dart';
import '../data/invoice_model.dart';
import '../data/invoice_numbering.dart';
import '../data/invoice_repository.dart';
import '../data/invoice_validation.dart';

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

  Future<void> setBusiness(dynamic business) async {
    state = state.copyWith(business: business);
    final businessId = business?.id;
    if (businessId != null && businessId > 0) {
      await setDefaultSignatureForBusiness(businessId);
    } else {
      state = state.copyWith(clearSignature: true);
    }
  }

  void setClient(dynamic client) {
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

      Signature? signature;
      final signatureId = invoice.signatureId;
      if (signatureId != null && signatureId > 0) {
        signature = await _ref
            .read(signatureRepositoryProvider)
            .getSignatureById(signatureId);
      }

      // Load items, taxes, and terms
      final items = invoice.items.toList();
      final taxes = invoice.taxes.toList();
      final terms = invoice.terms.toList();
      // Step 4C-4D-2A: carry precise quantities — prefer Invoice.lines, else
      // derive from legacy items. Not consumed by UI/write yet.
      final lines = InvoiceFormLine.resolve(
        items: items,
        lines: invoice.lines.toList(),
      );

      state = state.copyWith(
        invoice: invoice,
        items: items,
        lines: lines,
        taxes: taxes,
        terms: terms,
        signature: signature,
        clearSignature: signature == null,
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
      await setDefaultSignatureForBusiness(business.id!);
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

  void setSignature(Signature? signature) {
    state = state.copyWith(signature: signature);
  }

  void clearSignature() {
    state = state.copyWith(clearSignature: true);
  }

  Future<void> setDefaultSignatureForBusiness(int businessId) async {
    final signature = await _ref
        .read(signatureRepositoryProvider)
        .getDefaultActiveSignatureByBusinessId(businessId);
    state = signature == null
        ? state.copyWith(clearSignature: true)
        : state.copyWith(signature: signature);
  }

  void resetItems() {
    // Keep the in-memory line carrier (Step 4C-4D-2A) in lockstep with items.
    state = state.copyWith(items: [], lines: []);
  }

  // Add a new item to the temporary items list
  void addItem(Item item) {
    final List<Item> updatedItems = [...state.items!, item];
    final List<InvoiceFormLine> updatedLines = [
      ...?state.lines,
      InvoiceFormLine.fromItem(item),
    ];
    state = state.copyWith(items: updatedItems, lines: updatedLines);
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

    final List<InvoiceFormLine> updatedLines = (state.lines ?? const [])
        .map(
          (line) => line.item.id == updatedItem.id
              ? InvoiceFormLine.fromItem(updatedItem)
              : line,
        )
        .toList();

    state = state.copyWith(items: updatedItems, lines: updatedLines);
  }

  // Remove an item from the temporary items list
  void removeItem(Item itemToRemove) {
    if (state.items == null) return;

    final List<Item> updatedItems = state.items!
        .where((item) => item.id != itemToRemove.id)
        .toList();

    final List<InvoiceFormLine> updatedLines = (state.lines ?? const [])
        .where((line) => line.item.id != itemToRemove.id)
        .toList();

    state = state.copyWith(items: updatedItems, lines: updatedLines);
  }

  // Subtotal via the unified line adapter (Step 4C-4C): same lines-preferred /
  // items-fallback source as the detail/PDF item rows. No persisted lines exist
  // at compose time, so this resolves from the in-memory items.
  int calculateSubtotalCents() {
    final items = state.items;
    if (items == null || items.isEmpty) return 0;

    return InvoiceLineReader.subtotalCents(lines: const [], items: items);
  }

  double calculateSubtotal() {
    return Money(calculateSubtotalCents()).toDouble();
  }

  Future<String?> nextInvoiceNumberForBusiness(int businessId) async {
    final result = await _repository.nextInvoiceNumber(businessId);
    if (result is Ok<String>) return result.value;

    final failure = (result as Err<String>).failure;
    state = state.copyWith(error: failure.message);
    return null;
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
      signatureId: state.signature?.id,
      subtotal: Money(invoice.effectiveSubtotalCents).toDouble(),
      discountAmount: Money(invoice.effectiveDiscountAmountCents).toDouble(),
      taxAmount: Money(invoice.effectiveTaxAmountCents).toDouble(),
      total: Money(invoice.effectiveTotalCents).toDouble(),
      paidAmount: Money(invoice.effectivePaidAmountCents).toDouble(),
      balanceDue: Money(invoice.effectiveBalanceDueCents).toDouble(),
      subtotalCents: invoice.effectiveSubtotalCents,
      discountAmountCents: invoice.effectiveDiscountAmountCents,
      taxAmountCents: invoice.effectiveTaxAmountCents,
      totalCents: invoice.effectiveTotalCents,
      paidAmountCents: invoice.effectivePaidAmountCents,
      balanceDueCents: invoice.effectiveBalanceDueCents,
    );

    final validationFailure = await _validateForSave(updatedInvoice);
    if (validationFailure != null) {
      state = state.copyWith(
        isLoading: false,
        error: validationFailure.message,
      );
      return Err(validationFailure);
    }

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

    // Step 4C-4B: dual-write Invoice.lines mirroring the just-saved items
    // (built after the items loop so sourceItemId reflects assigned ids).
    // Replaces any prior lines; totals/stored snapshot are unchanged.
    await _repository.replaceInvoiceLines(
      savedInvoice.id!,
      InvoiceLineBuilder.fromItems(state.items ?? const []),
    );

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

  /// Centralised status change — the single path every status-changing UI uses.
  /// Payment fields are always reconciled so invoice status and payment can
  /// never diverge:
  ///   - paid -> mark fully paid (balance 0, paymentStatus paid)
  ///   - sent -> mark sent (status + sentDate), payment reset to unpaid
  ///   - any other status -> payment reset to unpaid
  Future<void> updateInvoiceStatus(int id, InvoiceStatus status) async {
    final Result<void> result;
    if (status == InvoiceStatus.paid) {
      result = await _repository.markAsPaid(id);
    } else if (status == InvoiceStatus.sent) {
      result = await _repository.markAsSent(id);
    } else {
      result = await _repository.markAsUnpaid(id, status: status);
    }
    state = state.copyWith(
      isLoading: false,
      error: result.failureOrNull?.message,
    );
  }

  /// Mark the invoice as sent (status + sentDate; payment untouched).
  Future<bool> markInvoiceAsSent(int id) async {
    final result = await _repository.markAsSent(id);
    state = state.copyWith(
      isLoading: false,
      error: result.failureOrNull?.message,
    );
    return result.isOk;
  }

  /// Mark the invoice as paid. Full payment by default; pass [paidAmount] for a
  /// partial payment.
  Future<bool> markInvoiceAsPaid(int id, {double? paidAmount}) async {
    final result = await _repository.markAsPaid(id, paidAmount: paidAmount);
    state = state.copyWith(
      isLoading: false,
      error: result.failureOrNull?.message,
    );
    return result.isOk;
  }

  Future<ValidationFailure?> _validateForSave(Invoice invoice) async {
    final items = state.items ?? const <Item>[];
    final validationMessage = InvoiceValidation.validateForSave(
      invoice: invoice,
      items: items,
      hasBusiness: invoice.businessId != null && invoice.businessId! > 0,
      hasClient: invoice.clientId != null && invoice.clientId! > 0,
    );
    if (validationMessage != null) {
      return ValidationFailure(validationMessage);
    }

    final businessId = invoice.businessId;
    if (businessId == null || businessId <= 0) {
      return const ValidationFailure('Please select a business before saving.');
    }

    final numberResult = await _repository.isInvoiceNumberAvailable(
      businessId: businessId,
      invoiceNumber: InvoiceNumbering.fullNumber(invoice),
      excludingInvoiceId: invoice.id,
    );

    if (numberResult is Err<bool>) {
      return ValidationFailure(numberResult.failure.message);
    }

    if (!(numberResult as Ok<bool>).value) {
      return const ValidationFailure(
        'Invoice number already exists for this business.',
      );
    }

    return null;
  }
}

// Provider for InvoiceFormNotifier
final invoiceFormProvider =
    StateNotifierProvider<InvoiceFormNotifier, InvoiceFormState>(
      (ref) => InvoiceFormNotifier(ref.watch(invoiceRepositoryProvider), ref),
    );
