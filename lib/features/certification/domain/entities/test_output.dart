import 'package:flutter/foundation.dart';

@immutable
class TestOutput {
  const TestOutput({
    required this.id,
    required this.certificateId,
    this.assetId,
    this.descriptionId,
    this.description,
    this.expectedValue,
    this.actualValue,
    this.notes,
    this.pass = false,
    this.fail = false,
    this.na = false,
  });

  final int id;
  final int certificateId;
  final int? assetId;
  final String? descriptionId;
  final String? description;
  final String? expectedValue;
  final String? actualValue;
  final String? notes;
  final bool pass;
  final bool fail;
  final bool na;

  TestOutput copyWith({
    String? actualValue,
    String? notes,
    bool? pass,
    bool? fail,
    bool? na,
  }) => TestOutput(
    id: id,
    certificateId: certificateId,
    assetId: assetId,
    descriptionId: descriptionId,
    description: description,
    expectedValue: expectedValue,
    actualValue: actualValue ?? this.actualValue,
    notes: notes ?? this.notes,
    pass: pass ?? this.pass,
    fail: fail ?? this.fail,
    na: na ?? this.na,
  );
}
