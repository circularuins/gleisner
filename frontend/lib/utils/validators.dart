final _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]{2,30}$');

String? validateEmail(String? value) {
  if (value == null || value.isEmpty) return 'Email is required';
  if (!_emailRegex.hasMatch(value)) return 'Invalid email format';
  return null;
}

String? validateUsername(String? value) {
  if (value == null || value.isEmpty) return 'Username is required';
  if (!_usernameRegex.hasMatch(value)) {
    return 'Letters, numbers, underscores (2-30 chars)';
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

final _inviteCodeRegex = RegExp(r'^[a-f0-9]{20}$');

/// Validates an invite code. Returns null if valid or empty (optional field).
String? validateInviteCode(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  if (!_inviteCodeRegex.hasMatch(value.trim())) {
    return 'Invalid invite code format';
  }
  return null;
}
