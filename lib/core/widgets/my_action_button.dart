import 'package:flutter/material.dart';

class MyActionButton extends StatelessWidget {
  final String cancelLabel;
  final String saveLabel;
  final bool showCancel;
  final VoidCallback? cancelOnPressed;
  final VoidCallback? saveOnPressed;
  final bool isSaveLoading;
  final bool isSaveDisabled;
  final bool isCancelDisabled;
  final ButtonStyle? cancelButtonStyle;
  final ButtonStyle? saveButtonStyle;
  final Widget? cancelIcon;
  final Widget? saveIcon;
  final bool expandSaveButton;
  final String? cancelSemanticLabel;
  final String? saveSemanticLabel;

  const MyActionButton({
    super.key,
    required this.cancelLabel,
    required this.saveLabel,
    this.cancelOnPressed,
    this.saveOnPressed,
    this.showCancel = true,
    this.isSaveLoading = false,
    this.isSaveDisabled = false,
    this.isCancelDisabled = false,
    this.cancelButtonStyle,
    this.saveButtonStyle,
    this.cancelIcon,
    this.saveIcon,
    this.expandSaveButton = false,
    this.cancelSemanticLabel,
    this.saveSemanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          if (showCancel) ...[
            const SizedBox(width: 16),
            Expanded(
              flex: expandSaveButton ? 1 : 1,
              child: Semantics(
                label: cancelSemanticLabel ?? cancelLabel,
                button: true,
                child: TextButton.icon(
                  onPressed: isCancelDisabled ? null : cancelOnPressed,
                  style: cancelButtonStyle,
                  icon: cancelIcon ?? const SizedBox.shrink(),
                  label: Text(cancelLabel, style: TextStyle(color: Colors.red)),
                ),
              ),
            ),
          ],
          Expanded(
            flex: expandSaveButton ? 2 : 1,
            child: Semantics(
              label: saveSemanticLabel ?? saveLabel,
              button: true,
              child: TextButton.icon(
                onPressed: (isSaveDisabled || isSaveLoading)
                    ? null
                    : saveOnPressed,
                style: saveButtonStyle,
                icon: saveIcon ?? const SizedBox.shrink(),
                label: isSaveLoading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(saveLabel),
                        ],
                      )
                    : Text(saveLabel),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
