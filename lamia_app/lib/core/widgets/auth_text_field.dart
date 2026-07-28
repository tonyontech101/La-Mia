import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// Filled text field matching the design system: label above, prefix icon,
/// optional password show/hide toggle, and a reserved error line below so the
/// layout never jumps when validation messages appear.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.isPassword = false,
    this.errorText,
    this.enabled = true,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool isPassword;
  final String? errorText;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;
  bool _obscured = true;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final iconColor = hasError
        ? AppColors.error
        : _focused
            ? AppColors.primary
            : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppTypography.label()),
        const SizedBox(height: 6),
        Semantics(
          label: widget.label,
          textField: true,
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            obscureText: widget.isPassword && _obscured,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            autofillHints: widget.enabled ? widget.autofillHints : null,
            style: AppTypography.body(),
            cursorColor: AppColors.primary,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            onEditingComplete: widget.onEditingComplete,
            decoration: InputDecoration(
              isDense: false,
              filled: true,
              fillColor: _focused ? AppColors.surface : AppColors.surfaceAlt,
              hintText: widget.hint,
              hintStyle: AppTypography.body(
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
              prefixIcon: Icon(widget.prefixIcon, size: 20, color: iconColor),
              suffixIcon: widget.isPassword
                  ? IconButton(
                      onPressed: () => setState(() => _obscured = !_obscured),
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 22,
                        color: _focused
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      tooltip: _obscured ? 'Show password' : 'Hide password',
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              enabledBorder: _border(AppColors.border, 1),
              focusedBorder: _border(AppColors.primary, 1.5),
              errorBorder: _border(AppColors.error, 1.5),
              focusedErrorBorder: _border(AppColors.error, 1.5),
              disabledBorder: _border(AppColors.border, 1),
            ),
          ),
        ),
        // Reserved error line (scales with text size) to avoid layout jumps.
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.textScalerOf(context).scale(16) + 2,
          ),
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 2, left: 2),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      widget.errorText!,
                      style: AppTypography.caption(color: AppColors.error),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: BorderSide(color: color, width: width),
      );
}
