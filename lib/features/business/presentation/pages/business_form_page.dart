import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/constants/form_type.dart';
import 'package:invois/core/utils/string_utils.dart';
import 'package:invois/features/shared/widgets/form_section_header.dart';
import 'package:invois/features/shared/widgets/my_action_button.dart';
import 'package:invois/features/shared/widgets/my_snackbar.dart';
import 'package:invois/features/shared/widgets/my_text_field.dart';
import 'package:invois/features/shared/widgets/my_tile.dart';

import '../providers/business_form_provider.dart';
import '../../business_model.dart';

class BusinessFormPage extends ConsumerStatefulWidget {
  final FormType type;
  final int? businessId;

  const BusinessFormPage({super.key, required this.type, this.businessId});

  @override
  ConsumerState<BusinessFormPage> createState() => _BusinessFormPageState();
}

class _BusinessFormPageState extends ConsumerState<BusinessFormPage> {
  //============================================
  // MARK: - Properties
  //============================================

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();

  final _addressController = TextEditingController();
  final _address2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();

  bool _isReadOnly = false;
  bool _isDefault = false;
  bool _isActive = false;

  //============================================
  // MARK: - Init
  //============================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref
          .read(businessFormProvider.notifier)
          .init(widget.businessId, widget.type);

      if (widget.type == FormType.view) {
        setState(() {
          _isReadOnly = true;
        });
      } else {
        setState(() {
          _isReadOnly = false;
        });
      }

      final state = ref.read(businessFormProvider);
      if (state.business != null) {
        _nameController.text = state.business!.name;
        _descriptionController.text = state.business!.description ?? '';
        _phoneController.text = state.business!.phone ?? '';
        _emailController.text = state.business!.email ?? '';
        _websiteController.text = state.business!.website ?? '';

        _addressController.text = state.business!.streetAddress1 ?? '';
        _address2Controller.text = state.business!.streetAddress2 ?? '';
        _cityController.text = state.business!.city ?? '';
        _stateController.text = state.business!.state ?? '';
        _postalCodeController.text = state.business!.postalCode ?? '';

        setState(() {
          _isDefault = state.business!.isDefault;
          _isActive = state.business!.isActive;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
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

  void _onDeleteBusiness(business) async {
    final state = ref.watch(businessFormProvider);
    final result = await ref
        .read(businessFormProvider.notifier)
        .deleteBusiness(business.id!);
    if (result && mounted) Navigator.pop(context);
    if (mounted) {
      MySnackBar.show(
        context,
        message: state.error ?? 'Business deleted',
        type: result ? MySnackbarType.success : MySnackbarType.failed,
      );
    }
  }

  void _onSubmit() async {
    if (_isReadOnly) return;
    if (_formKey.currentState!.validate() == false) return;

    final business = Business(
      id: (widget.businessId != null && widget.businessId! > 0)
          ? widget.businessId!
          : null,
      name: _nameController.text.trim(),
      description: StringUtils.nullIfBlank(_descriptionController.text),
      phone: StringUtils.nullIfBlank(_phoneController.text),
      email: StringUtils.nullIfBlank(_emailController.text),
      website: StringUtils.nullIfBlank(_websiteController.text),
      streetAddress1: StringUtils.nullIfBlank(_addressController.text),
      streetAddress2: StringUtils.nullIfBlank(_address2Controller.text),
      city: StringUtils.nullIfBlank(_cityController.text),
      state: StringUtils.nullIfBlank(_stateController.text),
      postalCode: StringUtils.nullIfBlank(_postalCodeController.text),
      isDefault: _isDefault,
      isActive: _isActive,
    );

    final notifier = ref.read(businessFormProvider.notifier);
    final result = await notifier.onUpsert(business);

    if (result == true && mounted) Navigator.pop(context);

    if (mounted) {
      final state = ref.read(businessFormProvider);
      MySnackBar.show(
        context,
        message: state.error ?? 'Business saved',
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
      title: const Text('Business'),
      forceMaterialTransparency: true,
      actions: [if (_isReadOnly) _buildPopupMenu(context)],
    );
  }

  //============================================
  // MARK: - Body
  //============================================

  void _showDeleteConfirmation() {
    final state = ref.watch(businessFormProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text('Delete Business'),
        content: Text(
          'Are you sure you want to delete this business? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _onDeleteBusiness(state.business!);
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
                  title: 'Business Details',
                  subtitle: 'This is the business details',
                  icon: Icons.business,
                ),
                MyTextField(
                  isRequired: true,
                  isReadOnly: _isReadOnly,
                  controller: _nameController,
                  label: 'Name',
                  hint: 'This is your public display name',
                  prefixIcon: Icons.business,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                MyTextField(
                  isReadOnly: _isReadOnly,
                  controller: _descriptionController,
                  label: 'Description (Optional)',
                  hint: 'This is your business description',
                  prefixIcon: Icons.description,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                FormSectionHeader(
                  title: 'Business Addresses',
                  subtitle: 'This is the business addresses',
                  icon: Icons.location_on,
                ),
                MyTextField(
                  isRequired: true,
                  isReadOnly: _isReadOnly,
                  controller: _addressController,
                  label: 'Address',
                  hint: 'This is your address',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Address is required';
                    }
                    return null;
                  },
                ),
                MyTextField(
                  isRequired: true,
                  isReadOnly: _isReadOnly,
                  controller: _address2Controller,
                  label: 'Address 2',
                  hint: 'This is your address 2',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Address 2 is required';
                    }
                    return null;
                  },
                ),
                MyTextField(
                  isRequired: true,
                  isReadOnly: _isReadOnly,
                  controller: _cityController,
                  label: 'City',
                  hint: 'This is your city',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'City is required';
                    }
                    return null;
                  },
                ),
                Row(
                  spacing: 8,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: MyTextField(
                        isRequired: true,
                        isReadOnly: _isReadOnly,
                        controller: _postalCodeController,
                        label: 'Postal Code',
                        hint: 'This is your postal code',
                        maxLength: 5,
                        showCounter: false,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Postal code is required';
                          }
                          if (value.length != 5) {
                            return 'Postal code must be 5 digits';
                          }
                          return null;
                        },
                      ),
                    ),
                    Expanded(
                      child: MyTextField(
                        isRequired: true,
                        isReadOnly: _isReadOnly,
                        controller: _stateController,
                        label: 'State',
                        hint: 'This is your state',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'State is required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FormSectionHeader(
                  title: 'Business Contact',
                  subtitle: 'This is the business contact',
                  icon: Icons.contact_page,
                ),
                MyTextField(
                  isRequired: true,
                  isReadOnly: _isReadOnly,
                  controller: _phoneController,
                  label: 'Phone',
                  hint: 'This is your phone number',
                  prefixIcon: Icons.phone,
                  maxLength: 15,
                  showCounter: false,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Phone is required';
                    }
                    return null;
                  },
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                MyTextField(
                  isRequired: true,
                  isReadOnly: _isReadOnly,
                  controller: _emailController,
                  label: 'Email',
                  hint: 'This is your email address',
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    return null;
                  },
                ),
                MyTextField(
                  isReadOnly: _isReadOnly,
                  controller: _websiteController,
                  label: 'Website',
                  hint: 'This is your website',
                  prefixIcon: Icons.web,
                  keyboardType: TextInputType.url,
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
