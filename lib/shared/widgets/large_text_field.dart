import 'package:flutter/material.dart';

class LargeTextField extends StatefulWidget {
  const LargeTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    this.minLines = 1,
    this.maxLines = 1,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.prefixIcon,
    this.autofillHints,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final int minLines;
  final int maxLines;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final IconData? prefixIcon;
  final Iterable<String>? autofillHints;
  final bool enabled;

  @override
  State<LargeTextField> createState() => _LargeTextFieldState();
}

class _LargeTextFieldState extends State<LargeTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  void didUpdateWidget(covariant LargeTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _obscured = widget.obscureText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            widget.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextField(
          controller: widget.controller,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          obscureText: _obscured,
          enabled: widget.enabled,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
          autofillHints: widget.autofillHints,
          cursorColor: theme.colorScheme.primary,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            alignLabelWithHint: widget.maxLines > 1,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(widget.prefixIcon, size: 20),
                  ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 0,
            ),
            suffixIcon: widget.obscureText
                ? IconButton(
                    onPressed: () {
                      setState(() {
                        _obscured = !_obscured;
                      });
                    },
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
