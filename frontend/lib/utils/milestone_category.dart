import 'package:flutter/material.dart';

/// Milestone category metadata — shared between artist page and edit sheet.
const milestoneCategories = [
  ('award', 'Award', Icons.emoji_events),
  ('release', 'Release', Icons.album),
  ('event', 'Event', Icons.event),
  ('affiliation', 'Affiliation', Icons.groups),
  ('education', 'Education', Icons.school),
  ('other', 'Other', Icons.star_outline),
];

IconData milestoneCategoryIcon(String category) {
  for (final (key, _, icon) in milestoneCategories) {
    if (key == category) return icon;
  }
  return Icons.star_outline;
}
