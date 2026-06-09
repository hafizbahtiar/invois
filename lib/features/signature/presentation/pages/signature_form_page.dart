import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/constants/form_type.dart';
import 'package:invois/core/utils/string_utils.dart';
import 'package:invois/features/business/business.dart';
import 'package:invois/features/shared/widgets/form_section_header.dart';
import 'package:invois/features/shared/widgets/my_action_button.dart';
import 'package:invois/features/shared/widgets/my_selector_field.dart';
import 'package:invois/features/shared/widgets/my_snackbar.dart';
import 'package:invois/features/shared/widgets/my_text_field.dart';
import 'package:invois/features/shared/widgets/my_tile.dart';
import 'package:signature/signature.dart' as signature_lib;

import '../../data/signature_model.dart' as signature_model;
import '../../providers/signature_service.dart';
import '../../providers/signature_notifier.dart';

class SignatureFormPage extends ConsumerStatefulWidget {
  final FormType type;
  final int? signatureId;

  const SignatureFormPage({super.key, required this.type, this.signatureId});

  @override
  ConsumerState<SignatureFormPage> createState() => _SignatureFormPageState();
}

class _SignatureFormPageState extends ConsumerState<SignatureFormPage> {
  //============================================
  // MARK: - Properties
  //============================================

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyController = TextEditingController();
  final _websiteController = TextEditingController();
  final _notesController = TextEditingController();

  // Signature controller
  final signature_lib.SignatureController _signatureController =
      signature_lib.SignatureController(
        penStrokeWidth: 3,
        penColor: Colors.black,
        exportBackgroundColor: Colors.white,
      );

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
          .read(signatureFormProvider.notifier)
          .init(widget.signatureId, widget.type);
      final state = ref.read(signatureFormProvider);

