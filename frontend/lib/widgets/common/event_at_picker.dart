import 'package:flutter/material.dart';
import '../../theme/gleisner_tokens.dart';

/// Date+time picker for post event date ("when did this happen?").
/// Shared between create_post and edit_post screens.
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
              eventAt != null ? _format(eventAt!) : 'Event date (optional)',
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
    final date = await showDatePicker(
      context: context,
      initialDate: eventAt ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: eventAt != null
          ? TimeOfDay(hour: eventAt!.hour, minute: eventAt!.minute)
          : TimeOfDay.now(),
    );
    if (time == null) return;

    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }
}
