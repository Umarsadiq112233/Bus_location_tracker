class Validators {
  const Validators._();

  static String? required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required field' : null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required';
    return text.contains('@') ? null : 'Enter a valid email';
  }
}
