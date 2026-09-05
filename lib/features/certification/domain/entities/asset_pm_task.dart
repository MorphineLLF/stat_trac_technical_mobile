import 'package:flutter/foundation.dart';

@immutable
class AssetPmTask {
  const AssetPmTask({
    required this.pmTaskId,
    required this.assetId,
    required this.description,
    this.scheduleDate,
    required this.active,
    this.interval,
    this.intervalType,
    this.taskType,
  });

  final int pmTaskId;
  final int assetId;
  final String description;
  final DateTime? scheduleDate;
  final bool active;
  final String? interval;
  final String? intervalType;

  /// `PmTaskType` — 1 dated, 2 meter-based.
  final int? taskType;

  /// A meter-based task comes round on readings rather than on months, so no
  /// interval arithmetic applies to it.
  ///
  /// The server refuses to propose a next-service date for one — its
  /// `NextServiceProposal` returns false — and the technician has to be asked
  /// instead. The old Delphi app had no branch for this and offered whatever
  /// was left in the date picker, which is the bug this distinction exists to
  /// avoid repeating.
  bool get isMeterBased => taskType == 2;
}
