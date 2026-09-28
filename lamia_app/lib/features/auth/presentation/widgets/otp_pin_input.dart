import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

/// A 6-digit OTP PIN input widget with individual stylized cells,
/// automatic focus advancement, paste support, and subtle shake animation on error.
class OtpPinInput extends StatefulWidget {
  const OtpPinInput({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.hasError = false,
    this.autoFocus = true,
    this.length = 6,
    this.controller,
    this.focusNode,
  });

  /// Called when all [length] digits have been entered.
  final ValueChanged<String> onCompleted;

  /// Called whenever the entered digits change.
  final ValueChanged<String>? onChanged;

  /// When true, renders cells with error borders and shakes horizontally.
  final bool hasError;

  /// Whether to request keyboard focus automatically on build.
  final bool autoFocus;

  /// Number of OTP digits (defaults to 6).
  final int length;

  /// Optional external controller.
  final TextEditingController? controller;

  /// Optional external focus node.
  final FocusNode? focusNode;

  @override
  State<OtpPinInput> createState() => _OtpPinInputState();
}

class _OtpPinInputState extends State<OtpPinInput>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _internalController = false;
  bool _internalFocusNode = false;

  late final AnimationController _shakeAnimController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _internalController = true;
    }

    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _internalFocusNode = true;
    }

    _shakeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeAnimController, curve: Curves.easeInOut),
    );

    _controller.addListener(_onTextChange);

    if (widget.hasError) {
      _shakeAnimController.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant OtpPinInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasError && !oldWidget.hasError) {
      _shakeAnimController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChange);
    if (_internalController) _controller.dispose();
    if (_internalFocusNode) _focusNode.dispose();
    _shakeAnimController.dispose();
    super.dispose();
  }

  void _onTextChange() {
    final text = _controller.text;
    widget.onChanged?.call(text);
    if (text.length == widget.length) {
      widget.onCompleted(text);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;
    final isFocused = _focusNode.hasFocus;

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final offset = widget.hasError
            ? math.sin(_shakeAnimation.value * math.pi * 4) * 6.0
            : 0.0;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: GestureDetector(
        onTap: () {
          if (!_focusNode.hasFocus) {
            _focusNode.requestFocus();
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Underlying hidden TextField that captures keyboard, paste, and auto-fill
            Positioned.fill(
              child: Opacity(
                opacity: 0.0,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: widget.autoFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.length),
                  ],
                  showCursor: false,
                  enableInteractiveSelection: true,
                ),
              ),
            ),

            // Visually rendered individual OTP cells
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(widget.length, (index) {
                final hasChar = index < text.length;
                final char = hasChar ? text[index] : '';
                final isCurrent = isFocused && index == text.length;

                Color borderColor = AppColors.border;
                Color backgroundColor = AppColors.surfaceAlt.withValues(alpha: 0.5);

                if (widget.hasError) {
                  borderColor = AppColors.error;
                  backgroundColor = AppColors.error.withValues(alpha: 0.05);
                } else if (isCurrent) {
                  borderColor = AppColors.primary;
                  backgroundColor = AppColors.surface;
                } else if (hasChar) {
                  borderColor = AppColors.primary.withValues(alpha: 0.4);
                  backgroundColor = AppColors.surface;
                }

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: 46,
                  height: 54,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(AppRadii.snackbar),
                    border: Border.all(
                      color: borderColor,
                      width: isCurrent || widget.hasError ? 2.0 : 1.2,
                    ),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    char,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: widget.hasError
                          ? AppColors.error
                          : AppColors.textPrimary,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
