import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../../../../core/theme/app_theme.dart';
import 'signature_export_size.dart';
import 'signature_step_validation.dart';

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
    penStrokeWidth: signaturePenStrokeWidth,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  final _clientController = SignatureController(
    penStrokeWidth: signaturePenStrokeWidth,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  /// The pad's laid-out size, measured rather than assumed.
  ///
  /// Both pads sit in the same list under the same constraints, so one
  /// measurement serves both — which is what makes the two exported files
  /// identical by construction.
  Size? _padSize;
  final _clientNameController = TextEditingController();

  @override
  void dispose() {
    _techController.dispose();
    _clientController.dispose();
    _clientNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Checked together, and checked BEFORE anything is exported: a facility
    // signature with no name used to pass here and be discarded on the way to
    // the server, so a real signature from a real person was lost with only a
    // log line to say so.
    final problem = signatureStepError(
      techSigned: _techController.isNotEmpty,
      requiresCustomerSig: widget.requiresCustomerSig,
      clientSigned: _clientController.isNotEmpty,
      clientName: _clientNameController.text,
    );
    if (problem != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }

    // Said, not enforced. A certificate is valid without a facility
    // signature, so this cannot stand in the way of issuing one — but a
    // signature that cannot be sent must not disappear without a word either.
    final warning = signatureStepWarning(
      clientSigned: _clientController.isNotEmpty,
      clientName: _clientNameController.text,
    );
    if (warning != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(warning),
          backgroundColor: const Color(0xFFFFB300),
        ),
      );
    }
    // Both sides export on the same canvas. Without a size the package
    // exports the bounding box of the strokes, so the two signatures on one
    // certificate came out 123x97 and 180x82 — a record of how somebody
    // signed rather than of what they signed on.
    final export = _padSize == null ? null : signatureExportSize(_padSize!);

    final techBytes = await _techController.toPngBytes(
      width: export?.width.toInt(),
      height: export?.height.toInt(),
    );
    if (techBytes == null) return;

    // Exported whenever somebody signed, not only when the template asked.
    // A signature taken from a real person is not discarded because the
    // template did not require one.
    Uint8List? clientBytes;
    if (_clientController.isNotEmpty) {
      clientBytes = await _clientController.toPngBytes(
        width: export?.width.toInt(),
        height: export?.height.toInt(),
      );
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
        _SignaturePad(
          controller: _techController,
          // Measured once from the technician's pad. The facility pad is laid
          // out under the same constraints, so one measurement covers both —
          // which is what makes the two files identical rather than merely
          // similar. Assigned without setState: nothing rebuilds on it, it is
          // only read when the signatures are exported.
          onMeasured: (size) => _padSize = size,
        ),
        const SizedBox(height: 24),
        Text(
          'Facility Contact',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _clientNameController,
          decoration: const InputDecoration(
            labelText: 'Facility Contact Name',
            // Not "Optional". It is optional only until somebody from the
            // facility signs, and captioning it otherwise is what caused a
            // real signature to be captured and then thrown away.
            hintText: 'Required if the facility signs',
          ),
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
        ),
        if (widget.requiresCustomerSig) ...[
          const SizedBox(height: 8),
          _SignaturePad(controller: _clientController),
        ],
        const SizedBox(height: 24),
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
  const _SignaturePad({required this.controller, this.onMeasured});
  final SignatureController controller;

  /// Reports the pad's laid-out size, so the export can match it.
  final ValueChanged<Size>? onMeasured;

  static const double padHeight = 180;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: brandGrey),
        borderRadius: BorderRadius.circular(8),
      ),
      height: padHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            onMeasured?.call(
              Size(constraints.maxWidth, constraints.maxHeight),
            );
            return Signature(
              controller: controller,
              backgroundColor: Colors.white,
            );
          },
        ),
      ),
    );
  }
}
