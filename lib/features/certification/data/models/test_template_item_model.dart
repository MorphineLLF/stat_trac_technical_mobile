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
    super.actualValueTemplate,
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
        actualValueTemplate: m['actual_value_template'] as String?,
      );

  factory TestTemplateItemModel.fromJson(Map<String, dynamic> j) =>
      TestTemplateItemModel(
        id: j['id'] as int,
        certificateNameId: j['certificate_name_id'] as int,
        descriptionId: j['description_id'] as String?,
        descriptionNo: j['description_no'] as int?,
        description: j['description'] as String?,
        notes: j['notes'] as String?,
        expectedValue: j['expected_value'] as String?,
        actualValueTemplate: j['actual_value_template'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'certificate_name_id': certificateNameId,
        'description_id': descriptionId,
        'description_no': descriptionNo,
        'description': description,
        'notes': notes,
        'expected_value': expectedValue,
        'actual_value_template': actualValueTemplate,
      };
}
