import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/constants/form_type.dart';
import 'package:invois/core/utils/string_utils.dart';
import 'package:invois/features/business/business.dart';
import 'package:invois/core/widgets/form_section_header.dart';
import 'package:invois/core/widgets/my_action_button.dart';
import 'package:invois/core/widgets/my_selector_field.dart';
import 'package:invois/core/widgets/my_snackbar.dart';
import 'package:invois/core/widgets/my_text_field.dart';
import 'package:invois/core/widgets/my_tile.dart';

import '../../providers/client_notifier.dart';
import '../../providers/client_providers.dart';
import '../../data/client_model.dart';

class ClientFormPage extends ConsumerStatefulWidget {
  final FormType type;
  final int? clientId;

  const ClientFormPage({super.key, required this.type, this.clientId});

  @override
  ConsumerState<ClientFormPage> createState() => _ClientFormPageState();
}

class _ClientFormPageState extends ConsumerState<ClientFormPage> {
  //============================================
  // MARK: - Properties
  //============================================

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyController = TextEditingController();
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
          .read(clientFormProvider.notifier)
          .init(widget.clientId, widget.type);

      final state = ref.read(clientFormProvider);
      if (state.client != null) {
        _nameController.text = state.client!.name;
        _descriptionController.text = state.client!.description ?? '';
        _emailController.text = state.client!.email ?? '';
        _phoneController.text = state.client!.phone ?? '';
        _companyController.text = state.client!.company ?? '';
        _websiteController.text = state.client!.website ?? '';

        _addressController.text = state.client!.streetAddress1 ?? '';
        _address2Controller.text = state.client!.streetAddress2 ?? '';
        _cityController.text = state.client!.city ?? '';
        _stateController.text = state.client!.state ?? '';
        _postalCodeController.text = state.client!.postalCode ?? '';

        setState(() {
          _isDefault = state.client!.isDefault;
          _isActive = state.client!.isActive;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
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

  void _onDeleteClient(Client client) async {
    final result = await ref
        .read(clientFormProvider.notifier)
        .deleteClientById(client.id!);
    // Defense-in-depth: refresh the reactive list family after a successful
    // mutation so the list is fresh even if the ObjectBox watch is delayed.
    if (result && mounted) {
      ref.invalidate(clientListProvider);
      Navigator.pop(context);
    }
    if (mounted) {
      final error = ref.read(clientFormProvider).error;
      MySnackBar.show(
        context,
        message: result
            ? 'Client deleted'
            : (error ?? 'Failed to delete client'),
        type: result ? MySnackbarType.success : MySnackbarType.failed,
      );
    }
  }

  void _onSelectBusiness(int businessId) {
    if (_isReadOnly) return;
    ref.read(clientFormProvider.notifier).onSetBusiness(businessId);
  }

  void _onSubmit() async {
    if (_isReadOnly) return;
    if (_formKey.currentState!.validate() == false) return;

    final state = ref.read(clientFormProvider);
    final notifier = ref.read(clientFormProvider.notifier);

    final client = Client(
      id: (widget.clientId != null && widget.clientId! > 0)
          ? widget.clientId!
          : null,
      name: _nameController.text.trim(),
      description: StringUtils.nullIfBlank(_descriptionController.text),
      email: StringUtils.nullIfBlank(_emailController.text),
      phone: StringUtils.nullIfBlank(_phoneController.text),
      company: StringUtils.nullIfBlank(_companyController.text),
      website: StringUtils.nullIfBlank(_websiteController.text),
      streetAddress1: StringUtils.nullIfBlank(_addressController.text),
      streetAddress2: StringUtils.nullIfBlank(_address2Controller.text),
      city: StringUtils.nullIfBlank(_cityController.text),
      state: StringUtils.nullIfBlank(_stateController.text),
      postalCode: StringUtils.nullIfBlank(_postalCodeController.text),
      businessId: state.client?.businessId,
      isDefault: _isDefault,
      isActive: _isActive,
    );

    final result = await notifier.onUpsert(client);
    if (result == true && mounted) {
      ref.invalidate(clientListProvider);
      Navigator.pop(context);
    }
    if (mounted) {
      final error = ref.read(clientFormProvider).error;
      MySnackBar.show(
        context,
        message: result ? 'Client saved' : (error ?? 'Failed to save client'),
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
      title: const Text('Client'),
      forceMaterialTransparency: true,
      actions: [if (_isReadOnly) _buildPopupMenu(context)],
    );
  }

  //============================================
  // MARK: - Body
  //============================================

  void _showDeleteConfirmation() {
    final state = ref.watch(clientFormProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text('Delete Client'),
        content: Text(
          'Are you sure you want to delete this client? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _onDeleteClient(state.client!);
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
    final state = ref.watch(clientFormProvider);
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
                  title: 'Client Details',
                  subtitle: 'This is the client details',
                  icon: Icons.person,
                ),
                MyTextField(
                  isRequired: true,
                  isReadOnly: _isReadOnly,
                  controller: _nameController,
                  label: 'Name',
                  hint: 'This is your public display name',
                  maxLength: 100,
                  showCounter: false,
                  prefixIcon: Icons.person,
                  keyboardType: TextInputType.name,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                MyTextField(
                  isRequired: true,
                  isReadOnly: _isReadOnly,
                  controller: _companyController,
                  label: 'Company',
                  hint: 'Enter the company name',
                  maxLength: 200,
                  showCounter: false,
                  prefixIcon: Icons.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Company is required';
                    }
                    return null;
                  },
                ),
                MyTextField(
                  isReadOnly: _isReadOnly,
                  controller: _descriptionController,
                  label: 'Description (Optional)',
                  hint: 'This is your tax description',
                  maxLength: 500,
                  showCounter: false,
                  prefixIcon: Icons.title,
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
                  value:
                      businesses.isNotEmpty && state.client?.businessId != null
                      ? businesses
                            .firstWhere(
                              (business) =>
                                  business.id == state.client?.businessId,
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
                  title: 'Client Addresses',
                  subtitle: 'This is the client addresses',
                  icon: Icons.location_on,
                ),
                MyTextField(
                  isRequired: true,
                  isReadOnly: _isReadOnly,
                  controller: _addressController,
                  label: 'Address',
                  hint: 'This is your address',
                  maxLength: 255,
                  showCounter: false,
                  keyboardType: TextInputType.streetAddress,
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
                  keyboardType: TextInputType.streetAddress,
                  label: 'Address 2',
                  hint: 'This is your address 2',
                  maxLength: 255,
                  showCounter: false,
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
                  maxLength: 100,
                  showCounter: false,
                  keyboardType: TextInputType.streetAddress,
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
                        keyboardType: TextInputType.streetAddress,
                        label: 'State',
                        hint: 'This is your state',
                        maxLength: 100,
                        showCounter: false,
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
                  title: 'Contact',
                  subtitle: 'This is the contact',
                  icon: Icons.phone,
                ),
                MyTextField(
                  isRequired: true,
                  isReadOnly: _isReadOnly,
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  label: 'Phone',
                  hint: 'Enter the phone number',
                  maxLength: 20,
                  showCounter: false,
                  prefixIcon: Icons.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Phone is required';
                    }
                    return null;
                  },
                ),
                MyTextField(
                  isRequired: true,
                  isReadOnly: _isReadOnly,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  label: 'Email',
                  hint: 'Enter the email',
                  maxLength: 254,
                  showCounter: false,
                  prefixIcon: Icons.email,
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
                  keyboardType: TextInputType.url,
                  label: 'Website',
                  hint: 'Enter the website',
                  maxLength: 2083,
                  showCounter: false,
                  prefixIcon: Icons.public,
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
