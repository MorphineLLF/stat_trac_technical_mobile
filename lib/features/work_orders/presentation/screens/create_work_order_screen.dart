import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../sync/powersync_providers.dart';
import '../../../../sync/upload/upload_providers.dart';
import '../../../../sync/upload/upload_run_message.dart';
import '../../../../sync/upload/upload_worker.dart';
import '../../../../sync/upload/work_order_upload.dart';
import '../../../assets/data/powersync_asset_data_source.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/presentation/widgets/asset_picker_dialog.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../../certification/presentation/widgets/cert_signature_step.dart';
// The certificate wizard's precedent: the dashboard's counts are refreshed by
// the screen that changed them.
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../domain/work_order_job.dart';
import '../providers/work_order_providers.dart';
import '../widgets/work_order_form.dart';

/// What Save tells the technician. The job is in the outbox either way; the
/// send that follows decides the sentence. **A job that went straight away
/// says so** — "waiting to sync" over a job already sent had the technician
/// looking for a count that was rightly 0. Only "nothing was sent" keeps the
/// plain message.
String workOrderSaveMessage(UploadRunMessage? run) =>
    run == null || run.tone == UploadMessageTone.quiet
    ? 'Saved — waiting to sync'
    : run.text;

/// Capture on site, in three steps: the machine, the Work Order tab, both
/// signatures. Nothing is written until Save, and Save writes only to the
/// outbox — the server raises and completes the work order when it arrives.
///
/// With [resend] it reopens a job the server set aside: same mobile id, same
/// machine, same signatures, starting at the form with the server's complaint
/// under the box it named.
class CreateWorkOrderScreen extends ConsumerStatefulWidget {
  const CreateWorkOrderScreen({
    super.key,
    this.resend,
    this.resendField,
    this.resendMessage,
  });

  final WorkOrderUpload? resend;
  final String? resendField;
  final String? resendMessage;

  @override
  ConsumerState<CreateWorkOrderScreen> createState() =>
      _CreateWorkOrderScreenState();
}

class _CreateWorkOrderScreenState extends ConsumerState<CreateWorkOrderScreen> {
  late final String _mobileId = widget.resend?.mobileId ?? const Uuid().v4();
  int _step = 0;
  Asset? _asset;
  WorkOrderJob? _job;
  WorkOrderFieldError? _serverError;
  bool _saving = false;

  /// Bumped when the machine changes, so the form starts again from the new
  /// job rather than showing the old machine's boxes.
  int _formGeneration = 0;

  /// The signature step is kept alive once reached: going back to correct the
  /// card must not throw away signatures somebody has already drawn.
  bool _signReached = false;

  @override
  void initState() {
    super.initState();
    final resend = widget.resend;
    if (resend != null) {
      _job = WorkOrderJob.fromWire(resend.capture);
      _step = 1;
      if (widget.resendField != null && widget.resendMessage != null) {
        _serverError = WorkOrderFieldError(
          widget.resendField!,
          widget.resendMessage!,
        );
      }
    }
  }