      if (state.signature != null) {
        _nameController.text = state.signature!.name;
        _titleController.text = state.signature!.title ?? '';
        _emailController.text = state.signature!.email ?? '';
        _phoneController.text = state.signature!.phone ?? '';
        _companyController.text = state.signature!.company ?? '';
        _websiteController.text = state.signature!.website ?? '';
        _notesController.text = state.signature!.notes ?? '';

        _signatureController.clear();
        // Convert the stored signatureData (String) back to List<Point>
        if (state.signature!.signatureData != null &&
            state.signature!.signatureData!.isNotEmpty) {
          try {
            final List<dynamic> pointsList = jsonDecode(
              state.signature!.signatureData!,
            );
            _signatureController.points = pointsList
                .map<signature_lib.Point>(
                  (point) => signature_lib.Point(
                    Offset(
                      (point['dx'] as num).toDouble(),
                      (point['dy'] as num).toDouble(),
                    ),
                    signature_lib.PointType.values[point['type'] ?? 0],
                    (point['pressure'] as num?)?.toDouble() ?? 1.0,
                  ),
                )
                .toList();
          } catch (e) {
            // If parsing fails, just clear the signature
            _signatureController.clear();
          }
        }

        setState(() {
          _isDefault = state.signature!.isDefault;
          _isActive = state.signature!.isActive;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _websiteController.dispose();
    _notesController.dispose();
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

  void _onDeleteSignature(signature_model.Signature signature) async {
    final state = ref.watch(signatureFormProvider);
    final result = await ref
        .read(signatureFormProvider.notifier)
        .deleteSignature(signature.id!);
    if (result && mounted) Navigator.pop(context);
    if (mounted) {
      MySnackBar.show(
        context,
        message: state.error ?? 'Signature deleted',
        type: result ? MySnackbarType.success : MySnackbarType.failed,
      );
    }
  }

  void _onSelectBusiness(int businessId) {
    if (_isReadOnly) return;
    ref.read(signatureFormProvider.notifier).setBusiness(businessId);
  }

  void _onSubmit() async {
    if (_isReadOnly) return;
    if (_formKey.currentState!.validate() == false) return;

    final state = ref.read(signatureFormProvider);
    final notifier = ref.read(signatureFormProvider.notifier);
    // Serialize signature points to JSON (kept for re-editing).
    final pointsJson = jsonEncode(
      _signatureController.points
          .map(
            (point) => {
              'dx': point.offset.dx,
              'dy': point.offset.dy,
              'type': point.type.index,
              'pressure': point.pressure,
            },
          )
          .toList(),
    );

    // Render the canonical PNG (ADR-0004) when there are strokes; null otherwise
    // so an unsigned record still saves. Carry forward existing bytes on edit
    // when the canvas is empty.
    Uint8List? imageBytes = state.signature?.imageBytes;
    if (_signatureController.isNotEmpty) {
      imageBytes = await ref
          .read(signatureServiceProvider)
          .export(_signatureController);
    }

    final signature = signature_model.Signature(
      id: (widget.signatureId != null && widget.signatureId! > 0)
          ? widget.signatureId!
          : null,
      name: _nameController.text.trim(),
      title: StringUtils.nullIfBlank(_titleController.text),
      email: StringUtils.nullIfBlank(_emailController.text),
      phone: StringUtils.nullIfBlank(_phoneController.text),
      company: StringUtils.nullIfBlank(_companyController.text),
      website: StringUtils.nullIfBlank(_websiteController.text),
      signatureData: pointsJson,
      imageBytes: imageBytes,
      businessId: state.signature?.businessId,
      isDefault: _isDefault,
      isActive: _isActive,
    );

    final result = await notifier.onUpsert(signature);
    if (result == true && mounted) Navigator.pop(context);
    if (mounted) {
      MySnackBar.show(
        context,
        message: state.error ?? 'Signature saved',
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
      title: const Text('Signature'),
      forceMaterialTransparency: true,
      actions: [if (_isReadOnly) _buildPopupMenu(context)],
    );
  }

  //============================================
  // MARK: - Body
  //============================================

  void _showDeleteConfirmation() {
    final state = ref.watch(signatureFormProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text('Delete Signature'),
        content: Text(
          'Are you sure you want to delete this signature? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _onDeleteSignature(state.signature!);
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
    final state = ref.watch(signatureFormProvider);
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
                  title: 'Signature Details',
                  subtitle: 'This is the signature details',
                  icon: Icons.person,
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
                MyTextField(
                  isReadOnly: _isReadOnly,
                  controller: _titleController,
                  label: 'Title (Optional)',
                  hint: 'This is your signature title',
                  prefixIcon: Icons.title,
                ),
                const SizedBox(height: 16),
                FormSectionHeader(
                  title: 'Signature',
                  subtitle: 'This is the signature',
                  icon: Icons.person,
                ),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AbsorbPointer(
                      absorbing: _isReadOnly,
                      child: signature_lib.Signature(
                        controller: _signatureController,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (_isReadOnly == false) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _signatureController.clear(),
                          icon: const Icon(Icons.clear),
                          label: Text('Clear'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _signatureController.undo(),
                          icon: const Icon(Icons.undo),
                          label: Text('Undo'),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
                      businesses.isNotEmpty &&
                          state.signature?.businessId != null
                      ? businesses
                            .firstWhere(
                              (business) =>
                                  business.id == state.signature?.businessId,
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
                  title: 'Contact',
                  subtitle: 'This is the contact',
                  icon: Icons.contact_page,
                ),
                MyTextField(
                  isRequired: true,
                  isReadOnly: _isReadOnly,
                  controller: _phoneController,
                  label: 'Phone',
                  hint: 'This is your phone number',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
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
                  isRequired: true,
                  isReadOnly: _isReadOnly,
                  controller: _websiteController,
                  label: 'Website',
                  hint: 'This is your website',
                  prefixIcon: Icons.web,
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Website is required';
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
                    onChanged: (value) => _onChangeIsActive(value),
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
