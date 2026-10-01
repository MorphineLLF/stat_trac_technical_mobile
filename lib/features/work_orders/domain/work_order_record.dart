import 'work_type.dart';

/// A synced work order, as the detail screen shows it.
class WorkOrderRecord {
  const WorkOrderRecord({
    required this.trackId,
    this.mobileId,
    this.assetId,
    this.workType,
    required this.status,
    this.started,
    this.finished,
    this.equipHrs,
    this.nop,
    this.fault = '',
    this.work = '',
    this.note = '',
    this.clientName = '',
    this.jobCardNo = '',
    this.tech = '',
  });

  final int trackId;
  final String? mobileId;
  final int? assetId;
  final WorkType? workType;
  final String status;
  final DateTime? started;
  final DateTime? finished;
  final int? equipHrs;
  final int? nop;
  final String fault;
  final String work;
  final String note;
  final String clientName;
  final String jobCardNo;
  final String tech;
}
