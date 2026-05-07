import '../l10n/l10n.dart';

/// Validator function type alias.
typedef Validator = String? Function(String?);

final _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]{2,30}$');
final _inviteCodeRegex = RegExp(r'^[a-f0-9]{20}$');

/// Returns a localized email validator.
Validator validateEmailL10n(AppLocalizations l10n) => (value) {
  if (value == null || value.isEmpty) return l10n.emailRequired;
  if (!_emailRegex.hasMatch(value)) return l10n.invalidEmailFormat;
  return null;
};

/// Returns a localized username validator.
Validator validateUsernameL10n(AppLocalizations l10n) => (value) {
  if (value == null || value.isEmpty) return l10n.usernameRequired;
  if (!_usernameRegex.hasMatch(value)) return l10n.usernameFormat;
  return null;
};

/// Returns a localized password validator.
Validator validatePasswordL10n(AppLocalizations l10n) => (value) {
  if (value == null || value.isEmpty) return l10n.passwordRequired;
  if (value.length < 8) return l10n.passwordMinLength;
  return null;
};

/// Returns a localized required-field validator.
Validator validateRequiredL10n(AppLocalizations l10n, String fieldName) =>
    (value) {
      if (value == null || value.isEmpty) return l10n.fieldRequired(fieldName);
      return null;
    };

/// Returns a localized invite code validator.
Validator validateInviteCodeL10n(AppLocalizations l10n) => (value) {
  if (value == null || value.trim().isEmpty) return null;
  if (!_inviteCodeRegex.hasMatch(value.trim())) {
    return l10n.invalidInviteCode;
  }
  return null;
};
