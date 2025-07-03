import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MyTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool isRequired;
  final bool isReadOnly;
  final TextInputType keyboardType;
  final int maxLines;
  final int? maxLength;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final Function(String)? onChanged;
  final Function()? onTap;
  final FocusNode? focusNode;
  final bool obscureText;
  final TextCapitalization textCapitalization;
  final AutovalidateMode autovalidateMode;
  final EdgeInsetsGeometry? contentPadding;
  final TextInputAction? textInputAction;
  final Function(String)? onSubmitted;
  final bool autofocus;
  final bool enableSuggestions;
  final bool autocorrect;
  final String? initialValue;
  final bool enabled;
  final bool showCounter;

  const MyTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.isRequired = false,
    this.isReadOnly = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
    this.inputFormatters,
    this.onChanged,
    this.onTap,
    this.focusNode,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.contentPadding,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
    this.enableSuggestions = true,
    this.autocorrect = true,
    this.initialValue,
    this.enabled = true,
    this.showCounter = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        hintText: hint ?? '',
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffix: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: isReadOnly
            ? Theme.of(
                context,
              ).colorScheme.surfaceContainer.withValues(alpha: 0.3)
            : Theme.of(context).colorScheme.surface,
        contentPadding:
            contentPadding ??
            EdgeInsets.symmetric(
              horizontal: prefixIcon == null ? 16 : 0,
              vertical: maxLines > 1 ? 18 : 14,
            ),
        counterText: showCounter ? null : '',
      ),
      enabled: enabled && !isReadOnly,
      readOnly: isReadOnly,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      validator:
          validator ??
          (isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '$label is required';
                  }
                  return null;
                }
              : null),
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onTap: onTap,
      focusNode: focusNode,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      autovalidateMode: autovalidateMode,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      autofocus: autofocus,
      enableSuggestions: enableSuggestions,
      autocorrect: autocorrect,
    );
  }
}
