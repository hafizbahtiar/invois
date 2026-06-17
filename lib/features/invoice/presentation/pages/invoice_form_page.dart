import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/constants/form_type.dart';
import 'package:invois/core/money/money.dart';
import 'package:invois/core/utils/currency_utils.dart';
import 'package:invois/features/business/business.dart';
import 'package:invois/features/client/client.dart';
import 'package:invois/features/settings/providers/settings_notifier.dart';
import 'package:invois/features/signature/data/signature_model.dart';
import 'package:invois/features/signature/data/signature_query.dart';
import 'package:invois/features/signature/providers/signature_providers.dart';
import 'package:invois/core/widgets/form_section_header.dart';
import 'package:invois/core/widgets/my_action_button.dart';
import 'package:invois/core/widgets/my_date_picker_field.dart';
import 'package:invois/core/widgets/my_dropdown_menu.dart';
import 'package:invois/core/widgets/my_selector_field.dart';
import 'package:invois/core/widgets/my_snackbar.dart';
import 'package:invois/core/widgets/my_text_field.dart';
import 'package:invois/core/widgets/my_tile.dart';
import 'package:invois/features/tax/tax.dart';
import 'package:invois/features/term/term.dart';

import '../../domain/invoice_composer.dart';
import '../../domain/invoice_form_line.dart';
import '../../domain/invoice_payment.dart';
import '../../domain/invoice_quantity_input.dart';
import '../../providers/invoice_notifier.dart';
import '../../providers/invoice_state.dart';
import '../../data/invoice_model.dart';
import '../widgets/invoice_line_sheet.dart';

class InvoiceFormPage extends ConsumerStatefulWidget {
  final FormType type;
  final int? invoiceId;

  const InvoiceFormPage({super.key, required this.type, this.invoiceId});

  @override
  ConsumerState<InvoiceFormPage> createState() => _InvoiceFormPageState();
}

class _InvoiceFormPageState extends ConsumerState<InvoiceFormPage> {
  //============================================
  // MARK: - Properties
  //============================================

  // Invoice Basic Information
  final _formKey = GlobalKey<FormState>();
  final _invoicePrefixController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _invoiceReferenceController = TextEditingController();
  final _invoiceNotesController = TextEditingController();

  // Invoice Type and Status
  InvoiceType _selectedInvoiceType = InvoiceType.invoice;
  InvoiceStatus _selectedStatus = InvoiceStatus.draft;
  PaymentStatus _selectedPaymentStatus = PaymentStatus.unpaid;

  // Currency and Pricing
  String _selectedCurrency = 'MYR';
  final _discountRateController = TextEditingController();
  final _discountAmountController = TextEditingController();
  final _paidAmountController = TextEditingController();

  // Recurring Settings
  bool _isRecurring = false;
  RecurringFrequency _selectedRecurringFrequency = RecurringFrequency.monthly;
  final _recurringIntervalController = TextEditingController();
  DateTime? _recurringEndDate;

  // Item (the add/edit fields live inside InvoiceLineSheet)
  int _nextTemporaryLineId = -1;

  bool _isReadOnly = true;
  bool _isInvoiceNumberManuallyEdited = false;

  // Dates
  DateTime? _issueDate;
  DateTime? _dueDate;
  DateTime? _sentDate;
  DateTime? _viewedDate;
  DateTime? _paidDate;

