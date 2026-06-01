import '../../domain/entities/test_template_item.dart';

class TestTemplateItemModel extends TestTemplateItem {
  const TestTemplateItemModel({
    required super.id,
    required super.certificateNameId,
    super.descriptionId,
    super.descriptionNo,
    super.description,
    super.notes,
    super.expectedValue,
  });

  factory TestTemplateItemModel.fromMap(Map<String, dynamic> m) =>
      TestTemplateItemModel(
        id: m['id'] as int,
        certificateNameId: m['certificate_name_id'] as int,
        descriptionId: m['description_id'] as String?,
        descriptionNo: m['description_no'] as int?,
        description: m['description'] as String?,
        notes: m['notes'] as String?,
        expectedValue: m['expected_value'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'certificate_name_id': certificateNameId,
        'description_id': descriptionId,
        'description_no': descriptionNo,
        'description': description,
        'notes': notes,
        'expected_value': expectedValue,
      };
}
