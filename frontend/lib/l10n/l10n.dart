import 'package:flutter/widgets.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

extension L10nExt on BuildContext {
  AppLocalizations get l10n {
    final localizations = AppLocalizations.of(this);
    assert(
      localizations != null,
      'AppLocalizations not found in context. '
      'Ensure AppLocalizations.delegate is in localizationsDelegates.',
    );
    return localizations ?? lookupAppLocalizations(const Locale('en'));
  }
}
