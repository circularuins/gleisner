import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

/// Returns the abbreviated month name (e.g. "Jan" / "1月") for [month] (1–12).
///
/// Uses [intl.DateFormat('MMM')] with the current locale so that Japanese
/// returns "1月"–"12月" and English returns "Jan"–"Dec".
String monthShort(BuildContext context, int month) {
  final locale = Localizations.localeOf(context).languageCode;
  final date = DateTime(2000, month);
  return DateFormat('MMM', locale).format(date);
}

/// Returns the full month name (e.g. "January" / "1月") for [month] (1–12)
/// from the ARB translations.
String monthFull(BuildContext context, int month) {
  final l10n = AppLocalizations.of(context)!;
  switch (month) {
    case 1:
      return l10n.monthJanuary;
    case 2:
      return l10n.monthFebruary;
    case 3:
      return l10n.monthMarch;
    case 4:
      return l10n.monthApril;
    case 5:
      return l10n.monthMay;
    case 6:
      return l10n.monthJune;
    case 7:
      return l10n.monthJuly;
    case 8:
      return l10n.monthAugust;
    case 9:
      return l10n.monthSeptember;
    case 10:
      return l10n.monthOctober;
    case 11:
      return l10n.monthNovember;
    case 12:
      return l10n.monthDecember;
    default:
      return '';
  }
}
