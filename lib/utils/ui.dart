import 'package:flutter/material.dart';

InputDecoration inputDecoration(BuildContext context) {
  final theme = Theme.of(context);
  final defaults = theme.inputDecorationTheme;
  return InputDecoration(
    filled: defaults.filled,
    fillColor: defaults.fillColor,
    border: defaults.border,
    enabledBorder: defaults.enabledBorder,
    focusedBorder: defaults.focusedBorder,
    contentPadding: defaults.contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}
