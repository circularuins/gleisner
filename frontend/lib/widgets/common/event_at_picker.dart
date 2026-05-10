import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../theme/gleisner_tokens.dart';

/// Date+time picker for post event date ("when did this happen?").
/// Shared between create_post and edit_post screens.
///
/// Timezone contract:
/// - [eventAt] may arrive as either a UTC `DateTime` (e.g. parsed from a
///   `Z`-suffixed ISO string returned by the backend) or a local
///   `DateTime`. The widget always calls `.toLocal()` internally for
///   display and for picker initial values, so callers can pass either.
/// - [onChanged] always emits a *local* `DateTime` (`isUtc == false`),
///   reflecting what the user picked in their wall-clock time.
///   **Callers that send the value to the backend MUST call `.toUtc()`
///   before serializing**, otherwise `toIso8601String()` produces a
///   naive (offset-less) string that the server parses as its own local
///   time. Provider-layer `updatePost` / `submit` methods now accept
///   `DateTime?` and handle this conversion centrally — prefer that
///   over passing pre-serialized strings around.
class EventAtPicker extends StatelessWidget {
  final DateTime? eventAt;
  final ValueChanged<DateTime?> onChanged;

  const EventAtPicker({super.key, this.eventAt, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.event,
          size: 20,
          color: eventAt != null ? colorAccentGold : colorTextMuted,
        ),
        const SizedBox(width: spaceSm),
        Expanded(
          child: GestureDetector(
            onTap: () => _pickDateTime(context),
            child: Text(
              eventAt != null
                  ? _format(eventAt!.toLocal())
                  : context.l10n.eventDateOptional,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: eventAt != null ? colorTextPrimary : colorTextMuted,
              ),
            ),
          ),
        ),
        if (eventAt != null)
          IconButton(
            icon: const Icon(Icons.clear, size: 18, color: colorTextMuted),
            onPressed: () => onChanged(null),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  String _format(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $h:$min';
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    // Always operate on local-zone wall-clock time, regardless of whether
    // the incoming `eventAt` is UTC or local. See class doc.
    final localEventAt = eventAt?.toLocal();
    final date = await showDatePicker(
      context: context,
      initialDate: localEventAt ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: localEventAt != null
          ? TimeOfDay(hour: localEventAt.hour, minute: localEventAt.minute)
          : TimeOfDay.now(),
    );
    if (time == null) return;

    // `DateTime(...)` (no `.utc`) returns a naive local DateTime — caller
    // must `.toUtc()` before serializing.
    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }
}
