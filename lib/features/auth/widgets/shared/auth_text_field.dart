import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AuthTextField extends StatelessWidget {
  final String placeholder;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? errorText;
  final void Function(String)? onChanged;
  final TextEditingController? controller;

  const AuthTextField({
    super.key,
    required this.placeholder,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.errorText,
    this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: errorText != null
                  ? theme.colorScheme.error
                  : theme.colorScheme.outline,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          placeholderStyle: TextStyle(
            color: theme.colorScheme.onSurface.withAlpha(128),
          ),
          style: TextStyle(
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: TextStyle(
              color: theme.colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
