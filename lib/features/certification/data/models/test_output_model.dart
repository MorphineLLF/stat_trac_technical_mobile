import '../../domain/entities/test_output.dart';

class TestOutputModel extends TestOutput {
  const TestOutputModel({
    required super.id,
    required super.certificateId,
    super.assetId,
    super.descriptionId,
    super.description,
    super.expectedValue,
    super.actualValue,
    super.notes,
    super.pass,
    super.fail,
    super.na,
  });

  factory TestOutputModel.fromMap(Map<String, dynamic> m) => TestOutputModel(
        id: m['id'] as int,
        certificateId: m['certificate_id'] as int,
        assetId: m['asset_id'] as int?,
        descriptionId: m['description_id'] as String?,
        description: m['description'] as String?,
        expectedValue: m['expected_value'] as String?,
        actualValue: m['actual_value'] as String?,
        notes: m['notes'] as String?,
        pass: (m['pass'] as int? ?? 0) == 1,
        fail: (m['fail'] as int? ?? 0) == 1,
        na: (m['na'] as int? ?? 0) == 1,
      );

  factory TestOutputModel.fromJson(Map<String, dynamic> j, {int certificateId = 0}) =>
      TestOutputModel(
        id: 0,
        certificateId: certificateId,
        descriptionId: j['description_id'] as String?,
        description: j['description'] as String?,
        expectedValue: j['expected_value'] as String?,
        actualValue: j['actual_value'] as String?,
        notes: j['notes'] as String?,
        pass: j['pass'] as bool? ?? false,
        fail: j['fail'] as bool? ?? false,
        na: j['na'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'certificate_id': certificateId,
        'asset_id': assetId,
        'description_id': descriptionId,
        'description': description,
        'expected_value': expectedValue,
        'actual_value': actualValue,
        'notes': notes,
        'pass': pass ? 1 : 0,
        'fail': fail ? 1 : 0,
        'na': na ? 1 : 0,
      };
}
