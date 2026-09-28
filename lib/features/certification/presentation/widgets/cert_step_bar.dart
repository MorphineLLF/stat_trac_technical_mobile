import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The top of a wizard step: its title, and Next on the right.
///
/// Next used to sit at the bottom of each step, under content that did not
/// scroll, and was cut off on smaller phones. Here it never moves — the step's
/// content scrolls beneath it.
///
/// [onNext] null disables Next; [blockedReason] says why, under the title.
/// The reason used to be the button's own label, which a button this size has
/// no room for.
class CertStepBar extends StatelessWidget {
  const CertStepBar({
    super.key,
    required this.title,
    required this.onNext,
    this.blockedReason,
  });

  final String title;
  final VoidCallback? onNext;
  final String? blockedReason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFDDE3EA))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: theme.textTheme.titleLarge),
                  if (blockedReason != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      blockedReason!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: brandError,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // The theme's minimumSize is Size.fromHeight(48) — infinite width.
            // In a Row that throws every frame and the screen freezes, so the
            // width is bounded here.
            FilledButton.icon(
              onPressed: onNext,
              style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
              icon: const Icon(Icons.arrow_forward, size: 18),
              iconAlignment: IconAlignment.end,
              label: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}
