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
  /// Null while choosing, or when the line is typed.
  RegisterPart? _picked;
  bool _typing = false;
  String _query = '';
  late Future<List<RegisterPart>> _results = widget.search('');

  final _code = TextEditingController();
  final _desc = TextEditingController();
  final _qty = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _desc.dispose();
    _qty.dispose();
    super.dispose();
  }

  double? get _qtyValue {
    final q = PartUsed.parseQty(_qty.text);
    return q != null && q > 0 ? q : null;
  }

  bool get _named =>
      _picked != null ||
      _code.text.trim().isNotEmpty ||
      _desc.text.trim().isNotEmpty;

  void _add() => Navigator.of(context).pop(
    _picked != null
        ? PartUsed(
            partId: _picked!.id,
            partNo: _picked!.number,
            description: _picked!.description,
            qty: _qtyValue!,
            kind: _picked!.kind,
          )
        : PartUsed(
            partNo: _code.text,
            description: _desc.text,
            qty: _qtyValue!,
            kind: widget.charged ? PartUsed.chargedKind : PartUsed.partKind,
          ),
  );

  @override
  Widget build(BuildContext context) {
    final choosing = _picked == null && !_typing;
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
            return ListView(
              children: [
                for (final p in parts)
                  ListTile(
                    title: Text(p.number),
                    subtitle: Text(p.description),
                    onTap: () => setState(() => _picked = p),
                  ),
              ],
            );
          },
        ),
      ),
      TextButton(
        onPressed: () => setState(() => _typing = true),
        child: const Text('Type it instead'),
      ),
    ],
  );

  Widget _details() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_picked != null)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_picked!.number),
          subtitle: Text(_picked!.description),
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
        autofocus: _picked != null,
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
