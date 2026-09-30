import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;

import '../../../../core/theme/app_theme.dart';

/// The Actual reading on one test line.
///
/// The normal keyboard, not the number keypad: a reading is sometimes a word,
/// and a numbers-only keypad has no letters at all. An ABC / 123 toggle was
/// tried on 2026-09-30 and did not work on the device, so the user chose the
/// plain keyboard. "TestActualValue" is text on the server, so a word is
/// stored as typed — the certificate chart reports it skipped rather than
/// guessing.
class ActualValueField extends StatelessWidget {
  const ActualValueField({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  final String? initialValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      // Tinted with a grey border: under the theme's #DDE3EA border it
      // vanished into the white card.
      decoration: InputDecoration(
        hintText: 'Actual',
        isDense: true,
        filled: true,
        fillColor: brandTeal.withAlpha(18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: brandGrey, width: 1.5),
        ),
      ),
      keyboardType: TextInputType.text,
      textCapitalization: TextCapitalization.sentences,
      inputFormatters: [LengthLimitingTextInputFormatter(15)],
      onChanged: onChanged,
    );
  }
}
