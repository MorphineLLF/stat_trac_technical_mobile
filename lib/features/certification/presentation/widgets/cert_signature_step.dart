import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../../../../core/theme/app_theme.dart';

class CertSignatureStep extends StatefulWidget {
  const CertSignatureStep({
    super.key,
    required this.requiresCustomerSig,
    required this.onSigned,
  });
  final bool requiresCustomerSig;
  final ValueChanged<SignatureResult> onSigned;

  @override
  State<CertSignatureStep> createState() => _CertSignatureStepState();
}

class SignatureResult {
  const SignatureResult({
    required this.techSignatureBytes,
    this.clientSignatureBytes,
    this.clientName,
  });
  final Uint8List techSignatureBytes;
  final Uint8List? clientSignatureBytes;
  final String? clientName;
}

class _CertSignatureStepState extends State<CertSignatureStep> {
  final _techController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  final _clientController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  final _clientNameController = TextEditingController();

  @override
  void dispose() {
    _techController.dispose();
    _clientController.dispose();
    _clientNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_techController.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Technician signature is required')),
      );
      return;
    }
    final techBytes = await _techController.toPngBytes();
    if (techBytes == null) return;

    Uint8List? clientBytes;
    if (widget.requiresCustomerSig) {
      if (_clientController.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Facility signature is required')),
        );
        return;
      }
      clientBytes = await _clientController.toPngBytes();
    }

    widget.onSigned(
      SignatureResult(
        techSignatureBytes: techBytes,
        clientSignatureBytes: clientBytes,
        clientName: _clientNameController.text.trim().isEmpty
            ? null
            : _clientNameController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Technician Signature',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _SignaturePad(controller: _techController),
        const SizedBox(height: 24),
        if (widget.requiresCustomerSig) ...[
          Text(
            'Facility Signature',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _clientNameController,
            decoration: const InputDecoration(
              labelText: 'Facility Contact Name',
            ),
          ),
          const SizedBox(height: 8),
          _SignaturePad(controller: _clientController),
          const SizedBox(height: 24),
        ],
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check),
          label: const Text('Issue Certificate'),
        ),
      ],
    );
  }
}

class _SignaturePad extends StatelessWidget {
  const _SignaturePad({required this.controller});
  final SignatureController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: brandGrey),
        borderRadius: BorderRadius.circular(8),
      ),
      height: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Signature(controller: controller, backgroundColor: Colors.white),
      ),
    );
  }
}
