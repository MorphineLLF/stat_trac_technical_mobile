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
  });

  final int pmTaskId;
  final int assetId;
  final String description;
  final DateTime? scheduleDate;
  final bool active;
  final String? interval;
  final String? intervalType;
}
