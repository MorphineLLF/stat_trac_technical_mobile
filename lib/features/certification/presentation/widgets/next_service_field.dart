import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_theme.dart';

// ── Next service date ─────────────────────────────────────────────────────────

/// The date the certificate's next service is due.
///
/// **The date shown is the date the register will hold.** The server computes
/// nothing — `TestNextService` is written verbatim and the PM task's schedule
/// date follows it — so a default here is a promise the server keeps, which is
/// why offering one is worth doing rather than leaving an empty box.
class NextServiceField extends StatelessWidget {
  const NextServiceField({
    super.key,
    required this.testDate,
    required this.value,
    required this.onChanged,
  });

  final DateTime testDate;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    // No warning when nothing is chosen: the test date is shown, and the
    // wizard sends that same date, so what is on screen is what lands.
    final label = DateFormat('dd MMM yyyy').format(value ?? testDate);

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFDDE3EA)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? testDate,
            // Never before the test date: the server refuses that, and a
            // picker that allows it hands somebody a rejection they cannot
            // see coming.
            firstDate: testDate,
            lastDate: DateTime(testDate.year + 10),
          );
          if (picked != null) onChanged(picked);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.event_outlined, color: brandTeal),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next Service Due',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: brandGrey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: brandDark,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_calendar_outlined, color: brandGrey),
            ],
          ),
        ),
      ),
    );
  }
}
