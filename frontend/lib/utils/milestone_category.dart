import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Milestone category keys and their icons.
const milestoneCategoryIcons = <String, IconData>{
  'award': Icons.emoji_events,
  'release': Icons.album,
  'event': Icons.event,
  'affiliation': Icons.groups,
  'education': Icons.school,
  'other': Icons.star_outline,
};

/// All category keys in display order.
const milestoneCategoryKeys = [
  'award',
  'release',
  'event',
  'affiliation',
  'education',
  'other',
];

/// Localized display name for a milestone category.
String milestoneCategoryName(BuildContext context, String category) {
  final l10n = context.l10n;
  return switch (category) {
    'award' => l10n.milestoneCategoryAward,
    'release' => l10n.milestoneCategoryRelease,
    'event' => l10n.milestoneCategoryEvent,
    'affiliation' => l10n.milestoneCategoryAffiliation,
    'education' => l10n.milestoneCategoryEducation,
    'other' => l10n.milestoneCategoryOther,
    _ => category,
  };
}

IconData milestoneCategoryIcon(String category) {
  return milestoneCategoryIcons[category] ?? Icons.star_outline;
}
