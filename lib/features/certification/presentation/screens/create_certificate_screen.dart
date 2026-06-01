import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/presentation/widgets/asset_picker_dialog.dart';
import '../../domain/entities/test_certificate.dart';
import '../../domain/entities/test_output.dart';
import '../../domain/entities/test_template_name.dart';
import '../providers/certificate_providers.dart';
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

  void _pickAsset() async {
    final dataSource = ref.read(certAssetLocalDataSourceProvider);
    final asset = await showAssetPicker(context, dataSource);
    if (asset != null) setState(() => _selectedAsset = asset);
  }

  void _goToStep(int step) => setState(() => _step = step);

  // Saves cert + outputs to local SQLite (no signatures yet).
  Future<void> _saveCertificate() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final cert = TestCertificate(
        id: 0,
        certType: TestTemplateName.typeToInt(_selectedType!),
        syncStatus: 'pending',
        createdAt: DateTime.now(),
        assetId: _selectedAsset?.assetId,
        testDate: DateTime.now(),
        templateNameId: _selectedTemplate?.id,
        docNo: _selectedTemplate?.docNo,
      );
      final certId = await ref
          .read(certificateRepositoryProvider)
          .issueCertificate(cert: cert, outputs: _outputs);
      setState(() => _savedCertId = certId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certificate data saved to device')),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  // Updates the saved cert record with signatures.
  Future<void> _completeWithSignature(SignatureResult sig) async {
    await ref.read(certificateRepositoryProvider).updateSignatures(
          _savedCertId!,
          sig.techSignatureBytes.toList(),
          sig.clientSignatureBytes?.toList(),
          sig.clientName,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Certificate saved — PDF will be generated on next sync'),
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
              : () => _goToStep(_step - 1),
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

          // Step 1: asset picker prompt
          _AssetPickStep(
            selectedAsset: _selectedAsset,
            onPickTap: _pickAsset,
            onNext: _selectedAsset != null
                ? () => _goToStep(2)
                : null,
          ),

          // Step 2: template picker
          if (_selectedType != null)
            CertTemplatePicker(
              certType: _selectedType!,
              onSelected: (t) {
                setState(() => _selectedTemplate = t);
                _goToStep(3);
              },
            )
          else
            const SizedBox.shrink(),

          // Step 3: test items grid
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
                      if (!_allActualsValid && _savedCertId == null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'All actual values are required before saving.',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (_savedCertId == null)
                        FilledButton(
                          onPressed: _saving || !_allActualsValid
                              ? null
                              : _saveCertificate,
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Text('Save'),
                        )
                      else ...[
                        Text(
                          'Saved to device ✓',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.green[700]),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () => _goToStep(4),
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

          // Step 4: signatures
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
          Text('Select Asset',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (selectedAsset != null)
            Card(
              child: ListTile(
                leading:
                    const Icon(Icons.medical_services_outlined, color: brandTeal),
                title: Text(selectedAsset!.equipmentType),
                subtitle: Text([
                  if (selectedAsset!.hospital != null) selectedAsset!.hospital!,
                  if (selectedAsset!.serialNumber != null)
                    'S/N: ${selectedAsset!.serialNumber!}',
                ].join(' · ')),
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
            FilledButton(
              onPressed: onNext,
              child: const Text('Next'),
            ),
        ],
      ),
    );
  }
}
