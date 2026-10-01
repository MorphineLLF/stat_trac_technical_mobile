import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../sync/powersync_providers.dart';
import '../../../../sync/upload/upload_providers.dart';
import '../../../../sync/upload/work_order_upload.dart';
import '../../../assets/data/powersync_asset_data_source.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/presentation/widgets/asset_picker_dialog.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../../certification/presentation/widgets/cert_signature_step.dart';
import '../../domain/work_order_job.dart';
import '../providers/work_order_providers.dart';
import '../widgets/work_order_form.dart';

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

  @override
  void initState() {
    super.initState();
    final resend = widget.resend;
    if (resend != null) {
      _job = WorkOrderJob.fromWire(resend.capture);
      _step = 1;
      if (widget.resendField != null && widget.resendMessage != null) {
        _serverError =
            WorkOrderFieldError(widget.resendField!, widget.resendMessage!);
      }
    }
  }

  String get _techName {
    final auth = ref.read(authProvider);
    return auth is AuthAuthenticated ? auth.user.name : '';
  }

  Future<void> _pickMachine() async {
    final ds = PowerSyncAssetDataSource(
      await ref.read(syncDatabaseProvider.future),
    );
    if (!mounted) return;
    final asset = await showAssetPicker(context, ds);
    if (asset == null || asset.assetId == null) return;
    final detail = await ds.getAssetDetail(asset.assetId!);
    final now = DateTime.now();
    setState(() {
      _asset = asset;
      _job = WorkOrderJob(
        assetId: asset.assetId!,
        started: now,
        finished: now,
        equipHrs: detail?.hours,
      );
    });
  }

  Future<void> _save({required String techPng, required String clientPng,
      required String clientName}) async {
    final job = _job!;
    if (_saving) return;
    setState(() => _saving = true);
    final upload = WorkOrderUpload(
      mobileId: _mobileId,
      // The name signed against is the name on the card.
      capture: job.copyWith(clientName: clientName).toWire(),
      techPng: techPng,
      clientPng: clientPng,
      clientName: clientName,
    );
    final queue = await ref.read(uploadQueueProvider.future);
    // Replaces a set-aside row under the same id rather than adding one.
    await queue.enqueue(upload);
    ref.invalidate(worklistProvider);
    try {
      await (await ref.read(uploadWorkerProvider.future)).drain();
    } catch (e) {
      debugPrint('[upload] send after work order save failed: $e');
    }
    ref.invalidate(worklistProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved — waiting to sync')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.resend == null ? 'New Work Order' : 'Fix and resend'),
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
            Expanded(child: switch (_step) {
              0 => _machineStep(),
              1 => _formStep(),
              _ => _signStep(),
            }),
          ],
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
          Text(asset.displayName, style: Theme.of(context).textTheme.titleMedium),
          Text([asset.serialNumber, asset.hospital].whereType<String>().join(' · ')),
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
            onPressed: valid ? () => setState(() => _step = 2) : null,
            child: const Text('Next'),
          ),
        ),
      ],
    );
  }

  Widget _signStep() {
    final resend = widget.resend;
    if (resend != null) {
      // A set-aside job was signed when it was captured. The client may be long
      // gone; the signatures stand.
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified_outlined, color: brandTeal),
              title: const Text('Signatures kept'),
              subtitle: Text('Signed by the technician and ${resend.clientName}'),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving
                ? null
                : () => _save(
                    techPng: resend.techPng,
                    clientPng: resend.clientPng,
                    clientName: resend.clientName,
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
        leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100)),
        title: Text('Work order $open is still open on this machine '
            '(as of last sync).'),
        subtitle: const Text('The server will refuse a second one.'),
      ),
    );
  }
}
