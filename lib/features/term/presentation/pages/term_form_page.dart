import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/constants/form_type.dart';
import 'package:invois/features/business/business.dart';
import 'package:invois/core/widgets/form_section_header.dart';
import 'package:invois/core/widgets/my_action_button.dart';
import 'package:invois/core/widgets/my_selector_field.dart';
import 'package:invois/core/widgets/my_snackbar.dart';
import 'package:invois/core/widgets/my_text_field.dart';
import 'package:invois/core/widgets/my_tile.dart';

import '../../providers/term_notifier.dart';
import '../../providers/term_providers.dart';
import '../../data/term_model.dart';

class TermFormPage extends ConsumerStatefulWidget {
  final FormType type;
  final int? termId;

  const TermFormPage({super.key, required this.type, this.termId});

  @override
  ConsumerState<TermFormPage> createState() => _TermFormPageState();
}

class _TermFormPageState extends ConsumerState<TermFormPage> {
  //============================================
  // MARK: - Properties
  //============================================

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contentController = TextEditingController();
  final _descriptionController = TextEditingController();

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
          .read(termFormProvider.notifier)
          .init(widget.termId, widget.type);
      final state = ref.read(termFormProvider);
      if (state.term != null) {
        _nameController.text = state.term!.name;
        _contentController.text = state.term!.content;
        _descriptionController.text = state.term!.description ?? '';

        setState(() {
          _isDefault = state.term!.isDefault;
          _isActive = state.term!.isActive;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
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

  void _onDeleteTerm(Term term) async {
    final state = ref.watch(termFormProvider);
    final result = await ref
        .read(termFormProvider.notifier)
        .deleteTermById(term.id!);
    // Defense-in-depth: refresh the reactive list family after a successful
    // mutation so the list is fresh even if the ObjectBox watch is delayed.
    if (result && mounted) {
      ref.invalidate(termListProvider);
      Navigator.pop(context);
    }
    if (mounted) {
      MySnackBar.show(
        context,
        message: state.error ?? 'Term deleted',
        type: result ? MySnackbarType.success : MySnackbarType.failed,
      );
    }
  }

  void _onSelectBusiness(int businessId) {
    if (_isReadOnly) return;
    ref.read(termFormProvider.notifier).setBusiness(businessId);
  }

  void _onSubmit() async {
    if (_formKey.currentState!.validate() == false) return;

    final state = ref.read(termFormProvider);
    final notifier = ref.read(termFormProvider.notifier);

    final term = Term(
      id: (widget.termId != null && widget.termId! > 0) ? widget.termId! : null,
      name: _nameController.text,
      content: _contentController.text,
      description: _descriptionController.text,
      businessId: state.term?.businessId,
      isDefault: _isDefault,
      isActive: _isActive,
    );

    final result = await notifier.onUpsert(term);
    if (result == true && mounted) {
      ref.invalidate(termListProvider);
      Navigator.pop(context);
    }
    if (mounted) {
      MySnackBar.show(
        context,
        message: state.error ?? 'Term saved',
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
      title: const Text('Term'),
      forceMaterialTransparency: true,
      actions: [if (_isReadOnly) _buildPopupMenu(context)],
    );
  }

  //============================================
  // MARK: - Body
  //============================================

  void _showDeleteConfirmation() {
    final state = ref.watch(termFormProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text('Delete Term'),
        content: Text(
          'Are you sure you want to delete this term? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _onDeleteTerm(state.term!);
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
    final state = ref.watch(termFormProvider);
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
                  title: 'Term Details',
                  subtitle: 'This is the term details',
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
                MyTextField(
                  isRequired: true,
                  isReadOnly: _isReadOnly,
                  controller: _contentController,
                  label: 'Content',
                  hint: 'This is your term content',
                  maxLength: 500,
                  showCounter: true,
                  prefixIcon: Icons.content_copy,
                  keyboardType: TextInputType.multiline,
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Content is required';
                    }
                    return null;
                  },
                ),
                MyTextField(
                  isReadOnly: _isReadOnly,
                  controller: _descriptionController,
                  label: 'Description (Optional)',
                  hint: 'This is your term description',
                  prefixIcon: Icons.title,
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
                  value: businesses.isNotEmpty && state.term?.businessId != null
                      ? businesses
                            .firstWhere(
                              (business) =>
                                  business.id == state.term?.businessId,
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
