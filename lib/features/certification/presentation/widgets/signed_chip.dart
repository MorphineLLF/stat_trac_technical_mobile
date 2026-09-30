import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/certificate_summary.dart';

/// TECH SIGNED and CLIENT SIGNED, for whichever signatures a certificate has.
///
/// Two chips rather than one SIGNED — the user's choice, 2026-09-30. Most
/// older certificates carry only the technician's signature, and one chip
/// meaning "the facility signed" left them looking unsigned.
List<Widget> signedChips(CertificateSummary cert, {bool large = false}) => [
  if (cert.isTechSigned) SignedChip(label: 'TECH SIGNED', large: large),
  if (cert.isFacilitySigned) SignedChip(label: 'CLIENT SIGNED', large: large),
];

class SignedChip extends StatelessWidget {
  const SignedChip({super.key, required this.label, this.large = false});

  final String label;

  /// The certificate view's header is larger than a list row.
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 8 : 6,
        vertical: large ? 4 : 2,
      ),
      decoration: BoxDecoration(
        color: brandTeal.withAlpha(25),
        borderRadius: BorderRadius.circular(large ? 6 : 4),
        border: Border.all(color: brandTeal.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.how_to_reg, size: large ? 14 : 12, color: brandTeal),
          SizedBox(width: large ? 4 : 3),
          Text(
            label,
            style: TextStyle(
              color: brandTeal,
              fontSize: large ? 12 : 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
