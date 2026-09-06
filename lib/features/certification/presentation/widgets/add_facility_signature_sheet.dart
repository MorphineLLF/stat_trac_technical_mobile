import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../../../../core/theme/app_theme.dart';
import 'signature_export_size.dart';

/// What the facility gave: a signature and the name of who gave it.
class FacilitySignature {
  const FacilitySignature({required this.png, required this.name});
  final Uint8List png;
  final String name;
}

/// Captures a facility signature for a certificate that is already issued.
///
/// Signing after issue is allowed — what was measured cannot change, who
/// signed for it is what happens next — so a certificate that went up
/// unsigned can still be completed by the person it was written for.
///
/// The name is required here and not merely asked for, because a client
/// signature that does not say who gave it is refused by the server and would
/// be captured and then thrown away. That is the bug this sheet exists partly
/// to avoid repeating.
Future<FacilitySignature?> showAddFacilitySignatureSheet(
  BuildContext context,
) {
  return showModalBottomSheet<FacilitySignature>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _AddFacilitySignatureSheet(),
  );
}

class _AddFacilitySignatureSheet extends StatefulWidget {
  const _AddFacilitySignatureSheet();

  @override
  State<_AddFacilitySignatureSheet> createState() =>
      _AddFacilitySignatureSheetState();
}

class _AddFacilitySignatureSheetState
    extends State<_AddFacilitySignatureSheet> {
  final _controller = SignatureController(
    penStrokeWidth: signaturePenStrokeWidth,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  final _nameController = TextEditingController();
  Size? _padSize;

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_controller.isEmpty) {
      _say('Sign in the box first');
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      _say('Add the facility contact name — the signature cannot be sent '
          'without it');
      return;
    }

    final export = _padSize == null ? null : signatureExportSize(_padSize!);
    final png = await _controller.toPngBytes(
      width: export?.width.toInt(),
      height: export?.height.toInt(),
    );
    if (png == null || !mounted) return;

    Navigator.of(context).pop(
      FacilitySignature(png: png, name: _nameController.text.trim()),
    );
  }

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Facility signature',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Facility Contact Name',
              hintText: 'Who is signing',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: brandGrey),
              borderRadius: BorderRadius.circular(8),
            ),
            height: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _padSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return Signature(
                    controller: _controller,
                    backgroundColor: Colors.white,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(_controller.clear),
                icon: const Icon(Icons.refresh),
                label: const Text('Clear'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Save signature'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