  String get _techName {
    final auth = ref.read(authProvider);
    return auth is AuthAuthenticated ? auth.user.name : '';
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickMachine() async {
    final ds = PowerSyncAssetDataSource(
      await ref.read(syncDatabaseProvider.future),
    );
    if (!mounted) return;
    final asset = await showAssetPicker(context, ds);
    if (!mounted || asset == null || asset.assetId == null) return;
    // The hours are a convenience. A machine whose detail cannot be read is
    // still the machine the technician chose.
    int? hours;
    try {
      hours = (await ds.getAssetDetail(asset.assetId!))?.hours;
    } catch (e) {
      debugPrint('[work-order] asset detail unavailable: $e');
    }
    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      _asset = asset;
      _job = WorkOrderJob(
        assetId: asset.assetId!,
        started: now,
        finished: now,
        equipHrs: hours,
      );
      _formGeneration++;
      // Signatures given against another machine are not this job's.
      _signReached = false;
    });
  }

  Future<void> _save({
    required String techPng,
    required String clientPng,
    required String clientName,
  }) async {
    if (_saving) return;
    final name = clientName.trim();
    if (name.isEmpty) {
      _say(
        'Add the client contact name — the signature cannot be sent '
        'without it',
      );
      return;
    }
    // The name signed against is the name on the card, and it is checked as
    // the card is: refused here, while the client is still in the room,
    // rather than by the server after they have gone.
    final job = _job!.copyWith(clientName: name);
    final problem = job.validate();
    if (problem != null) {
      _say(problem.message);
      return;
    }
    setState(() => _saving = true);

    try {
      final upload = WorkOrderUpload(
        mobileId: _mobileId,
        capture: job.toWire(),
        techPng: techPng,
        clientPng: clientPng,
        clientName: name,
      );
      final queue = await ref.read(uploadQueueProvider.future);
      // Replaces a set-aside row under the same id rather than adding one.
      await queue.enqueue(upload);
    } catch (e) {
      // Nothing reached the outbox. Everything is still on this screen, so
      // the technician can simply press Save again.
      debugPrint('[work-order] outbox write failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      _say('Could not save — try again. Nothing was lost on this screen.');
      return;
    }
    if (!mounted) return;
    ref.invalidate(worklistProvider);
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(pendingUploadCountProvider);

    UploadRunResult? result;
    try {
      result = await (await ref.read(uploadWorkerProvider.future)).drain();
    } catch (e) {
      debugPrint('[upload] send after work order save failed: $e');
    }
    if (!mounted) return;
    ref.invalidate(worklistProvider);
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(pendingUploadCountProvider);

    _say(
      workOrderSaveMessage(result == null ? null : describeUploadRun(result)),
    );
    Navigator.of(context).pop();
  }

  /// Back steps back. Only the first step leaves, and it asks once a machine
  /// has been chosen: nothing is written until Save, so leaving a started card
  /// throws all of it away. A resend, which has no first step, asks too,
  /// because leaving abandons the fix.
  Future<void> _back() async {
    if (_step == 2) {
      setState(() => _step = 1);
      return;
    }
    if (_step == 1 && widget.resend == null) {
      setState(() => _step = 0);
      return;
    }
    final resend = widget.resend != null;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          resend ? 'Leave without resending?' : 'Leave without saving?',
        ),
        content: Text(
          resend
              ? 'The work order stays set aside. Your changes here are not '
                    'kept.'
              : 'This work order has not been saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Navigator.pop (Save, Leave) is not stopped by canPop — only the back
    // gesture and the AppBar arrow are, and those step back instead. The
    // first step leaves freely only while nothing has been started.
    return PopScope(
      canPop: _step == 0 && _job == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.resend == null ? 'New Work Order' : 'Fix and resend',
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  'Step ${_step + 1} of 3 — '
                  '${const ['Machine', 'Work order', 'Signatures'][_step]}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Expanded(
                // Every reached step stays mounted, so stepping back keeps
                // the boxes and the drawn signatures as they were.
                child: IndexedStack(
                  index: _step,
                  children: [
                    widget.resend == null
                        ? _machineStep()
                        : const SizedBox.shrink(),
                    _job == null ? const SizedBox.shrink() : _formStep(),
                    _signReached ? _signStep() : const SizedBox.shrink(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _machineStep() {
    final asset = _asset;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(
          onPressed: _pickMachine,
          icon: const Icon(Icons.precision_manufacturing_outlined),
          label: Text(asset == null ? 'Choose machine' : 'Change machine'),
        ),
        if (asset != null) ...[
          const SizedBox(height: 12),
          Text(
            asset.displayName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            [
              asset.serialNumber,
              asset.hospital,
            ].whereType<String>().join(' · '),
          ),
          const SizedBox(height: 12),
          _OpenRepairWarning(assetId: asset.assetId!),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => setState(() => _step = 1),
            child: const Text('Next'),
          ),
        ],
      ],
    );
  }

  Widget _formStep() {
    final job = _job!;
    final valid = job.validate() == null;
    return Column(
      children: [
        Expanded(
          child: WorkOrderForm(
            key: ValueKey(_formGeneration),
            job: job,
            technicianName: _techName,
            serverError: _serverError,
            onChanged: (j) => setState(() {
              _job = j;
              // The server's complaint stands until the box it named changes.
              if (_serverError != null &&
                  _changed(_serverError!.field, job, j)) {
                _serverError = null;
              }
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: valid
                ? () => setState(() {
                    _step = 2;
                    _signReached = true;
                  })
                : null,
            child: const Text('Next'),
          ),
        ),
      ],
    );
  }

  Widget _signStep() {
    final resend = widget.resend;
    if (resend != null) {
      // A set-aside job was signed when it was captured. The client may be
      // long gone; the signatures stand. The name is the card's as corrected:
      // fixing how a name is written does not change who signed.
      final name = _job!.clientName.trim();
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified_outlined, color: brandTeal),
              title: const Text('Signatures kept'),
              subtitle: Text('Signed by the technician and $name'),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving
                ? null
                : () => _save(
                    techPng: resend.techPng,
                    clientPng: resend.clientPng,
                    clientName: name,
                  ),
            child: const Text('Save work order'),
          ),
        ],
      );
    }
    return CertSignatureStep(
      requiresCustomerSig: true,
      clientLabel: 'Client',
      submitLabel: 'Save work order',
      initialClientName: _job!.clientName,
      clientNameMaxLength: WorkOrderJob.maxClient,
      onSigned: (s) => _save(
        techPng: base64Encode(s.techSignatureBytes),
        clientPng: base64Encode(s.clientSignatureBytes!),
        clientName: s.clientName!,
      ),
    );
  }

  static bool _changed(String field, WorkOrderJob a, WorkOrderJob b) =>
      switch (field) {
        'jobworktype' => a.workType != b.workType,
        'datein' || 'timein' => a.started != b.started,
        'dateout' || 'timeout' => a.finished != b.finished,
        'equiphrs' => a.equipHrs != b.equipHrs,
        'nop' => a.nop != b.nop,
        'jobfault' => a.fault != b.fault,
        'jobwork' => a.work != b.work,
        'jobnote' => a.note != b.note,
        'client' => a.clientName != b.clientName,
        'jobcardno' => a.jobCardNo != b.jobCardNo,
        _ => true,
      };
}

/// Amber, and a warning only: the phone's copy is as old as its last sync.
class _OpenRepairWarning extends ConsumerWidget {
  const _OpenRepairWarning({required this.assetId});
  final int assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(openRepairOnAssetProvider(assetId)).value;
    if (open == null) return const SizedBox.shrink();
    return Card(
      color: const Color(0xFFFFF8E1),
      child: ListTile(
        leading: const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFE65100),
        ),
        title: Text(
          'Work order $open is still open on this machine '
          '(as of last sync).',
        ),
        subtitle: const Text('The server will refuse a second one.'),
      ),
    );
  }
}
