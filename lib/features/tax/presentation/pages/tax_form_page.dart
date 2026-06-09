import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/constants/form_type.dart';
import 'package:invois/core/constants/tax_type.dart';
import 'package:invois/core/utils/safe_parse.dart';
import 'package:invois/features/business/business.dart';
import 'package:invois/features/shared/widgets/form_section_header.dart';
import 'package:invois/features/shared/widgets/my_action_button.dart';
import 'package:invois/features/shared/widgets/my_selector_field.dart';
import 'package:invois/features/shared/widgets/my_snackbar.dart';
import 'package:invois/features/shared/widgets/my_text_field.dart';
import 'package:invois/features/shared/widgets/my_tile.dart';

import '../../providers/tax_notifier.dart';
import '../../providers/tax_providers.dart';
import '../../data/tax_model.dart';

class TaxFormPage extends ConsumerStatefulWidget {
  final FormType type;
  final int? taxId;

  const TaxFormPage({super.key, required this.type, this.taxId});

  @override
  ConsumerState<TaxFormPage> createState() => _TaxFormPageState();
}

class _TaxFormPageState extends ConsumerState<TaxFormPage> {
  //============================================
  // MARK: - Properties
  //============================================

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rateController = TextEditingController();

  bool _isReadOnly = false;
  bool _isDefault = false;
  bool _isActive = false;

  TaxType _taxType = TaxType.fixed;

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

