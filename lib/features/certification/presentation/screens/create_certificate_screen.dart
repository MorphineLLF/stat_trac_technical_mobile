import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/presentation/widgets/asset_picker_dialog.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../domain/entities/test_certificate.dart';
import '../../domain/entities/test_equipment_selection.dart';
import '../../domain/entities/test_output.dart';
import '../../domain/entities/test_template_name.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../providers/certificate_providers.dart';
import '../widgets/cert_details_step.dart';
import '../widgets/cert_signature_step.dart';
import '../widgets/issue_inputs.dart';
import '../widgets/cert_template_picker.dart';
import '../widgets/cert_test_grid.dart';
import '../widgets/cert_type_selector.dart';
import '../../../assets/presentation/providers/asset_providers.dart';
import '../../../../sync/upload/upload_providers.dart';
import '../../../../sync/upload/certificate_upload.dart';
import '../../../../sync/upload/sync_upload_batch.dart';
import '../../../../sync/upload/sync_upload_archive_note.dart';
import 'package:uuid/uuid.dart';

class CreateCertificateScreen extends ConsumerStatefulWidget {
  const CreateCertificateScreen({super.key});

  @override
  ConsumerState<CreateCertificateScreen> createState() =>
      _CreateCertificateScreenState();
}

class _CreateCertificateScreenState
    extends ConsumerState<CreateCertificateScreen> {
  int _step = 0;
  CertType? _selectedType;
  Asset? _selectedAsset;
  TestTemplateName? _selectedTemplate;
  List<TestOutput> _outputs = [];

  /// The uuid this certificate was uploaded under. The signatures must name
  /// the same one — the server matches a sign op to a certificate by it.
  String? _uploadMobileId;
  int? _savedCertId;
  bool _saving = false;
  bool _allActualsValid = false;
  DateTime _testDate = DateTime.now();
  List<TestEquipmentSelection?> _equipment = [];
  // 0 = Non-Compliant, 1 = Compliant, 2 = Incomplete
  int? _patientSafe;
  String? _pmTaskDescription;
  String? _serviceInterval;
  String? _serviceType;
  int? _serviceId;

  /// The three issue decisions. Nothing here is defaulted on the technician's
  /// behalf except the next service date, which is only ever a starting point
  /// they can change — and the date sent is the date the register holds, so
  /// offering one shows them what will actually happen.
  DateTime? _nextService;

  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _pickAsset() async {
    final dataSource = await ref.read(powerSyncAssetsProvider.future);
    if (!mounted) return;
    final asset = await showAssetPicker(context, dataSource);
    if (asset != null) setState(() => _selectedAsset = asset);
  }

  void _goToStep(int step) => setState(() => _step = step);

  /// What the server would refuse this certificate for, or null.
  ///
  /// Checked on the device so a technician hears it while they are still
  /// standing at the machine, rather than as a 422 after they have driven
  /// away.
  String? get _issueProblem => issueInputsError(
    verdict: _patientSafe == null
        ? null
        : IssueVerdict.values.firstWhere((v) => v.wire == _patientSafe),
    needsNextService: _selectedTemplate?.nextService == true,
    nextService: _nextService,
    testDate: _testDate,
  );

  bool get _shouldShowDetailsStep =>
      _selectedTemplate != null &&
      (_selectedTemplate!.editDate || _selectedTemplate!.testEquipQty > 0);

  // Saves cert + outputs to local SQLite (no signatures yet).
  Future<void> _saveCertificate() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final authState = ref.read(authProvider);
      final user = authState is AuthAuthenticated ? authState.user : null;
      final cert = TestCertificate(
        id: 0,
        certType: TestTemplateName.typeToInt(_selectedType!),
        syncStatus: 'draft',
        createdAt: DateTime.now(),
        assetId: _selectedAsset?.assetId,
        testDate: _testDate,
        templateNameId: _selectedTemplate?.id,
        docNo: _selectedTemplate?.docNo,
        patientSafe: _patientSafe,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        technician: user?.name,
        technicianId: user?.id,
        certName: _selectedTemplate?.templateName,
        pmTaskDescription: _pmTaskDescription,
        serviceInterval: _serviceInterval,
        serviceType: _serviceType,
        serviceId: _serviceId,
        testType: (_selectedTemplate?.customerSigRequired == true) ? 1 : null,
      );
      // Saved locally as before, so the wizard's later steps still have a
      // record to attach signatures to.
      final certId = await ref
          .read(certificateRepositoryProvider)
          .issueCertificate(
            cert: cert,
            outputs: _outputs,
            equipment: _equipment.whereType<TestEquipmentSelection>().toList(),
          );
      setState(() => _savedCertId = certId);

      // AND queued for the server. Without this the certificate reaches the
      // retired local table and nothing else: the old push path is disabled
      // because its endpoints 404, and the certificate list reads PowerSync,
      // so the technician's work would vanish with no error at all.
      await _queueForUpload(cert, certId);

      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(pendingUploadCountProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved and queued — it will be sent when online'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  /// Puts the finished certificate in the outbox, and issues it.
  ///
  /// The issue op runs the server's whole IssueCertificate transaction — the
  /// completeness rules, TestNextService, the PM schedule move and the work
  /// order. Without it a certificate uploaded as a record and was never
  /// issued, which is what made a finished job look done while the register
  /// held a document that was not evidence of anything.
  ///
  /// Unknown fields are REFUSED on this op rather than dropped, which is the
  /// opposite of the row ops above and deliberate: a dropped column is
  /// something the office fills in anyway, a dropped complete_pm_work_order
  /// is a work order left open that everybody believes is closed.
  Future<void> _queueForUpload(TestCertificate cert, int certId) async {
    const uuid = Uuid();

    final certMobileId = uuid.v4();
    _uploadMobileId = certMobileId;

    final upload = CertificateUpload(
      mobileId: certMobileId,
      certificate: {
        'TestAssetID': cert.assetId,
        'TestDate': cert.testDate?.toIso8601String().substring(0, 10),
        'TestCertType': cert.certType,
        'TestTech': cert.technician,
        'TestTechID': cert.technicianId,
        'TestCertificateDescription': cert.certName,
        'TestCertificateNotes': cert.notes,
        'TestCertPatientSafe': cert.patientSafe,
        'TestType': cert.testType,
        'TestJobcardNo': cert.jobcardNo,
      }..removeWhere((_, v) => v == null),
      lines: [
        for (final o in _outputs)
          CertificateLineUpload(
            mobileId: uuid.v4(),
            data: {
              'TestDescriptionID': o.descriptionId,
              'TestDescription': o.description,
              'TestValue': o.expectedValue,
              // The dash survives: it is the register saying there is nothing
              // to measure here, and the server counts it as a complete line.
              'TestActualValue': o.actualValue,
              'TestNote': o.notes,
              'TestPass': o.pass,
              'TestFail': o.fail,
              'TestNA': o.na,
            }..removeWhere((_, v) => v == null),
          ),
      ],
      // The verdict is the technician's choice from three fixed values and is
      // never defaulted — 0 is Non-Compliant, the most serious verdict there
      // is, and the wizard already refuses to go on without one.
      //
      // next_service is sent whenever the design asks for it. Sent when
      // unwanted it is ignored in full; missing when required it is a 422 on
      // site, so an extra one is the safe way to be wrong.
      issue: CertificateIssue(
        verdict: cert.patientSafe!,
        notes: cert.notes,
        nextService: _nextService == null ? null : wireDate(_nextService!),
        // Both sent false and neither offered. Completing a PM work order and
        // its job card is not this certificate's business — the office
        // closes those. Sending false is always safe: where no work order is
        // open the server raises one already completed regardless, and where
        // one is open it stays open and the schedule does not move.
        completePmWorkOrder: false,
        completePmJobCard: false,
      ),
    );

    // Stamped on the row before it leaves. The server's answer names this
    // certificate by this UUID and by nothing else, so without it here the
    // device could never match the reply to the work.
    await ref
        .read(certLocalDataSourceProvider)
        .setMobileId(certId, upload.mobileId);

    // The first boundary, logged before anything leaves the device. A
    // certificate once reached the server without its readings and the only
    // record of what was sent had already been deleted, so the count is stated
    // here against the count that was actually saved locally — the two read
    // the same field and must agree.
    final savedLocally = (await ref
            .read(certLocalDataSourceProvider)
            .getOutputsByCertId(certId))
        .length;
    debugPrint(
      queuedNote(
        mobileId: upload.mobileId,
        lines: upload.lines.length,
        savedLocally: savedLocally,
      ),
    );

    final queue = await ref.read(uploadQueueProvider.future);
    await queue.enqueue(upload);

    // Try immediately. A technician normally still has signal when they
    // finish a job, and waiting for the next dashboard visit would leave the
    // record on the device for no reason. If it fails it stays queued, which
    // is exactly what the queue is for -- so the failure is not surfaced
    // here.
    try {
      final worker = await ref.read(uploadWorkerProvider.future);
      await worker.drain();
    } on Exception {
      // Queued is a good enough outcome to report.
    }
  }

  /// Sends the signatures as their own batch.
  ///
  /// A signature is captured after the readings were already queued, so it
  /// cannot ride in that batch — and it does not need to: signing a
  /// certificate uploaded last week is explicitly allowed, and sign ops run
  /// after issue ops. The batch carries its own queue key so it cannot replace
  /// the readings still waiting in the outbox.
  ///
  /// A signature is not a column. The server runs `SaveSignature`, which is
  /// what makes the signature mean something.
  Future<void> _queueSignatures(SignatureResult sig) async {
    final certMobileId = _uploadMobileId;
    if (certMobileId == null) return;

    final clientName = sig.clientName?.trim();
    final upload = CertificateUpload(
      mobileId: certMobileId,
      queueKey: '$certMobileId:sign',
      certificate: const {},
      lines: const [],
      signatures: [
        CertificateSignature(
          which: SignatureSide.tech,
          // Standard, padded base64 — the server refuses URL-safe or
          // unpadded rather than guessing.
          png: base64Encode(sig.techSignatureBytes),
        ),
        if (sig.clientSignatureBytes case final bytes?)
          if (clientName != null && clientName.isNotEmpty)
            CertificateSignature(
              which: SignatureSide.client,
              png: base64Encode(bytes),
              clientName: clientName,
            ),
      ],
    );

    debugPrint(
      signaturesQueuedNote(
        mobileId: certMobileId,
        sides: [for (final g in upload.signatures) g.which.wire],
        clientNameMissing:
            sig.clientSignatureBytes != null &&
            (clientName == null || clientName.isEmpty),
      ),
    );

    final queue = await ref.read(uploadQueueProvider.future);
    await queue.enqueue(upload);
    try {
      final worker = await ref.read(uploadWorkerProvider.future);
      await worker.drain();
    } on Exception {
      // Queued is enough: it goes when there is signal.
    }
  }

  // Updates the saved cert record with signatures, and sends them.
  Future<void> _completeWithSignature(SignatureResult sig) async {
    await ref
        .read(certificateRepositoryProvider)
        .updateSignatures(
          _savedCertId!,
          // Passed as the Uint8List the pad produced. sqflite takes a BLOB
          // only as that type; a plain List<int> is a warning today and an
          // error on a later sqflite.
          sig.techSignatureBytes,
          sig.clientSignatureBytes,
          sig.clientName,
        );

    await _queueSignatures(sig);

    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(pendingUploadCountProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Certificate saved — PDF will be generated on next sync',
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Certificate'),
        leading: BackButton(
          onPressed: _step == 0
              ? () => Navigator.of(context).pop()
              : () {
                  if (_step == 4 && !_shouldShowDetailsStep) {
                    _goToStep(2);
                  } else {
                    _goToStep(_step - 1);
                  }
                },
        ),
      ),
      body: IndexedStack(
        index: _step,
        children: [
          // Step 0: type selector
          CertTypeSelector(
            onSelected: (type) {
              setState(() => _selectedType = type);
              _goToStep(1);
            },
          ),

          // Step 1: asset picker
          _AssetPickStep(
            selectedAsset: _selectedAsset,
            onPickTap: _pickAsset,
            onNext: _selectedAsset != null ? () => _goToStep(2) : null,
          ),

          // Step 2: template picker
          if (_selectedType != null)
            CertTemplatePicker(
              certType: _selectedType!,
              onSelected: (t) {
                setState(() {
                  _selectedTemplate = t;
                  _equipment = List.filled(t.testEquipQty, null);
                });
                _goToStep(_shouldShowDetailsStep ? 3 : 4);
              },
            )
          else
            const SizedBox.shrink(),

          // Step 3: certificate details (NEW)
          if (_selectedTemplate != null)
            CertDetailsStep(
              template: _selectedTemplate!,
              selectedAsset: _selectedAsset,
              initialDate: _testDate,
              initialEquipment: _equipment,
              onChanged: (date, equip, pmTask, interval, serviceType, serviceId) => setState(() {
                _testDate = date;
                _equipment = equip;
                _pmTaskDescription = pmTask;
                _serviceInterval = interval;
                // Offered, not imposed — the technician can change it, and
                // the date they see is the one the register will hold because
                // the server writes it verbatim. Null for a meter task: it
                // comes round on readings, so a guess would be a lie.
                _nextService ??= defaultNextService(
                  testDate: date,
                  interval: int.tryParse(interval ?? ''),
                  intervalType: serviceType,
                );
                _serviceType = serviceType;
                _serviceId = serviceId;
              }),
              onNext: () => _goToStep(4),
            )
          else
            const SizedBox.shrink(),

          // Step 4: test items grid (was step 3)
          if (_selectedTemplate != null && _selectedAsset != null)
            Column(
              children: [
                Expanded(
                  child: CertTestGrid(
                    templateNameId: _selectedTemplate!.id,
                    assetId: _selectedAsset!.assetId ?? 0,
                    onOutputsChanged: (outputs) => _outputs = outputs,
                    onValidityChanged: (valid) =>
                        setState(() => _allActualsValid = valid),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_savedCertId == null) ...[
                        // FIRST, not last. It was at the bottom of a scrolling
                        // column under the notes and the compliance buttons,
                        // where it could barely be seen — and a required field
                        // nobody notices is a 422 on site.
                        //
                        // Shown only where the design asks for it: where it
                        // does not, the server ignores the date entirely, and
                        // a field that looks live and lands nowhere is worse
                        // than no field.
                        if (_selectedTemplate?.nextService == true) ...[
                          _NextServiceField(
                            testDate: _testDate,
                            value: _nextService,
                            onChanged: (d) => setState(() => _nextService = d),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            hintText: 'Optional certificate notes…',
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                          maxLength: 200,
                          maxLines: 2,
                          minLines: 1,
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 8),
                        _ComplianceSelector(
                          value: _patientSafe,
                          onChanged: (v) => setState(() => _patientSafe = v),
                        ),
                        const SizedBox(height: 8),
                        if (!_allActualsValid ||
                            _patientSafe == null ||
                            _issueProblem != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              [
                                if (!_allActualsValid)
                                  'Fill in all test results and actual values.',
                                if (_patientSafe == null)
                                  'Select a compliance status.',
                                // What the server would refuse, said before
                                // the technician leaves site rather than after.
                                if (_patientSafe != null && _issueProblem != null)
                                  _issueProblem!,
                              ].join(' '),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        FilledButton(
                          onPressed:
                              _saving ||
                                  !_allActualsValid ||
                                  _patientSafe == null
                              ? null
                              : _saveCertificate,
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save'),
                        ),
                      ] else ...[
                        Text(
                          'Saved to device ✓',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.green[700]),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () => _goToStep(5),
                          child: const Text('Sign Certificate'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            )
          else
            const SizedBox.shrink(),

          // Step 5: signatures (was step 4)
          if (_selectedTemplate != null)
            CertSignatureStep(
              requiresCustomerSig: _selectedTemplate!.customerSigRequired,
              onSigned: _completeWithSignature,
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

// ── Compliance selector ───────────────────────────────────────────────────────

class _ComplianceSelector extends StatelessWidget {
  const _ComplianceSelector({required this.value, required this.onChanged});
  final int? value;
  final ValueChanged<int> onChanged;

  static const _options = [
    (label: 'Compliant', value: 1, color: Color(0xFF2E7D32)),
    (label: 'Non-Compliant', value: 0, color: Color(0xFFC62828)),
    (label: 'Incomplete', value: 2, color: Color(0xFFF57F17)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Compliance Status',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        Row(
          children: _options.map((opt) {
            final selected = value == opt.value;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: () => onChanged(opt.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? opt.color : opt.color.withAlpha(22),
                      border: Border.all(
                        color: opt.color,
                        width: selected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      opt.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : opt.color,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AssetPickStep extends ConsumerWidget {
  const _AssetPickStep({
    required this.selectedAsset,
    required this.onPickTap,
    required this.onNext,
  });
  final Asset? selectedAsset;
  final VoidCallback onPickTap;
  final VoidCallback? onNext;

  static const _red = Color(0xFFC62828);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if the selected asset has PM tasks — required for certification.
    final pmTasksAsync = selectedAsset?.assetId != null
        ? ref.watch(assetPmTasksProvider(selectedAsset!.assetId!))
        : null;
    final loading = pmTasksAsync != null && !pmTasksAsync.hasValue;
    final hasPmTasks =
        pmTasksAsync == null || (pmTasksAsync.asData?.value.isNotEmpty ?? false);
    final showWarning = !loading && selectedAsset != null && !hasPmTasks;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Asset', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (selectedAsset != null)
            Card(
              shape: showWarning
                  ? RoundedRectangleBorder(
                      side: const BorderSide(color: _red, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.medical_services_outlined,
                      color: showWarning ? _red : brandTeal,
                    ),
                    title: Text(
                      selectedAsset!.equipmentType,
                      style: TextStyle(
                        color: showWarning ? _red : null,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      [
                        if (selectedAsset!.hospital != null)
                          selectedAsset!.hospital!,
                        if (selectedAsset!.serialNumber != null)
                          'S/N: ${selectedAsset!.serialNumber!}',
                      ].join(' · '),
                    ),
                    trailing: TextButton(
                      onPressed: onPickTap,
                      child: const Text('Change'),
                    ),
                  ),
                  if (showWarning)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.warning_amber_outlined,
                            size: 15,
                            color: _red,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'No PM tasks configured — this asset cannot be certified',
                              style: TextStyle(fontSize: 12, color: _red),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: onPickTap,
              icon: const Icon(Icons.search),
              label: const Text('Pick Asset'),
            ),
          const Spacer(),
          if (selectedAsset != null)
            FilledButton(
              onPressed: (onNext != null && !loading && hasPmTasks) ? onNext : null,
              child: Text(
                loading
                    ? 'Checking PM tasks…'
                    : showWarning
                        ? 'No PM tasks — cannot certify'
                        : 'Next',
              ),
            ),
        ],
      ),
    );
  }
}

// ── Next service date ─────────────────────────────────────────────────────────

/// The date the certificate's next service is due.
///
/// **The date shown is the date the register will hold.** The server computes
/// nothing — `TestNextService` is written verbatim and the PM task's schedule
/// date follows it — so a default here is a promise the server keeps, which is
/// why offering one is worth doing rather than leaving an empty box.
class _NextServiceField extends StatelessWidget {
  const _NextServiceField({
    required this.testDate,
    required this.value,
    required this.onChanged,
  });

  final DateTime testDate;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = value == null
        ? 'Tap to choose a date'
        : DateFormat('dd MMM yyyy').format(value!);

    // Given the weight of a decision rather than the look of another text
    // field. It is required, it is easy to scroll past, and a required field
    // nobody sees becomes a refusal after the technician has left site.
    final missing = value == null;

    return Material(
      color: missing ? const Color(0xFFFFF8E1) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: missing ? const Color(0xFFFFB300) : const Color(0xFFDDE3EA),
          width: missing ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? testDate,
            // Never before the test date: the server refuses that, and a
            // picker that allows it hands somebody a rejection they cannot
            // see coming.
            firstDate: testDate,
            lastDate: DateTime(testDate.year + 10),
          );
          if (picked != null) onChanged(picked);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                Icons.event_outlined,
                color: missing ? const Color(0xFFFFB300) : brandTeal,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next Service Due',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: brandGrey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: missing ? const Color(0xFFE65100) : brandDark,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_calendar_outlined, color: brandGrey),
            ],
          ),
        ),
      ),
    );
  }
}
