final _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,30}$');

String? validateEmail(String? value) {
  if (value == null || value.isEmpty) return 'Email is required';
  if (!_emailRegex.hasMatch(value)) return 'Invalid email format';
  return null;
}

String? validateUsername(String? value) {
  if (value == null || value.isEmpty) return 'Username is required';
  if (!_usernameRegex.hasMatch(value)) {
    return 'Letters, numbers, underscores (3-30 chars)';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Password is required';
  if (value.length < 8) return 'At least 8 characters';
  return null;
}

String? validateRequired(String? value, String fieldName) {
  if (value == null || value.isEmpty) return '$fieldName is required';
  return null;
}
