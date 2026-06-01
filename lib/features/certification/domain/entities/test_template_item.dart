import 'package:flutter/foundation.dart';

@immutable
class TestTemplateItem {
  const TestTemplateItem({
    required this.id,
    required this.certificateNameId,
    this.descriptionId,
    this.descriptionNo,
    this.description,
    this.notes,
    this.expectedValue,
    this.actualValueTemplate,
  });

  final int id;
  final int certificateNameId;
  final String? descriptionId;   // section name e.g. "SET-UP"
  final int? descriptionNo;      // section sequence
  final String? description;     // test item label
  final String? notes;
  final String? expectedValue;
  /// `TestTempActualValue` from the server template. Value '-' means no actual
  /// reading is required for this test item.
  final String? actualValueTemplate;

  bool get noActualRequired => actualValueTemplate?.trim() == '-';
}
