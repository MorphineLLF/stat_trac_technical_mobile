import 'package:flutter/material.dart';

import '../../domain/part_used.dart';
import '../../domain/register_part.dart';

/// Picks a part — or with [charged] a charged rate — from the register, or
/// takes one typed, then asks the quantity. A typed charged rate is
/// [PartUsed.chargedKind]; a picked line keeps the register's kind.
/// Null when the technician backs out. Everything it has to say stays inside
/// the sheet — a SnackBar from a sheet renders behind it.
Future<PartUsed?> showPartPicker(
  BuildContext context, {
  required Future<List<RegisterPart>> Function(String) search,
  bool charged = false,
}) => showModalBottomSheet<PartUsed>(
  context: context,
  isScrollControlled: true,
  builder: (sheet) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
    child: _PartPicker(search: search, charged: charged),
  ),
);

class _PartPicker extends StatefulWidget {
  const _PartPicker({required this.search, required this.charged});
  final Future<List<RegisterPart>> Function(String) search;
  final bool charged;

  @override
  State<_PartPicker> createState() => _PartPickerState();
}

class _PartPickerState extends State<_PartPicker> {
  /// Typing a line rather than picking one from the list.
  bool _typing = false;
  String _query = '';
  late Future<List<RegisterPart>> _results = widget.search('');

  final _code = TextEditingController();
  final _desc = TextEditingController();
  final _qty = TextEditingController(text: '1');

  /// Each list row's own quantity box, by register id, starting at 1.
  final _rowQty = <int, TextEditingController>{};

  TextEditingController _qtyFor(int id) =>
      _rowQty.putIfAbsent(id, () => TextEditingController(text: '1'));

  static double? _valid(String text) {
    final q = PartUsed.parseQty(text);
    return q != null && q > 0 && q.isFinite ? q : null;
  }

  @override
  void dispose() {
    _code.dispose();
    _desc.dispose();
    _qty.dispose();
    for (final c in _rowQty.values) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _qtyValue {
    final q = PartUsed.parseQty(_qty.text);
    return q != null && q > 0 && q.isFinite ? q : null;
  }

  bool get _named =>
      _code.text.trim().isNotEmpty || _desc.text.trim().isNotEmpty;

  void _add() => Navigator.of(context).pop(
    PartUsed(
      partNo: _code.text,
      description: _desc.text,
      qty: _qtyValue!,
      kind: widget.charged ? PartUsed.chargedKind : PartUsed.partKind,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final choosing = !_typing;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: choosing ? _chooser() : _details(),
      ),
    );
  }

  Widget _chooser() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        widget.charged ? 'Add charged rate' : 'Add part',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('part-search'),
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Search number or description',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (q) => setState(() {
          _query = q;
          _results = widget.search(q);
        }),
      ),
      Expanded(
        child: FutureBuilder<List<RegisterPart>>(
          future: _results,
          builder: (_, snap) {
            if (snap.hasError) {
              return const Center(child: Text('Could not read the parts list'));
            }
            final parts = snap.data;
            if (parts == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (parts.isEmpty) {
              return Center(
                child: Text(
                  _query.isNotEmpty
                      ? 'No match'
                      : widget.charged
                      ? 'No charged rates on this phone yet'
                      : 'No parts on this phone yet',
                ),
              );
            }
            return ListView(children: [for (final p in parts) _row(p)]);
          },
        ),
      ),
      TextButton(
        onPressed: () => setState(() => _typing = true),
        child: const Text('Type it instead'),
      ),
    ],
  );

  /// A register row: its quantity box and Add. Add puts the part on the work
  /// order at that quantity and closes the list.
  Widget _row(RegisterPart p) {
    final qty = _qtyFor(p.id);
    final value = _valid(qty.text);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(p.number),
      subtitle: Text(p.description),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            child: TextField(
              key: Key('pick-qty-${p.id}'),
              controller: qty,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          TextButton(
            key: Key('pick-add-${p.id}'),
            onPressed: value == null
                ? null
                : () => Navigator.of(context).pop(
                    PartUsed(
                      partId: p.id,
                      partNo: p.number,
                      description: p.description,
                      qty: value,
                      kind: p.kind,
                    ),
                  ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _details() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const Key('part-code'),
        controller: _code,
        maxLength: PartUsed.maxPartNo,
        decoration: const InputDecoration(labelText: 'Item code'),
        onChanged: (_) => setState(() {}),
      ),
      TextField(
        key: const Key('part-desc'),
        controller: _desc,
        maxLength: PartUsed.maxDescription,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Description'),
        onChanged: (_) => setState(() {}),
      ),
      if (!_named) const Text('An item code or a description is needed'),
      const SizedBox(height: 12),
      TextField(
        key: const Key('part-qty'),
        controller: _qty,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Quantity'),
        onChanged: (_) => setState(() {}),
      ),
      const Spacer(),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _named && _qtyValue != null ? _add : null,
            child: const Text('Add'),
          ),
        ],
      ),
    ],
  );
}

/// What the edit sheet decided: a changed line, or the line removed.
class PartEdit {
  const PartEdit.changed(PartUsed this.part);
  const PartEdit.removed() : part = null;

  final PartUsed? part;
  bool get removed => part == null;
}

/// Opens a line to edit. A picked line changes its quantity only — the
/// register owns its name; a typed line changes its code, description and
/// quantity. Null when the technician cancels.
Future<PartEdit?> showPartEditor(BuildContext context, PartUsed part) =>
    showModalBottomSheet<PartEdit>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
        child: _PartEditor(part: part),
      ),
    );

class _PartEditor extends StatefulWidget {
  const _PartEditor({required this.part});
  final PartUsed part;

  @override
  State<_PartEditor> createState() => _PartEditorState();
}

class _PartEditorState extends State<_PartEditor> {
  late final _code = TextEditingController(text: widget.part.partNo);
  late final _desc = TextEditingController(text: widget.part.description);
  late final _qty = TextEditingController(text: widget.part.qtyText);

  @override
  void dispose() {
    _code.dispose();
    _desc.dispose();
    _qty.dispose();
    super.dispose();
  }

  double? get _qtyValue {
    final q = PartUsed.parseQty(_qty.text);
    return q != null && q > 0 && q.isFinite ? q : null;
  }

  bool get _named =>
      widget.part.picked ||
      _code.text.trim().isNotEmpty ||
      _desc.text.trim().isNotEmpty;

  void _save() {
    final p = widget.part;
    Navigator.of(context).pop(
      PartEdit.changed(
        PartUsed(
          partId: p.partId,
          partNo: p.picked ? p.partNo : _code.text,
          description: p.picked ? p.description : _desc.text,
          qty: _qtyValue!,
          kind: p.kind,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.part;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p.picked)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(p.description.isEmpty ? p.partNo : p.description),
              subtitle: p.description.isEmpty ? null : Text(p.partNo),
            )
          else ...[
            TextField(
              key: const Key('part-code'),
              controller: _code,
              maxLength: PartUsed.maxPartNo,
              decoration: const InputDecoration(labelText: 'Item code'),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              key: const Key('part-desc'),
              controller: _desc,
              maxLength: PartUsed.maxDescription,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Description'),
              onChanged: (_) => setState(() {}),
            ),
            if (!_named) const Text('An item code or a description is needed'),
          ],
          const SizedBox(height: 12),
          TextField(
            key: const Key('part-qty'),
            controller: _qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Quantity'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(const PartEdit.removed()),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Remove'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: _named && _qtyValue != null ? _save : null,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
