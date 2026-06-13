import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.label,
    required this.icon,
    this.initialValue,
    this.obscureText = false,
  });

  final String label;
  final IconData icon;
  final String? initialValue;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      obscureText: obscureText,
      decoration: InputDecoration(prefixIcon: Icon(icon), labelText: label),
    );
  }
}
