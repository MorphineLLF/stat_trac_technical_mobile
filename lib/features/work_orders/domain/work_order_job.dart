import 'work_type.dart';

/// What is wrong with a job card, named as the server names it.
class WorkOrderFieldError {
  const WorkOrderFieldError(this.field, this.message);

  /// The server's `ValidationError` field — the form maps it to a box.
  final String field;
  final String message;
}

/// The Work Order tab of a captured job: what the technician fills in.
///
/// **The checks are the server's, word for word** (`JobCardInput.Validate`,
/// captured), and never stricter: a device check the server would not make
/// stops a technician finishing a job that was fine.
class WorkOrderJob {
  const WorkOrderJob({
    required this.assetId,
    this.workType,
    this.started,
    this.finished,
    this.equipHrs,
    this.nop,
    this.fault = '',
    this.work = '',
    this.note = '',
    this.clientName = '',
    this.jobCardNo = '',
  });

  final int assetId;

  /// No default. A default is filed as though somebody chose it.
  final WorkType? workType;

  /// Date in and time in.
  final DateTime? started;

  /// Date completed and time out. Saving a capture completes the work order,
  /// so the card is the whole record of the job.
  final DateTime? finished;

  final int? equipHrs;

  /// N.O.P, as the desktop labels it.
  final int? nop;

  final String fault;
  final String work;
  final String note;
  final String clientName;
  final String jobCardNo;

  static const maxJobCardNo = 30;
  static const maxClient = 50;
  static const maxFault = 200;
  static const maxWork = 200;
  static const maxNote = 100;

  WorkOrderFieldError? validate() {
    if (workType == null) {
      return const WorkOrderFieldError('jobworktype', 'Choose the type of work');
    }
    if (started == null) {
      return const WorkOrderFieldError('datein', 'The date in is needed');
    }
    if (finished == null) {
      return const WorkOrderFieldError('dateout', 'The date completed is needed');
    }
    // Dates, not times — the server compares the two dates only.
    if (_day(finished!).isBefore(_day(started!))) {
      return const WorkOrderFieldError(
        'dateout',
        'The date completed is before the date in',
      );
    }
    if ((equipHrs ?? 0) < 0) {
      return const WorkOrderFieldError(
        'equiphrs',
        'Equipment hours cannot be negative',
      );
    }
    for (final (field, label, value, max) in [
      ('jobcardno', 'The job card no', jobCardNo, maxJobCardNo),
      ('client', 'The client', clientName, maxClient),
      ('jobfault', 'The fault', fault, maxFault),
      ('jobwork', 'Work done', work, maxWork),
      ('jobnote', 'Comments', note, maxNote),
    ]) {
      if (value.trim().runes.length > max) {
        return WorkOrderFieldError(field, '$label is longer than $max characters');
      }
    }
    return null;
  }

  /// The `data` of the capture op. Call only on a job that validates.
  Map<String, Object?> toWire() => {
    'asset_id': assetId,
    'work_type': workType!.code,
    'date_in': _date(started!),
    'time_in': _time(started!),
    'date_out': _date(finished!),
    'time_out': _time(finished!),
    if (equipHrs != null) 'equip_hrs': equipHrs,
    if (nop != null) 'nop': nop,
    'fault': fault.trim(),
    'work': work.trim(),
    'note': note.trim(),
    'client_name': clientName.trim(),
    'job_card_no': jobCardNo.trim(),
  };

  /// Back from a queued payload, for the Worklist and for Fix and resend.
  factory WorkOrderJob.fromWire(Map<String, Object?> w) => WorkOrderJob(
    assetId: (w['asset_id']! as num).toInt(),
    workType: WorkType.fromCode((w['work_type'] as num?)?.toInt()),
    started: _parse(w['date_in'], w['time_in']),
    finished: _parse(w['date_out'], w['time_out']),
    equipHrs: (w['equip_hrs'] as num?)?.toInt(),
    nop: (w['nop'] as num?)?.toInt(),
    fault: w['fault'] as String? ?? '',
    work: w['work'] as String? ?? '',
    note: w['note'] as String? ?? '',
    clientName: w['client_name'] as String? ?? '',
    jobCardNo: w['job_card_no'] as String? ?? '',
  );

  WorkOrderJob copyWith({
    WorkType? workType,
    DateTime? started,
    DateTime? finished,
    int? equipHrs,
    int? nop,
    String? fault,
    String? work,
    String? note,
    String? clientName,
    String? jobCardNo,
  }) => WorkOrderJob(
    assetId: assetId,
    workType: workType ?? this.workType,
    started: started ?? this.started,
    finished: finished ?? this.finished,
    equipHrs: equipHrs ?? this.equipHrs,
    nop: nop ?? this.nop,
    fault: fault ?? this.fault,
    work: work ?? this.work,
    note: note ?? this.note,
    clientName: clientName ?? this.clientName,
    jobCardNo: jobCardNo ?? this.jobCardNo,
  );

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

  static String _time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  static DateTime? _parse(Object? date, Object? time) {
    if (date is! String) return null;
    return DateTime.tryParse('${date}T${time is String ? time : '00:00'}');
  }
}
