import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../domain/register_part.dart';
import '../../domain/work_order_job.dart';
import '../../domain/work_type.dart';
import 'parts_used_section.dart';

/// Step 2 — the desktop's Work Order tab, the fields agreed 2026-10-01.
///
/// Every edit reports a whole new [WorkOrderJob]; the screen owns the value
/// and decides when it is valid. The technician is shown and never editable:
/// the server writes the person it authenticated.
class WorkOrderForm extends StatefulWidget {
  const WorkOrderForm({
    super.key,
    required this.job,
    required this.onChanged,
    required this.technicianName,
    required this.searchParts,
    this.serverError,
  });

  final WorkOrderJob job;
  final ValueChanged<WorkOrderJob> onChanged;
  final String technicianName;

  /// The parts register search, for the picker.
  final Future<List<RegisterPart>> Function(String) searchParts;

  /// The server's refusal, shown under the box it names.
  final WorkOrderFieldError? serverError;

  @override
  State<WorkOrderForm> createState() => _WorkOrderFormState();
}

class _WorkOrderFormState extends State<WorkOrderForm> {
  late final _equipHrs = TextEditingController(text: _num(widget.job.equipHrs));
  late final _nop = TextEditingController(text: _num(widget.job.nop));
  late final _fault = TextEditingController(text: widget.job.fault);
  late final _work = TextEditingController(text: widget.job.work);
  late final _note = TextEditingController(text: widget.job.note);
  late final _client = TextEditingController(text: widget.job.clientName);
  late final _jobCard = TextEditingController(text: widget.job.jobCardNo);

  static String _num(int? n) => n == null ? '' : '$n';

  @override
  void dispose() {
    for (final c in [
      _equipHrs,
      _nop,
      _fault,
      _work,
      _note,
      _client,
      _jobCard,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Built fresh from the boxes rather than copied, so a cleared number box
  /// becomes null rather than keeping its old value.
  void _emit({
    WorkType? workType,
    DateTime? started,
    DateTime? finished,
    List<PartUsed>? parts,
  }) {
    final j = widget.job;
    widget.onChanged(
      WorkOrderJob(
        assetId: j.assetId,
        workType: workType ?? j.workType,
        started: started ?? j.started,
        finished: finished ?? j.finished,
        equipHrs: int.tryParse(_equipHrs.text),
        nop: int.tryParse(_nop.text),
        fault: _fault.text,
        work: _work.text,
        note: _note.text,
        clientName: _client.text,
        jobCardNo: _jobCard.text,
        parts: parts ?? j.parts,
      ),
    );
  }

  String? _errorFor(String field) {
    final e = widget.serverError ?? widget.job.validate();
    return e != null && e.field == field ? e.message : null;
  }

  Future<DateTime?> _pick(DateTime? current) async {
    final base = current ?? DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(base.year - 1),
      lastDate: DateTime(base.year + 1),
    );
    if (day == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return null;
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  Widget _when(
    String label,
    String field,
    DateTime? value,
    ValueChanged<DateTime> set,
  ) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        errorText: _errorFor(field),
      ),
      child: InkWell(
        onTap: () async {
          final picked = await _pick(value);
          if (picked != null) set(picked);
        },
        child: Text(
          value == null
              ? 'Choose'
              : DateFormat('dd MMM yyyy  HH:mm').format(value),
        ),
      ),
    );
  }

  Widget _text(
    String key,
    String label,
    TextEditingController c,
    String field, {
    int? max,
    int lines = 1,
    bool digits = false,
  }) {
    return TextField(
      key: Key(key),
      controller: c,
      maxLength: max,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 2,
      keyboardType: digits ? TextInputType.number : TextInputType.text,
      inputFormatters: digits ? [FilteringTextInputFormatter.digitsOnly] : null,
      textCapitalization: digits
          ? TextCapitalization.none
          : TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        errorText: _errorFor(field),
      ),
      onChanged: (_) => _emit(),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<WorkType>(
          key: const Key('wo-work-type'),
          initialValue: widget.job.workType,
          decoration: InputDecoration(
            labelText: 'Type of work',
            errorText: _errorFor('jobworktype'),
          ),
          items: [
            for (final w in WorkType.values)
              DropdownMenuItem(value: w, child: Text(w.label)),
          ],
          onChanged: (w) => _emit(workType: w),
        ),
        gap,
        _when(
          'Date in / time in',
          'datein',
          widget.job.started,
          (d) => _emit(started: d),
        ),
        gap,
        _when(
          'Date completed / time out',
          'dateout',
          widget.job.finished,
          (d) => _emit(finished: d),
        ),
        gap,
        InputDecorator(
          decoration: const InputDecoration(labelText: 'Technician'),
          child: Text(widget.technicianName),
        ),
        gap,
        _text(
          'wo-hours',
          'Equipment hours',
          _equipHrs,
          'equiphrs',
          max: WorkOrderJob.maxCountDigits,
          digits: true,
        ),
        gap,
        _text(
          'wo-nop',
          'N.O.P',
          _nop,
          'nop',
          max: WorkOrderJob.maxCountDigits,
          digits: true,
        ),
        gap,
        _text(
          'wo-fault',
          'Fault',
          _fault,
          'jobfault',
          max: WorkOrderJob.maxFault,
          lines: 2,
        ),
        _text(
          'wo-work',
          'Work done',
          _work,
          'jobwork',
          max: WorkOrderJob.maxWork,
          lines: 3,
        ),
        _text(
          'wo-note',
          'Notes',
          _note,
          'jobnote',
          max: WorkOrderJob.maxNote,
          lines: 2,
        ),
        _text(
          'wo-client',
          'Client name',
          _client,
          'client',
          max: WorkOrderJob.maxClient,
        ),
        _text(
          'wo-jobcard',
          'Job card no',
          _jobCard,
          'jobcardno',
          max: WorkOrderJob.maxJobCardNo,
        ),
        gap,
        PartsUsedSection(
          parts: widget.job.parts,
          search: widget.searchParts,
          error: widget.serverError ?? widget.job.validate(),
          onChanged: (p) => _emit(parts: p),
        ),
      ],
    );
  }
}
