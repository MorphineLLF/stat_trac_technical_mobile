import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/presentation/widgets/asset_picker_dialog.dart';
import '../../../work_orders/presentation/providers/work_order_providers.dart';
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

  void _pickAsset() async {
    final dataSource = ref.read(assetLocalDataSourceProvider);
    final asset = await showAssetPicker(context, dataSource);
    if (asset != null) setState(() => _selectedAsset = asset);
  }

  void _goToStep(int step) => setState(() => _step = step);

  Future<void> _issueWithSignature(SignatureResult sig) async {
    final cert = TestCertificate(
      id: 0,
      certType: TestTemplateName.typeToInt(_selectedType!),
      syncStatus: 'pending',
      createdAt: DateTime.now(),
      assetId: _selectedAsset?.assetId,
      testDate: DateTime.now(),
      templateNameId: _selectedTemplate?.id,
      docNo: _selectedTemplate?.docNo,
      techSignature: sig.techSignatureBytes.toList(),
      clientSignature: sig.clientSignatureBytes?.toList(),
      clientName: sig.clientName,
    );

    await ref
        .read(certificateRepositoryProvider)
        .issueCertificate(cert: cert, outputs: _outputs);

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
        leading: _step == 0
            ? null
            : BackButton(onPressed: () => _goToStep(_step - 1)),
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
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: () => _goToStep(4),
                    child: const Text('Proceed to Sign'),
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
              onSigned: _issueWithSignature,
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
