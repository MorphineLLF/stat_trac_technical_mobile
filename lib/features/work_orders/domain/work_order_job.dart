import 'part_used.dart';
import 'work_type.dart';

export 'part_used.dart';

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
/// stops a technician finishing a job that was fine. The one exception is the
/// nine-digit cap on hours and N.O.P — see [validate].
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
    this.parts = const [],
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

  /// Parts used, in the order the technician added them.
  final List<PartUsed> parts;

  static const maxJobCardNo = 30;
  static const maxClient = 50;
  static const maxFault = 200;
  static const maxWork = 200;
  static const maxNote = 100;

  /// Equipment hours and N.O.P: nine digits, inside a Postgres `integer`.
  static const maxCount = 999999999;
  static const maxCountDigits = 9;

  WorkOrderFieldError? validate() {
    if (workType == null) {
      return const WorkOrderFieldError(
        'jobworktype',
        'Choose the type of work',
      );
    }
    if (started == null) {
      return const WorkOrderFieldError('datein', 'The date in is needed');
    }
    if (finished == null) {
      return const WorkOrderFieldError(
        'dateout',
        'The date completed is needed',
      );
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
    // The one check the server does not make. It refuses only a negative;
    // anything past the database's integer column fails the insert as a 500,
    // which the outbox reads as no signal — and the job then blocks every
    // upload behind it for ever. Nine digits is the form's limit too.
    if ((equipHrs ?? 0) > maxCount) {
      return const WorkOrderFieldError(
        'equiphrs',
        'Equipment hours is too large',
      );
    }
    if ((nop ?? 0) > maxCount) {
      return const WorkOrderFieldError('nop', 'N.O.P is too large');
    }
    for (final (field, label, value, max) in [
      ('jobcardno', 'The job card no', jobCardNo, maxJobCardNo),
      ('client', 'The client', clientName, maxClient),
      ('jobfault', 'The fault', fault, maxFault),
      ('jobwork', 'Work done', work, maxWork),
      ('jobnote', 'Comments', note, maxNote),
    ]) {
      if (value.trim().runes.length > max) {
        return WorkOrderFieldError(
          field,
          '$label is longer than $max characters',
        );
      }
    }
    for (var i = 0; i < parts.length; i++) {
      final p = parts[i];
      if (p.partNo.trim().runes.length > PartUsed.maxPartNo) {
        return WorkOrderFieldError(
          'parts[$i].part_no',
          'The item code is longer than ${PartUsed.maxPartNo} characters',
        );
      }
      if (p.description.trim().runes.length > PartUsed.maxDescription) {
        return WorkOrderFieldError(
          'parts[$i].description',
          'The description is longer than ${PartUsed.maxDescription} characters',
        );
      }
      if (!p.picked &&
          p.partNo.trim().isEmpty &&
          p.description.trim().isEmpty) {
        return WorkOrderFieldError(
          'parts[$i].description',
          'A part needs an item code or a description',
        );
      }
      if (p.qty <= 0) {
        return WorkOrderFieldError(
          'parts[$i].qty',
          'A part needs a quantity above nought',
        );
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
    if (parts.isNotEmpty) 'parts': [for (final p in parts) p.toWire()],
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
    parts: [
      for (final p in (w['parts'] as List?) ?? const [])
        PartUsed.fromWire(Map<String, Object?>.from(p as Map)),
    ],
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
    List<PartUsed>? parts,
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
    parts: parts ?? this.parts,
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
