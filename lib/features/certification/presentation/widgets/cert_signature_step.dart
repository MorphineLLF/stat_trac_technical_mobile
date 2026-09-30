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
    this.onClose,
  });
  final bool requiresCustomerSig;
  final ValueChanged<SignatureResult> onSigned;

  /// Leaves without signing, after asking. Null shows no Close button.
  final VoidCallback? onClose;

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
    // Both sides export on the same canvas. Without a size the package
    // exports the bounding box of the strokes, so the two signatures on one
    // certificate came out 123x97 and 180x82 — a record of how somebody
    // signed rather than of what they signed on.
    final export = signatureExportSizeFor(_padSize);

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

  /// The certificate is saved and issued before this step, so closing loses
  /// nothing but the signatures — which can still be added from the
  /// certificate afterwards. Asked anyway, because leaving unsigned should be
  /// a choice rather than a slip.
  Future<void> _confirmClose() async {
    final close = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close without signing?'),
        content: const Text(
          'The certificate is saved. You can sign it later from the '
          'certificate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep signing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Close without signing'),
          ),
        ],
      ),
    );
    if (close == true) widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    final issue = FilledButton.icon(
      onPressed: _submit,
      icon: const Icon(Icons.check),
      label: const Text('Issue Certificate'),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SignaturePad(
          title: 'Technician Signature',
          controller: _techController,
          // Measured once from the technician's pad. The facility pad is laid
          // out under the same constraints, so one measurement covers both —
          // which is what makes the two files identical rather than merely
          // similar. Assigned without setState: nothing rebuilds on it, it is
          // only read when the signatures are exported.
          onMeasured: (size) => _padSize = size,
        ),
        // The whole facility section, name included, only when the template
        // asks for a facility signature. Shown on its own under the
        // technician's pad, the name box read as part of the technician's
        // signature — and with no facility pad to go with it, anything typed
        // there was dropped on save.
        if (widget.requiresCustomerSig) ...[
          const SizedBox(height: 24),
          Text(
            'Facility Contact',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _clientNameController,
            decoration: const InputDecoration(
              // White like the pads — unfilled, it showed the grey page
              // through.
              filled: true,
              fillColor: Colors.white,
              labelText: 'Facility Contact Name',
              hintText: 'Required when the facility signs',
            ),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),
          _SignaturePad(
            title: 'Facility Signature',
            controller: _clientController,
          ),
        ],
        const SizedBox(height: 24),
        // Both buttons are full width by theme (minimumSize fromHeight), so
        // each is bounded by Expanded — unbounded in a Row, layout throws
        // every frame and the screen reads as a hang.
        if (widget.onClose == null)
          issue
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _confirmClose,
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: issue),
            ],
          ),
      ],
    );
  }
}

class _SignaturePad extends StatelessWidget {
  const _SignaturePad({
    required this.title,
    required this.controller,
    this.onMeasured,
  });
  final String title;
  final SignatureController controller;

  /// Reports the pad's laid-out size, so the export can match it.
  final ValueChanged<Size>? onMeasured;

  static const double padHeight = 180;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            // A slip of the pen used to mean leaving the certificate: there
            // was no way to take a signature back.
            TextButton.icon(
              onPressed: controller.clear,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _pad(),
      ],
    );
  }

  Widget _pad() {
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
            onMeasured?.call(Size(constraints.maxWidth, constraints.maxHeight));
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
