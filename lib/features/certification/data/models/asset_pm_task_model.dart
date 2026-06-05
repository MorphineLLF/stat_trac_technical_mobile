import '../../domain/entities/asset_pm_task.dart';

class AssetPmTaskModel extends AssetPmTask {
  const AssetPmTaskModel({
    required super.pmTaskId,
    required super.assetId,
    required super.description,
    super.scheduleDate,
    required super.active,
    super.interval,
    super.intervalType,
  });

  factory AssetPmTaskModel.fromJson(Map<String, dynamic> j) => AssetPmTaskModel(
    pmTaskId: j['pm_task_id'] as int,
    assetId: j['asset_id'] as int,
    description: j['description'] as String? ?? '',
    scheduleDate: j['schedule_date'] != null
        ? DateTime.tryParse(j['schedule_date'] as String)
        : null,
    active: (j['active'] as int? ?? 1) == 1,
    interval: j['interval'] as String?,
    intervalType: j['interval_type'] as String?,
  );

  factory AssetPmTaskModel.fromMap(Map<String, dynamic> m) => AssetPmTaskModel(
    pmTaskId: m['pm_task_id'] as int,
    assetId: m['asset_id'] as int,
    description: m['description'] as String,
    scheduleDate: m['schedule_date'] != null
        ? DateTime.tryParse(m['schedule_date'] as String)
        : null,
    active: (m['active'] as int? ?? 1) == 1,
    interval: m['interval'] as String?,
    intervalType: m['interval_type'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'pm_task_id': pmTaskId,
    'asset_id': assetId,
    'description': description,
    'schedule_date': scheduleDate?.toIso8601String().substring(0, 10),
    'active': active ? 1 : 0,
    'interval': interval,
    'interval_type': intervalType,
  };
}
