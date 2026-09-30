import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The result of one test line.
enum TestResult {
  pass('Pass', Color(0xFF2E7D32)),
  fail('Fail', Color(0xFFC62828)),
  na('N/A', Color(0xFF37474F));

  const TestResult(this.label, this.color);
  final String label;
  final Color color;
}

/// Pass / Fail / N/A as radio buttons in a row — option B of the mockup the
/// user chose on 2026-09-30, replacing the filled chips.
///
/// A radio: tapping the chosen option does nothing. The chips toggled off on
/// a second tap, which is how a line could be un-marked; now a line marked by
/// mistake is changed to the right answer, not cleared.
///
/// With [onSelected] null the row is read-only — the certificate view shows
/// the same radios the technician chose from.
class ResultRadioRow extends StatelessWidget {
  const ResultRadioRow({
    super.key,
    required this.value,
    required this.onSelected,
  });

  final TestResult? value;
  final ValueChanged<TestResult>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final r in TestResult.values)
          _ResultRadio(
            result: r,
            selected: value == r,
            readOnly: onSelected == null,
            onTap: value == r || onSelected == null
                ? null
                : () => onSelected!(r),
          ),
      ],
    );
  }
}

class _ResultRadio extends StatelessWidget {
  const _ResultRadio({
    required this.result,
    required this.selected,
    required this.readOnly,
    required this.onTap,
  });

  final TestResult result;
  final bool selected;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = result.color;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: !readOnly,
      onTap: readOnly ? null : onTap ?? () {},
      excludeSemantics: true,
      label: result.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? color : brandGrey,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 150),
                  scale: selected ? 1 : 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                result.label,
                style: TextStyle(
                  fontSize: 14,
                  color: selected ? color : brandDark,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
