import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/presentation/widgets/asset_picker_dialog.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../domain/entities/test_certificate.dart';
import '../../domain/entities/test_equipment_selection.dart';
import '../../domain/entities/test_output.dart';
import '../../domain/entities/test_template_name.dart';
import '../providers/certificate_providers.dart';
import '../widgets/cert_details_step.dart';
import '../widgets/cert_signature_step.dart';
import '../widgets/cert_template_picker.dart';
import '../widgets/cert_test_grid.dart';
import '../widgets/cert_type_selector.dart';

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
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _pickAsset() async {
    final dataSource = ref.read(certAssetLocalDataSourceProvider);
    final asset = await showAssetPicker(context, dataSource);
    if (asset != null) setState(() => _selectedAsset = asset);
  }

  void _goToStep(int step) => setState(() => _step = step);

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
        syncStatus: 'pending',
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
        certName: _selectedTemplate?.certName,
        pmTaskDescription: _pmTaskDescription,
        serviceInterval: _serviceInterval,
        serviceType: _serviceType,
        serviceId: _serviceId,
      );
      final certId = await ref
          .read(certificateRepositoryProvider)
          .issueCertificate(
            cert: cert,
            outputs: _outputs,
            equipment: _equipment.whereType<TestEquipmentSelection>().toList(),
          );
      setState(() => _savedCertId = certId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certificate data saved to device')),
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

  // Updates the saved cert record with signatures.
  Future<void> _completeWithSignature(SignatureResult sig) async {
    await ref
        .read(certificateRepositoryProvider)
        .updateSignatures(
          _savedCertId!,
          sig.techSignatureBytes.toList(),
          sig.clientSignatureBytes?.toList(),
          sig.clientName,
        );

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
                        if (!_allActualsValid || _patientSafe == null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              [
                                if (!_allActualsValid)
                                  'Fill in all test results and actual values.',
                                if (_patientSafe == null)
                                  'Select a compliance status.',
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

class _AssetPickStep extends StatelessWidget {
  const _AssetPickStep({
    required this.selectedAsset,
    required this.onPickTap,
    required this.onNext,
  });
  final Asset? selectedAsset;
  final VoidCallback onPickTap;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Asset', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (selectedAsset != null)
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.medical_services_outlined,
                  color: brandTeal,
                ),
                title: Text(selectedAsset!.equipmentType),
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
            )
          else
            OutlinedButton.icon(
              onPressed: onPickTap,
              icon: const Icon(Icons.search),
              label: const Text('Pick Asset'),
            ),
          const Spacer(),
          if (onNext != null)
            FilledButton(onPressed: onNext, child: const Text('Next')),
        ],
      ),
    );
  }
}