      await ref.read(taxFormProvider.notifier).init(widget.taxId, widget.type);
      final state = ref.read(taxFormProvider);
      if (state.tax != null) {
        _nameController.text = state.tax!.name;
        _descriptionController.text = state.tax!.description ?? '';
        _rateController.text = state.tax!.rate == 0.0
            ? ''
            : state.tax!.rate.toString();

        setState(() {
          _isDefault = state.tax!.isDefault;
          _isActive = state.tax!.isActive;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _rateController.dispose();
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

  void _onChangeIsDefault(bool value) {
    if (_isReadOnly) return;
    setState(() {
      _isDefault = value;
    });
  }

  void _onChangeIsActive(bool value) {
    if (_isReadOnly) return;
    setState(() {
      _isActive = value;
    });
  }

  void _onChangeTaxType(TaxType value) {
    if (_isReadOnly) return;
    setState(() {
      _taxType = value;
    });
  }

  void _onDeleteTax(Tax tax) async {
    final state = ref.watch(taxFormProvider);
    final result = await ref
        .read(taxFormProvider.notifier)
        .deleteTaxById(tax.id!);
    // Defense-in-depth: refresh the reactive list family after a successful
    // mutation so the list is fresh even if the ObjectBox watch is delayed.
    if (result && mounted) {
      ref.invalidate(taxListProvider);
      Navigator.pop(context);
    }
    if (mounted) {
      MySnackBar.show(
        context,
        message: state.error ?? 'Tax deleted',
        type: result ? MySnackbarType.success : MySnackbarType.failed,
      );
    }
  }

  void _onSelectBusiness(int businessId) {
    if (_isReadOnly) return;
    ref.read(taxFormProvider.notifier).setBusiness(businessId);
  }

  void _onSubmit() async {
    if (_formKey.currentState!.validate() == false) return;

    final state = ref.read(taxFormProvider);

    final tax = Tax(
      id: (widget.taxId != null && widget.taxId! > 0) ? widget.taxId! : null,
      name: _nameController.text,
      description: _descriptionController.text,
      rate: SafeParse.decimal(_rateController.text),
      businessId: state.tax?.businessId,
      taxType: _taxType.name,
      isDefault: _isDefault,
      isActive: _isActive,
    );

    final notifier = ref.read(taxFormProvider.notifier);
    final result = await notifier.onUpsert(tax);
    if (result == true && mounted) {
      ref.invalidate(taxListProvider);
      Navigator.pop(context);
    }
    if (mounted) {
      MySnackBar.show(
        context,
        message: state.error ?? 'Tax saved',
        type: result ? MySnackbarType.success : MySnackbarType.failed,
      );
    }
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
      title: const Text('Tax'),
      forceMaterialTransparency: true,
      actions: [if (_isReadOnly) _buildPopupMenu(context)],
    );
  }

  //============================================
  // MARK: - Body
  //============================================

  void _showDeleteConfirmation() {
    final state = ref.watch(taxFormProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text('Delete Tax'),
        content: Text(
          'Are you sure you want to delete this tax? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _onDeleteTax(state.tax!);
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
        if (_isReadOnly == false) _buildActionButtons(context),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    final state = ref.watch(taxFormProvider);
    final businesses =
        ref
            .watch(businessListProvider(const BusinessQuery(isActive: true)))
            .value ??
        const [];

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              spacing: 8.0,
              children: [
                FormSectionHeader(
                  title: 'Tax Details',
                  subtitle: 'This is the tax details',
                  icon: Icons.percent,
                ),
                MyTextField(
                  isRequired: true,
                  isReadOnly: _isReadOnly,
                  controller: _nameController,
                  label: 'Name',
                  hint: 'This is your public display name',
                  prefixIcon: Icons.person,
                  keyboardType: TextInputType.name,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                MySelectorField(
                  label: 'Tax Type',
                  onSelected: (value) => _onChangeTaxType(value),
                  value: _taxType.name,
                  selectedValue: _taxType,
                  selectItems: TaxType.values
                      .map(
                        (taxType) => SelectItem<TaxType>(
                          value: taxType,
                          label: taxType.name,
                        ),
                      )
                      .toList(),
                ),
                MyTextField(
                  isReadOnly: _isReadOnly,
                  controller: _descriptionController,
                  label: 'Description (Optional)',
                  hint: 'This is your tax description',
                  prefixIcon: Icons.title,
                  keyboardType: TextInputType.multiline,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                FormSectionHeader(
                  title: 'Business',
                  subtitle: 'This is the business',
                  icon: Icons.business,
                ),
                MySelectorField(
                  isMultiSelect: false,
                  label: 'Business',
                  isReadOnly: _isReadOnly,
                  onSelected: (value) => _onSelectBusiness(value),
                  value: businesses.isNotEmpty && state.tax?.businessId != null
                      ? businesses
                            .firstWhere(
                              (business) =>
                                  business.id == state.tax?.businessId,
                              orElse: () => businesses.first,
                            )
                            .name
                      : null,
                  selectItems: businesses
                      .map(
                        (business) => SelectItem<int>(
                          value: business.id!,
                          label: business.name,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                FormSectionHeader(
                  title: 'Rate',
                  subtitle: 'This is the rate',
                  icon: Icons.percent,
                ),
                MyTextField(
                  isRequired: true,
                  isReadOnly: _isReadOnly,
                  controller: _rateController,
                  label: 'Tax Rate',
                  hint: 'Enter the tax rate (e.g., 10 for 10%)',
                  prefixIcon: Icons.percent,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Tax rate is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                FormSectionHeader(
                  title: 'Settings',
                  subtitle: 'This is the settings',
                  icon: Icons.settings,
                ),
                MyTile(
                  isRounded: true,
                  showChevron: false,
                  title: 'Is Default',
                  subtitle: 'This is the default business',
                  icon: Icons.star,
                  isReadOnly: _isReadOnly,
                  onTap: () => _onChangeIsDefault(!_isDefault),
                  trailing: Switch.adaptive(
                    value: _isDefault,
                    onChanged: (value) => _onChangeIsDefault(value),
                  ),
                ),
                MyTile(
                  isRounded: true,
                  showChevron: false,
                  title: 'Is Active',
                  subtitle: 'This is the active business',
                  icon: Icons.check_circle,
                  isReadOnly: _isReadOnly,
                  onTap: () => _onChangeIsActive(!_isActive),
                  trailing: Switch.adaptive(
                    value: _isActive,
                    onChanged: _onChangeIsActive,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return MyActionButton(
      cancelLabel: 'Cancel',
      saveLabel: widget.type == FormType.add ? 'Add' : 'Save',
      cancelOnPressed: () => Navigator.pop(context),
      saveOnPressed: () async => _onSubmit(),
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