  //============================================
  // MARK: - Init
  //============================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.type == FormType.view) {
        setState(() {
          _isReadOnly = true;
        });
      } else {
        setState(() {
          _isReadOnly = false;
        });
      }

      await ref
          .read(invoiceFormProvider.notifier)
          .init(widget.invoiceId, widget.type);
      // Active businesses load reactively via businessListProvider(const BusinessQuery(isActive: true)).
      // Active clients load reactively via clientListProvider(const ClientQuery(isActive: true)).
      // Active taxes load reactively via taxListProvider(const TaxQuery(isActive: true)).
      // Active signatures load reactively via signatureListProvider(const SignatureQuery(isActive: true)).
      // Active terms load reactively via termListProvider(const TermQuery(isActive: true)).

      final state = ref.read(invoiceFormProvider);
      final settingState = ref.read(settingsProvider);

      _invoicePrefixController.text = '';
      _selectedCurrency = settingState.currencyCode;

      _discountRateController.text = '0.0';
      _discountAmountController.text = '0.0';
      _paidAmountController.text = '0.0';

      if (state.invoice != null &&
          state.invoice!.id! > 0 &&
          widget.invoiceId != null) {
        _invoicePrefixController.text =
            state.invoice!.invoiceNumberPrefix ?? '';
        _invoiceNumberController.text = state.invoice!.invoiceNumber;
        _invoiceReferenceController.text = state.invoice!.reference ?? '';
        _invoiceNotesController.text = state.invoice!.notes ?? '';
        _selectedCurrency =
            state.invoice!.currency ?? settingState.currencyCode;
        _discountRateController.text = state.invoice!.discountRate.toString();
        _discountAmountController.text = state.invoice!.discountAmount
            .toString();
        _paidAmountController.text = state.invoice!.paidAmount.toString();
        _isRecurring = state.invoice!.isRecurring;
        _selectedRecurringFrequency = RecurringFrequencyExtension.fromName(
          state.invoice!.recurringFrequency,
        );
        _recurringIntervalController.text =
            state.invoice!.recurringInterval?.toString() ?? '';
        _recurringEndDate = state.invoice!.recurringEndDate;
        _issueDate = state.invoice!.issueDate;
        _dueDate = state.invoice!.dueDate;
        _sentDate = state.invoice!.sentDate;
        _viewedDate = state.invoice!.viewedDate;
        _paidDate = state.invoice!.paidDate;

        // Set enums (safe parse — tolerates unknown/legacy stored values
        // instead of throwing via Enum.values.byName).
        _selectedInvoiceType = InvoiceTypeExtension.fromName(
          state.invoice!.invoiceType,
        );
        _selectedStatus = InvoiceStatusExtension.fromName(
          state.invoice!.status,
        );
        _selectedPaymentStatus = PaymentStatusExtension.fromName(
          state.invoice!.paymentStatus,
        );

        _onSelectClient(state.invoice!.clientId);
      } else {
        final businessId = state.business?.id;
        if (businessId != null && businessId > 0) {
          await _suggestInvoiceNumberForBusiness(businessId);
        }
      }
    });
  }

  @override
  void dispose() {
    _invoicePrefixController.dispose();
    _invoiceNumberController.dispose();
    _invoiceReferenceController.dispose();
    _invoiceNotesController.dispose();
    _discountRateController.dispose();
    _discountAmountController.dispose();
    _paidAmountController.dispose();
    _recurringIntervalController.dispose();
    super.dispose();
  }

  //============================================
  // MARK: - Actions
  //============================================

  void _onEdit() {
    setState(() {
      _isReadOnly = false;
    });
  }

  void _onChangeIssueDate(DateTime date) {
    if (_isReadOnly) return;
    setState(() {
      _issueDate = date;
    });
  }

  void _onChangeDueDate(DateTime date) {
    if (_isReadOnly) return;
    setState(() {
      _dueDate = date;
    });
  }

  void _onChangeSentDate(DateTime date) {
    if (_isReadOnly) return;
    setState(() {
      _sentDate = date;
    });
  }

  void _onChangePaidDate(DateTime date) {
    if (_isReadOnly) return;
    setState(() {
      _paidDate = date;
    });
  }

  void _onChangeViewedDate(DateTime date) {
    if (_isReadOnly) return;
    setState(() {
      _viewedDate = date;
    });
  }

  void _onChangeRecurringEndDate(DateTime date) {
    if (_isReadOnly) return;
    setState(() {
      _recurringEndDate = date;
    });
  }

  void _onInvoiceTypeChanged(InvoiceType type) {
    if (_isReadOnly) return;
    setState(() {
      _selectedInvoiceType = type;
    });
  }

  void _onStatusChanged(InvoiceStatus status) {
    if (_isReadOnly) return;
    setState(() {
      _selectedStatus = status;
      _selectedPaymentStatus = _derivedPaymentStatus();
    });
  }

  void _onCurrencyChanged(String currency) {
    if (_isReadOnly) return;
    setState(() {
      _selectedCurrency = currency;
    });
  }

  void _onInvoiceNumberChanged(String value) {
    if (_isReadOnly) return;
    _isInvoiceNumberManuallyEdited = true;
  }

  /// Changing the prefix re-scopes the suggested number (INV-… vs QUO-…); it
  /// is not a manual edit of the number itself.
  void _onInvoicePrefixChanged(String value) {
    if (_isReadOnly) return;
    final businessId = ref.read(invoiceFormProvider).business?.id;
    if (businessId != null && businessId > 0) {
      _suggestInvoiceNumberForBusiness(businessId);
    }
  }

  Future<void> _suggestInvoiceNumberForBusiness(int businessId) async {
    if (_isReadOnly || _isInvoiceNumberManuallyEdited) return;
    // Never regenerate the number of an existing invoice.
    if (widget.invoiceId != null && widget.invoiceId! > 0) return;

    final prefix = _invoicePrefixController.text;
    final number = await ref
        .read(invoiceFormProvider.notifier)
        .nextInvoiceNumberForBusiness(businessId, prefix: prefix);
    if (number == null || !mounted || _isInvoiceNumberManuallyEdited) return;
    // The prefix changed again while we awaited — a newer call owns the field.
    if (_invoicePrefixController.text != prefix) return;

    setState(() {
      _invoiceNumberController.text = number;
    });
  }

  void _onRecurringChanged(bool value) {
    if (_isReadOnly) return;
    setState(() {
      _isRecurring = value;
    });
  }

  void _onRecurringFrequencyChanged(RecurringFrequency frequency) {
    if (_isReadOnly) return;
    setState(() {
      _selectedRecurringFrequency = frequency;
    });
  }

  Money _moneyFromCents(int cents) {
    return Money(cents, currencyCode: _selectedCurrency);
  }

  Money _parseMoney(String value) {
    return Money.tryParseDecimalString(
          value,
          currencyCode: _selectedCurrency,
        ) ??
        Money.zero(currencyCode: _selectedCurrency);
  }

  String _formatMoneyCents(int cents) {
    return _moneyFromCents(
      cents,
    ).format(symbol: CurrencyUtils.getSymbol(_selectedCurrency));
  }

  void _onDiscountRateChanged(String value) {
    if (_isReadOnly) return;
    final rate = double.tryParse(value) ?? 0.0;
    final subtotalCents = ref
        .read(invoiceFormProvider.notifier)
        .calculateSubtotalCents();
    final discountAmount = _moneyFromCents(subtotalCents).percent(rate);
    _discountAmountController.text = discountAmount.toDouble().toStringAsFixed(
      2,
    );
    _refreshPricingCalculations();
  }

  void _onDiscountAmountChanged(String value) {
    if (_isReadOnly) return;
    final amount = _parseMoney(value);
    final subtotalCents = ref
        .read(invoiceFormProvider.notifier)
        .calculateSubtotalCents();
    final discountRate = subtotalCents > 0
        ? (amount.minorUnits / subtotalCents) * 100
        : 0.0;
    _discountRateController.text = discountRate.toStringAsFixed(2);
    _refreshPricingCalculations();
  }

  void _refreshPricingCalculations() {
    if (_isReadOnly) return;
    // Rebuild the pricing summary and keep the derived payment status in sync.
    setState(() {
      _selectedPaymentStatus = _derivedPaymentStatus();
    });
  }

  /// Payment status is derived from amounts + status (never hand-picked), so
  /// the form cannot save contradictory status/payment combinations.
  PaymentStatus _derivedPaymentStatus() {
    final subtotalCents = ref
        .read(invoiceFormProvider.notifier)
        .calculateSubtotalCents();
    final discountAmount = _parseMoney(_discountAmountController.text);
    final taxAmountCents = _calculateTaxAmountCents(
      ref.read(invoiceFormProvider),
    );
    final totalCents =
        subtotalCents - discountAmount.minorUnits + taxAmountCents;
    final paidAmount = _parseMoney(_paidAmountController.text);
    return InvoicePayment.forManualSave(
      status: _selectedStatus,
      totalCents: totalCents,
      enteredPaidCents: paidAmount.minorUnits,
    ).paymentStatus;
  }

  int _calculateTaxAmountCents(InvoiceFormState state) {
    if (state.taxes == null || state.taxes!.isEmpty) return 0;

    final subtotalCents = ref
        .read(invoiceFormProvider.notifier)
        .calculateSubtotalCents();
    final discountAmount = _parseMoney(_discountAmountController.text);

    return InvoiceComposer.taxOnTaxable(
      taxableCents: subtotalCents - discountAmount.minorUnits,
      rates: state.taxes!.map((tax) => tax.rate),
      currencyCode: _selectedCurrency,
    );
  }

  void _onDeleteInvoice(Invoice invoice) async {
    final result = await ref
        .read(invoiceFormProvider.notifier)
        .deleteInvoiceById(invoice.id!);
    if (!mounted) return;
    // Read the error *after* the delete so the snackbar reflects this
    // operation, not a stale failure from an earlier action.
    final error = ref.read(invoiceFormProvider).error;
    if (result) Navigator.pop(context);
    MySnackBar.show(
      context,
      message: result
          ? 'Invoice deleted'
          : (error ?? 'Failed to delete invoice'),
      type: result ? MySnackbarType.success : MySnackbarType.failed,
    );
  }

  void _onSubmit() async {
    if (_isReadOnly) return;
    if (_formKey.currentState!.validate() == false) return;

    final state = ref.read(invoiceFormProvider);
    final notifier = ref.read(invoiceFormProvider.notifier);

    final discountRate = double.tryParse(_discountRateController.text) ?? 0.0;
    final discountAmount = _parseMoney(_discountAmountController.text);
    final paidAmount = _parseMoney(_paidAmountController.text);

    // Single source of truth for the money spine (see InvoiceComposer). The
    // typed discount amount takes precedence over the rate, matching the form.
    // The subtotal comes from the form lines' authoritative
    // quantityMilli (via the notifier); discount/tax/total/balance still flow
    // through the composer.
    final totals = InvoiceComposer.compose(
      subtotalCentsOverride: notifier.calculateSubtotalCents(),
      discountAmountCents: discountAmount.minorUnits,
      taxRates: (state.taxes ?? const []).map((tax) => tax.rate),
      paidAmountCents: paidAmount.minorUnits,
      currencyCode: _selectedCurrency,
    );

    final subtotalCents = totals.subtotalCents;
    final taxAmountCents = totals.taxAmountCents;
    final totalCents = totals.totalCents;

    // Keep status and payment fields consistent (`status == paid` always means
    // fully paid) — the form is a status-writing entry point too, so it must
    // honour the same invariant as the status dialog and detail actions.
    final payment = InvoicePayment.forManualSave(
      status: _selectedStatus,
      totalCents: totalCents,
      enteredPaidCents: paidAmount.minorUnits,
    );

    final invoice = Invoice(
      id: (widget.invoiceId != null && widget.invoiceId! > 0)
          ? widget.invoiceId!
          : null,
      invoiceNumberPrefix: _invoicePrefixController.text,
      invoiceNumber: _invoiceNumberController.text,
      reference: _invoiceReferenceController.text,
      notes: _invoiceNotesController.text,
      invoiceType: _selectedInvoiceType.name,
      status: _selectedStatus.name,
      paymentStatus: payment.paymentStatus.name,
      issueDate: _issueDate ?? DateTime.now(),
      dueDate: _dueDate ?? DateTime.now(),
      sentDate: _sentDate,
      viewedDate: _viewedDate,
      paidDate:
          _paidDate ??
          (payment.paymentStatus == PaymentStatus.paid ? DateTime.now() : null),
      businessId: state.business?.id,
      clientId: state.client?.id,
      signatureId: state.signature?.id,
      subtotal: _moneyFromCents(subtotalCents).toDouble(),
      discountRate: discountRate,
      discountAmount: discountAmount.toDouble(),
      taxAmount: _moneyFromCents(taxAmountCents).toDouble(),
      total: _moneyFromCents(totalCents).toDouble(),
      paidAmount: _moneyFromCents(payment.paidAmountCents).toDouble(),
      balanceDue: _moneyFromCents(payment.balanceDueCents).toDouble(),
      currency: _selectedCurrency,
      subtotalCents: subtotalCents,
      discountAmountCents: discountAmount.minorUnits,
      taxAmountCents: taxAmountCents,
      totalCents: totalCents,
      paidAmountCents: payment.paidAmountCents,
      balanceDueCents: payment.balanceDueCents,
      isRecurring: _isRecurring,
      recurringFrequency: _isRecurring
          ? _selectedRecurringFrequency.name
          : null,
      recurringInterval: _isRecurring
          ? int.tryParse(_recurringIntervalController.text)
          : null,
      recurringEndDate: _isRecurring ? _recurringEndDate : null,
    );

    // Save the invoice first
    final result = await notifier.onUpsert(invoice);

    if (result.isOk && mounted) Navigator.pop(context);
    if (mounted) {
      MySnackBar.show(
        context,
        message: result.failureOrNull?.message ?? 'Invoice saved',
        type: result.isOk ? MySnackbarType.success : MySnackbarType.failed,
      );
    }
  }

  Future<void> _onSelectBusiness(int? businessId) async {
    if (_isReadOnly) return;
    if (businessId == null) return;
    final businesses =
        ref
            .read(businessListProvider(const BusinessQuery(isActive: true)))
            .value ??
        const <Business>[];
    final business = businesses.firstWhere(
      (business) => business.id == businessId,
      orElse: () => Business(name: ''),
    );
    await ref.read(invoiceFormProvider.notifier).setBusiness(business);
    await _suggestInvoiceNumberForBusiness(businessId);
  }

  Future<void> _onSelectClient(int? clientId) async {
    if (_isReadOnly) return;
    if (clientId == null) return;
    final clients =
        ref.read(clientListProvider(const ClientQuery(isActive: true))).value ??
        const <Client>[];
    final client = clients.firstWhere(
      (client) => client.id == clientId,
      orElse: () => Client(name: ''),
    );
    ref.read(invoiceFormProvider.notifier).setClient(client);
  }

  void _onSelectTerms(List<dynamic> terms) {
    if (_isReadOnly) return;
    final activeTerms =
        ref.read(termListProvider(const TermQuery(isActive: true))).value ??
        const <Term>[];
    final selectedTerms = activeTerms
        .where((term) => terms.contains(term.id))
        .toList();
    ref.read(invoiceFormProvider.notifier).setTerms(selectedTerms);
  }

  void _onSelectTaxes(List<dynamic> taxes) {
    if (_isReadOnly) return;
    final activeTaxes =
        ref.read(taxListProvider(const TaxQuery(isActive: true))).value ??
        const <Tax>[];
    final selectedTaxes = activeTaxes
        .where((tax) => taxes.contains(tax.id))
        .toList();
    ref.read(invoiceFormProvider.notifier).setTaxes(selectedTaxes);
    _refreshPricingCalculations();
  }

  void _onSelectSignature(int? signatureId) {
    if (_isReadOnly) return;
    if (signatureId == null) return;
    final signatures =
        ref
            .read(signatureListProvider(const SignatureQuery(isActive: true)))
            .value ??
        const <Signature>[];
    final signature = signatures.firstWhere(
      (signature) => signature.id == signatureId,
      orElse: () => Signature(name: ''),
    );
    ref.read(invoiceFormProvider.notifier).setSignature(signature);
  }

  void _onClearSignature() {
    if (_isReadOnly) return;
    ref.read(invoiceFormProvider.notifier).clearSignature();
  }

  Future<void> _showLineItemSheet({InvoiceFormLine? existingLine}) async {
    if (_isReadOnly) return;

    final result = await InvoiceLineSheet.show(
      context,
      existingLine: existingLine,
      currencyCode: _selectedCurrency,
      temporaryLineId: _nextTemporaryLineId,
    );
    if (!mounted || result == null) return;

    final notifier = ref.read(invoiceFormProvider.notifier);
    if (result.removed) {
      if (existingLine != null) notifier.removeLine(existingLine);
    } else if (existingLine != null) {
      notifier.updateLine(result.line!);
    } else {
      notifier.addLine(result.line!);
      _nextTemporaryLineId--;
    }
    _refreshPricingCalculations();
  }

  /// Remove a line from the items list (long-press) — confirm first, and never
  /// pop a route: there is no sheet open in this path.
  void _confirmRemoveLine(InvoiceFormLine line) {
    if (_isReadOnly) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog.adaptive(
        title: const Text('Remove Item'),
        content: Text('Remove "${line.name}" from this invoice?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(invoiceFormProvider.notifier).removeLine(line);
              _refreshPricingCalculations();
            },
            child: Text(
              'Remove',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  //============================================
  // MARK: - AppBar
  //============================================

  Widget _buildPopupMenu(BuildContext context) {
    return PopupMenuButton(
      icon: const Icon(Icons.more_vert),
      onOpened: () => FocusScope.of(context).unfocus(),
      onCanceled: () => FocusScope.of(context).unfocus(),
      itemBuilder: (context) => [
        PopupMenuItem(
          onTap: _onEdit,
          child: Row(
            spacing: 8,
            children: [
              const Icon(Icons.edit),
              Expanded(child: Text('Edit')),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () => _showDeleteConfirmation(),
          child: Row(
            spacing: 8,
            children: [
              const Icon(Icons.delete, color: Colors.red),
              Expanded(
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      centerTitle: false,
      title: const Text('Invoice'),
      forceMaterialTransparency: true,
      actions: [_buildPopupMenu(context)],
    );
  }

  //============================================
  // MARK: - Body
  //============================================

  void _showDeleteConfirmation() {
    final state = ref.read(invoiceFormProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text('Delete Invoice'),
        content: Text(
          'Are you sure you want to delete this invoice? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _onDeleteInvoice(state.invoice!);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        _buildForm(context),
        if (!_isReadOnly) _buildActionButtons(context),
      ],
    );
  }

  // MARK: - Form
  Widget _buildForm(BuildContext context) {
    final state = ref.watch(invoiceFormProvider);
    final businesses =
        ref
            .watch(businessListProvider(const BusinessQuery(isActive: true)))
            .value ??
        const <Business>[];
    final clients =
        ref
            .watch(clientListProvider(const ClientQuery(isActive: true)))
            .value ??
        const <Client>[];
    final termState = ref.watch(
      termListProvider(const TermQuery(isActive: true)),
    );
    final taxState = ref.watch(taxListProvider(const TaxQuery(isActive: true)));
    final signatures =
        ref
            .watch(signatureListProvider(const SignatureQuery(isActive: true)))
            .value ??
        const <Signature>[];

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              spacing: 8.0,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // MARK: - Details
                FormSectionHeader(
                  title: 'Invoice Details',
                  subtitle: 'Basic invoice information',
                  icon: Icons.receipt_long,
                  isReadOnly: _isReadOnly,
                ),
                Row(
                  spacing: 8,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: MyTextField(
                        isReadOnly: _isReadOnly,
                        controller: _invoicePrefixController,
                        label: 'Invoice Prefix',
                        maxLength: 20,
                        showCounter: false,
                        onChanged: _onInvoicePrefixChanged,
                      ),
                    ),
                    Expanded(
                      child: MyTextField(
                        isRequired: true,
                        isReadOnly: _isReadOnly,
                        controller: _invoiceNumberController,
                        label: 'Invoice Number',
                        maxLength: 50,
                        showCounter: false,
                        onChanged: _onInvoiceNumberChanged,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter invoice number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  spacing: 8,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // MARK: - Type
                    Expanded(
                      child: MyDropdownMenu<InvoiceType>(
                        label: 'Invoice Type',
                        isReadOnly: _isReadOnly,
                        initialSelection: _selectedInvoiceType,
                        entries: InvoiceType.values
                            .map(
                              (type) => DropdownMenuEntry(
                                value: type,
                                label: type.displayName,
                              ),
                            )
                            .toList(),
                        onSelected: (value) =>
                            value != null ? _onInvoiceTypeChanged(value) : null,
                      ),
                    ),
                    // MARK: - Currency
                    Expanded(
                      child: MyDropdownMenu<String>(
                        label: 'Currency',
                        isReadOnly: _isReadOnly,
                        initialSelection: _selectedCurrency,
                        entries: CurrencyUtils.getAllCodes()
                            .map(
                              (code) => DropdownMenuEntry(
                                value: code,
                                label:
                                    '${CurrencyUtils.getSymbol(code)} ${CurrencyUtils.getName(code)}',
                              ),
                            )
                            .toList(),
                        onSelected: (value) =>
                            value != null ? _onCurrencyChanged(value) : null,
                      ),
                    ),
                  ],
                ),
                MyTextField(
                  controller: _invoiceReferenceController,
                  label: 'Reference',
                  isReadOnly: _isReadOnly,
                  prefixIcon: Icons.description,
                  keyboardType: TextInputType.multiline,
                  maxLines: 3,
                  maxLength: 500,
                  showCounter: false,
                ),
                MyTextField(
                  controller: _invoiceNotesController,
                  label: 'Notes',
                  maxLines: 3,
                  keyboardType: TextInputType.multiline,
                  prefixIcon: Icons.description,
                  isReadOnly: _isReadOnly,
                  maxLength: 2000,
                  showCounter: false,
                ),
                const SizedBox(height: 16),
                FormSectionHeader(
                  title: 'Status & Dates',
                  subtitle: 'Invoice status and important dates',
                  icon: Icons.schedule,
                  isReadOnly: _isReadOnly,
                ),
                Row(
                  spacing: 8,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // MARK: - Status
                    Expanded(
                      child: MyDropdownMenu<InvoiceStatus>(
                        label: 'Status',
                        isReadOnly: _isReadOnly,
                        initialSelection: _selectedStatus,
                        entries: InvoiceStatus.values
                            .map(
                              (status) => DropdownMenuEntry(
                                value: status,
                                label: status.displayName,
                              ),
                            )
                            .toList(),
                        onSelected: (value) =>
                            value != null ? _onStatusChanged(value) : null,
                      ),
                    ),
                    // Payment status is derived from the paid amount and
                    // status (see _derivedPaymentStatus) — display only.
                    Expanded(
                      child: MyDropdownMenu<PaymentStatus>(
                        key: ValueKey(_selectedPaymentStatus),
                        label: 'Payment Status',
                        isReadOnly: true,
                        initialSelection: _selectedPaymentStatus,
                        entries: PaymentStatus.values
                            .map(
                              (status) => DropdownMenuEntry(
                                value: status,
                                label: status.displayName,
                              ),
                            )
                            .toList(),
                        onSelected: (_) {},
                      ),
                    ),
                  ],
                ),
                // MARK: - Dates
                Row(
                  spacing: 8,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: MyDatePickerField(
                        label: 'Issue Date',
                        value: _issueDate,
                        isReadOnly: _isReadOnly,
                        onDateSelected: _onChangeIssueDate,
                      ),
                    ),
                    Expanded(
                      child: MyDatePickerField(
                        label: 'Due Date',
                        value: _dueDate,
                        isReadOnly: _isReadOnly,
                        onDateSelected: _onChangeDueDate,
                      ),
                    ),
                  ],
                ),
                Row(
                  spacing: 8,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: MyDatePickerField(
                        label: 'Sent Date',
                        value: _sentDate,
                        isReadOnly: _isReadOnly,
                        onDateSelected: _onChangeSentDate,
                      ),
                    ),
                    Expanded(
                      child: MyDatePickerField(
                        label: 'Viewed Date',
                        value: _viewedDate,
                        isReadOnly: _isReadOnly,
                        onDateSelected: _onChangeViewedDate,
                      ),
                    ),
                  ],
                ),
                Row(
                  spacing: 8,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: MyDatePickerField(
                        label: 'Paid Date',
                        value: _paidDate,
                        isReadOnly: _isReadOnly,
                        onDateSelected: _onChangePaidDate,
                      ),
                    ),
                    const Expanded(child: SizedBox()),
                  ],
                ),
                const SizedBox(height: 16),
                FormSectionHeader(
                  title: 'Business & Client',
                  subtitle: 'Select business and client for this invoice',
                  icon: Icons.business,
                  isReadOnly: _isReadOnly,
                ),
                // MARK: - Business
                MySelectorField(
                  icon: Icons.business,
                  label: 'Business',
                  isReadOnly: _isReadOnly,
                  selectedValue: state.business?.id,
                  hintText: state.business?.name ?? 'Select Business',
                  onSelected: (value) => _onSelectBusiness(value),
                  selectItems: businesses
                      .map(
                        (business) => SelectItem(
                          label: business.name,
                          value: business.id,
                        ),
                      )
                      .toList(),
                ),
                // MARK: - Client
                MySelectorField(
                  icon: Icons.person,
                  label: 'Client',
                  isReadOnly: _isReadOnly,
                  selectedValue: state.client?.id,
                  hintText: state.client?.name ?? 'Select Client',
                  onSelected: (value) => _onSelectClient(value),
                  selectItems: clients
                      .map(
                        (client) =>
                            SelectItem(label: client.name, value: client.id),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                FormSectionHeader(
                  title: 'Signature',
                  subtitle: 'Attach an optional signature to this invoice',
                  icon: Icons.draw,
                  isReadOnly: _isReadOnly,
                ),
                MySelectorField<int?>(
                  icon: Icons.draw,
                  label: 'Signature',
                  isReadOnly: _isReadOnly,
                  selectedValue: state.signature?.id,
                  value: state.signature?.name,
                  hintText: state.signature?.name ?? 'No signature selected',
                  onSelected: (value) => _onSelectSignature(value),
                  onClear: _onClearSignature,
                  selectItems: signatures
                      .map(
                        (signature) => SelectItem<int?>(
                          label: [
                            signature.name,
                            if ((signature.title ?? '').trim().isNotEmpty)
                              signature.title!,
                          ].join(' · '),
                          value: signature.id,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                FormSectionHeader(
                  title: 'Taxes',
                  subtitle: 'Select applicable taxes',
                  icon: Icons.receipt_long,
                  isReadOnly: _isReadOnly,
                ),
                MySelectorField(
                  icon: Icons.receipt_long,
                  label: 'Tax',
                  isMultiSelect: true,
                  isReadOnly: _isReadOnly,
                  hintText: (state.taxes != null && state.taxes!.isNotEmpty)
                      ? state.taxes!.map((tax) => tax.name).join(', ')
                      : 'Select Tax',
                  selectedValues: state.taxes?.map((tax) => tax.id).toList(),
                  onMultiSelected: (value) => _onSelectTaxes(value),
                  multiSelectItems: (taxState.value ?? const <Tax>[])
                      .map(
                        (tax) => MultiSelectItem<int?>(
                          label: tax.name,
                          value: tax.id,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                // MARK: - Items
                FormSectionHeader(
                  title: 'Items',
                  subtitle: 'Add products or services to your invoice',
                  icon: Icons.list,
                  isReadOnly: _isReadOnly,
                ),
                _buildItemsList(state),
                const SizedBox(height: 16),
                FormSectionHeader(
                  title: 'Pricing & Discounts',
                  subtitle: 'Manage pricing, discounts and payments',
                  icon: Icons.calculate,
                  isReadOnly: _isReadOnly,
                ),
                Row(
                  spacing: 8,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // MARK: - Discount
                    Expanded(
                      child: MyTextField(
                        controller: _discountRateController,
                        label: 'Discount Rate (%)',
                        isReadOnly: _isReadOnly,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        prefixIcon: Icons.percent,
                        maxLength: 10,
                        showCounter: false,
                        onChanged: _onDiscountRateChanged,
                      ),
                    ),
                    Expanded(
                      child: MyTextField(
                        controller: _discountAmountController,
                        label: 'Discount Amount',
                        isReadOnly: _isReadOnly,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        prefixIcon: Icons.attach_money,
                        maxLength: 15,
                        showCounter: false,
                        onChanged: _onDiscountAmountChanged,
                      ),
                    ),
                  ],
                ),
                // MARK: - Paid Amount
                MyTextField(
                  controller: _paidAmountController,
                  label: 'Paid Amount',
                  isReadOnly: _isReadOnly,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  prefixIcon: Icons.payment,
                  maxLength: 15,
                  showCounter: false,
                  onChanged: (_) => _refreshPricingCalculations(),
                ),
                _buildPricingSummary(state),
                const SizedBox(height: 16),
                FormSectionHeader(
                  title: 'Terms & Conditions',
                  subtitle: 'Select terms and conditions for this invoice',
                  icon: Icons.description,
                  isReadOnly: _isReadOnly,
                ),
                MySelectorField(
                  icon: Icons.description,
                  label: 'Terms',
                  isMultiSelect: true,
                  isReadOnly: _isReadOnly,
                  hintText: (state.terms != null && state.terms!.isNotEmpty)
                      ? state.terms!.map((term) => term.name).join(', ')
                      : 'Select Terms',
                  selectedValues: state.terms?.map((term) => term.id).toList(),
                  onMultiSelected: (value) => _onSelectTerms(value),
                  multiSelectItems: (termState.value ?? const <Term>[])
                      .map(
                        (term) => MultiSelectItem<int?>(
                          label: term.name,
                          value: term.id,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                // MARK: - Recurring
                FormSectionHeader(
                  title: 'Recurring Settings',
                  subtitle: 'Configure recurring invoice settings',
                  icon: Icons.repeat,
                  isReadOnly: _isReadOnly,
                ),
                MyTile(
                  isRounded: true,
                  icon: Icons.repeat,
                  title: 'Recurring Invoice',
                  subtitle: 'Enable recurring billing',
                  isReadOnly: _isReadOnly,
                  trailing: Switch.adaptive(
                    value: _isRecurring,
                    onChanged: _onRecurringChanged,
                  ),
                ),
                if (_isRecurring) ...[
                  Row(
                    spacing: 8,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: MyDropdownMenu<RecurringFrequency>(
                          label: 'Frequency',
                          isReadOnly: _isReadOnly,
                          initialSelection: _selectedRecurringFrequency,
                          entries: RecurringFrequency.values
                              .map(
                                (frequency) => DropdownMenuEntry(
                                  value: frequency,
                                  label: frequency.displayName,
                                ),
                              )
                              .toList(),
                          onSelected: (value) => value != null
                              ? _onRecurringFrequencyChanged(value)
                              : null,
                        ),
                      ),
                      Expanded(
                        child: MyTextField(
                          controller: _recurringIntervalController,
                          label: 'Interval',
                          isReadOnly: _isReadOnly,
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.repeat_one,
                          maxLength: 5,
                          showCounter: false,
                        ),
                      ),
                    ],
                  ),
                  MyDatePickerField(
                    label: 'End Date',
                    value: _recurringEndDate,
                    isReadOnly: _isReadOnly,
                    onDateSelected: _onChangeRecurringEndDate,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSummary(InvoiceFormState state) {
    final subtotalCents = ref
        .read(invoiceFormProvider.notifier)
        .calculateSubtotalCents();
    final discountRate = double.tryParse(_discountRateController.text) ?? 0.0;
    final discountAmount = _parseMoney(_discountAmountController.text);
    final taxAmountCents = _calculateTaxAmountCents(state);
    final paidAmount = _parseMoney(_paidAmountController.text);
    final totalCents =
        subtotalCents - discountAmount.minorUnits + taxAmountCents;
    // Mirror exactly what _onSubmit will persist (status==paid forces full
    // payment), so the preview never disagrees with the saved invoice.
    final payment = InvoicePayment.forManualSave(
      status: _selectedStatus,
      totalCents: totalCents,
      enteredPaidCents: paidAmount.minorUnits,
    );
    final balanceDueCents = payment.balanceDueCents;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pricing Summary',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          // Show item details (decimal-aware, from the authoritative form lines)
          if (state.lines != null && state.lines!.isNotEmpty) ...[
            ...state.lines!.map(
              (line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${line.name} (${InvoiceQuantityInput.format(line.quantityMilli)} × ${_formatMoneyCents(line.unitPriceCents)})',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      _formatMoneyCents(line.lineTotalCents),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal:'),
              Text(_formatMoneyCents(subtotalCents)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Discount (${discountRate.toStringAsFixed(1)}%):'),
              Text('-${_formatMoneyCents(discountAmount.minorUnits)}'),
            ],
          ),
          // Show tax breakdown
          if (state.taxes != null && state.taxes!.isNotEmpty) ...[
            ...state.taxes!.map((tax) {
              final subtotalCents = ref
                  .read(invoiceFormProvider.notifier)
                  .calculateSubtotalCents();
              final discountAmount = _parseMoney(
                _discountAmountController.text,
              );
              final taxableAmount = _moneyFromCents(
                subtotalCents - discountAmount.minorUnits,
              );
              final individualTaxAmountCents = taxableAmount
                  .percent(tax.rate)
                  .minorUnits;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${tax.name} (${tax.rate.toStringAsFixed(1)}%):'),
                    Text(_formatMoneyCents(individualTaxAmountCents)),
                  ],
                ),
              );
            }),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Tax:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  _formatMoneyCents(taxAmountCents),
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                _formatMoneyCents(totalCents),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Paid:'),
              Text(_formatMoneyCents(payment.paidAmountCents)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Balance Due:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: balanceDueCents > 0 ? Colors.red : Colors.green,
                ),
              ),
              Text(
                _formatMoneyCents(balanceDueCents),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: balanceDueCents > 0 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(InvoiceFormState state) {
    final lines = state.lines ?? const <InvoiceFormLine>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: Text(
                'No items added yet',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
            ),
          ),
        if (lines.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lines.length,
            itemBuilder: (context, index) {
              final line = lines[index];
              return MyTile(
                isRounded: true,
                icon: Icons.shopping_cart,
                title: line.name,
                isReadOnly: _isReadOnly,
                subtitle:
                    '${_formatMoneyCents(line.unitPriceCents)} x ${InvoiceQuantityInput.format(line.quantityMilli)}',
                trailing: Text(
                  _formatMoneyCents(line.lineTotalCents),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () => _showLineItemSheet(existingLine: line),
                onLongPress: () => _confirmRemoveLine(line),
              );
            },
          ),
        const SizedBox(height: 8),
        if (lines.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Subtotal: ${_formatMoneyCents(ref.read(invoiceFormProvider.notifier).calculateSubtotalCents())}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        if (_isReadOnly == false) ...[
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _showLineItemSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return MyActionButton(
      cancelLabel: 'Cancel',
      saveLabel: widget.type == FormType.add ? 'Add' : 'Save',
      cancelOnPressed: () => Navigator.pop(context),
      saveOnPressed: () => _onSubmit(),
    );
  }

  //============================================
  // MARK: - Build
  //============================================

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(appBar: _buildAppBar(context), body: _buildBody(context)),
    );
  }
}
