import '../../data/models/certificate_summary.dart';

/// Whether a certificate matches what the technician typed.
///
/// Matched in memory rather than in SQL, deliberately: the list is already
/// loaded and bounded, and a technician searching in a hospital basement has
/// no server to ask. Filtering what is on the device works with no signal,
/// which is the condition this app is built for.
///
/// Everything a person would plausibly remember is searchable — the facility
/// they were standing in, the certificate number the office quotes, the
/// equipment, and the template's name.
bool certificateMatchesSearch(CertificateSummary cert, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }

  final haystack = <String?>[
    cert.hospital,
    cert.certificateNo?.toString(),
    cert.equipmentType,
    cert.certName,
    cert.templateName,
    cert.pmTaskDescription,
  ];

  for (final field in haystack) {
    if (field != null && field.toLowerCase().contains(needle)) {
      return true;
    }
  }
  return false;
}
