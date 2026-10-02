import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'document_result.dart';

/// The box a document is emailed from — a certificate or a work order.
///
/// The recipient is typed: no contact table and no email column reach this
/// device. The CC and message open with the technician's own CC and sign-off,
/// asked of the server as the box opens — they live on the Admin row, which
/// does not sync.
class EmailDocumentDialog extends StatefulWidget {
  const EmailDocumentDialog({
    super.key,
    required this.title,
    required this.sentLabel,
    required this.loadDefaults,
    required this.onSend,
  });

  /// "Email Certificate" / "Email Work Order".
  final String title;

  /// "Certificate" / "Work order" — the start of the sent message.
  final String sentLabel;
  final Future<DocEmailDefaults?> Function() loadDefaults;

  /// [cc] and [body] null means "left out" — the server fills them in.
  /// Throws `StateError(message)` to show a refusal inside the box.
  final Future<void> Function(String to, String? cc, String? body) onSend;

  @override
  State<EmailDocumentDialog> createState() => _EmailDocumentDialogState();
}

class _EmailDocumentDialogState extends State<EmailDocumentDialog> {
  final _controller = TextEditingController();
  final _ccController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _sending = false;
  bool _loadingDefaults = true;

  /// Whether the technician's CC and sign-off were put in the boxes. Until
  /// they are, an empty box is left to the server to fill — see
  /// [docEmailFields].
  bool _defaultsShown = false;
  String? _error;

  bool get _valid =>
      _controller.text.contains('@') && _controller.text.contains('.');

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    DocEmailDefaults? defaults;
    try {
      defaults = await widget.loadDefaults();
    } catch (_) {
      // No defaults is not an error: the boxes stay empty and the server
      // signs the mail instead.
    }
    if (!mounted) return;
    setState(() {
      _loadingDefaults = false;
      if (defaults == null) return;
      // Only boxes still empty — never over something already typed.
      if (_ccController.text.isEmpty) _ccController.text = defaults.cc;
      if (_bodyController.text.isEmpty) {
        _bodyController.text = defaults.initialBody;
        _bodyController.selection = const TextSelection.collapsed(offset: 0);
      }
      _defaultsShown = true;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final fields = docEmailFields(
        defaultsShown: _defaultsShown,
        cc: _ccController.text,
        body: _bodyController.text,
      );
      await widget.onSend(_controller.text.trim(), fields.cc, fields.body);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.sentLabel} emailed to ${_controller.text.trim()}',
            ),
          ),
        );
      }
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _ccController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Recipient email',
                hintText: 'name@example.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              onChanged: (_) => setState(() {}),
              enabled: !_sending,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ccController,
              // Read-only on the user's word (2026-10-01): the CC is the
              // technician's own, set in Admin ▸ User Access, and is shown so
              // they know who else receives it — not chosen here.
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'CC',
                prefixIcon: Icon(Icons.people_outline),
              ),
              enabled: !_sending,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              keyboardType: TextInputType.multiline,
              minLines: 5,
              maxLines: 8,
              style: const TextStyle(color: brandDark, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
              ),
              enabled: !_sending,
            ),
            if (_loadingDefaults) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _valid && !_sending ? _submit : null,
          child: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send'),
        ),
      ],
    );
  }
}
