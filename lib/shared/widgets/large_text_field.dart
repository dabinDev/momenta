import 'package:flutter/material.dart';

class LargeTextField extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}
