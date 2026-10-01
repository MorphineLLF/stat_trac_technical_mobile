import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../sync/upload/upload_providers.dart';
import '../../../../sync/upload/upload_queue.dart';
import '../../../../sync/upload/work_order_upload.dart';
import '../../domain/work_order_job.dart';
import '../providers/work_order_providers.dart';
import 'create_work_order_screen.dart';

/// One work order, read-only. A synced one by [trackId]; one still on the
/// phone by [mobileId].
class WorkOrderDetailScreen extends ConsumerWidget {
  const WorkOrderDetailScreen({super.key, this.trackId, this.mobileId});

  final int? trackId;
  final String? mobileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = trackId;
    return Scaffold(
      appBar: AppBar(title: Text(id == null ? 'Work order — pending' : 'WO $id')),
      body: id != null ? _Synced(trackId: id, mobileId: mobileId)
          : _Queued(mobileId: mobileId!),
    );
  }
}

class _Synced extends ConsumerWidget {
  const _Synced({required this.trackId, this.mobileId});
  final int trackId;
  final String? mobileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(workOrderRecordProvider(trackId)).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Could not read this work order')),
      data: (r) => r == null
          ? const Center(child: Text('Not on this phone yet'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Field('Status', r.status),
                _Field('Type of work', r.workType?.label ?? ''),
                _Field('Date in', _at(r.started)),
                _Field('Date completed', _at(r.finished)),
                _Field('Technician', r.tech),
                _Field('Equipment hours', r.equipHrs?.toString() ?? ''),
                _Field('N.O.P', r.nop?.toString() ?? ''),
                _Field('Fault', r.fault),
                _Field('Work done', r.work),
                _Field('Notes', r.note),
                _Field('Client name', r.clientName),
                _Field('Job card no', r.jobCardNo),
                const SizedBox(height: 16),
                _Signatures(mobileId: r.mobileId ?? mobileId),
              ],
            ),
    );
  }
}

class _Queued extends ConsumerWidget {
  const _Queued({required this.mobileId});
  final String mobileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(queuedWorkOrderProvider(mobileId)).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Could not read this job')),
      data: (entry) {
        if (entry == null) {
          return const Center(child: Text('Sent — it will appear once synced'));
        }
        final upload = entry.upload as WorkOrderUpload;
        final job = WorkOrderJob.fromWire(upload.capture);
        final setAside = entry.status != UploadStatus.pending;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (setAside)
              Card(
                color: const Color(0xFFFFEBEE),
                child: ListTile(
                  leading: const Icon(Icons.block, color: brandError),
                  title: const Text('Set aside by the server'),
                  subtitle: Text(entry.lastError ?? ''),
                ),
              )
            else
              _Field('Status', entry.lastError ?? 'Waiting to sync'),
            _Field('Type of work', job.workType?.label ?? ''),
            _Field('Date in', _at(job.started)),
            _Field('Date completed', _at(job.finished)),
            _Field('Equipment hours', job.equipHrs?.toString() ?? ''),
            _Field('N.O.P', job.nop?.toString() ?? ''),
            _Field('Fault', job.fault),
            _Field('Work done', job.work),
            _Field('Notes', job.note),
            _Field('Client name', job.clientName),
            _Field('Job card no', job.jobCardNo),
            const SizedBox(height: 16),
            _Signatures(mobileId: mobileId),
            if (setAside) ...[
              const SizedBox(height: 24),
              if (entry.reason == 'invalid') ...[
                FilledButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => CreateWorkOrderScreen(
                        resend: upload,
                        resendField: entry.field,
                        resendMessage: entry.lastError,
                      ),
                    ),
                  ),
                  child: const Text('Fix and resend'),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton(
                onPressed: () => _discard(context, ref),
                child: const Text('Discard'),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Discard this work order?'),
        content: const Text('It never reached the server. Discarding deletes '
            'it from this phone for good.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false),
              child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(c, true),
              child: const Text('Discard')),
        ],
      ),
    );
    if (sure != true) return;
    await (await ref.read(uploadQueueProvider.future)).discard(mobileId);
    ref.invalidate(worklistProvider);
    if (context.mounted) Navigator.of(context).pop();
  }
}

/// Signatures are shown only when this phone holds them. `bytea` does not
/// come down through sync, so anything signed elsewhere cannot be drawn here.
class _Signatures extends ConsumerWidget {
  const _Signatures({required this.mobileId});
  final String? mobileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = mobileId;
    final held = id == null ? null : ref.watch(phoneSignaturesProvider(id)).value;
    if (held == null) {
      return const Text('Signed on another device or at the office');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Technician', style: Theme.of(context).textTheme.titleSmall),
        Image.memory(base64Decode(held.techPng), height: 100),
        const SizedBox(height: 12),
        Text('Client — ${held.clientName}',
            style: Theme.of(context).textTheme.titleSmall),
        Image.memory(base64Decode(held.clientPng), height: 100),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value.isEmpty ? '—' : value,
            style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}

String _at(DateTime? d) =>
    d == null ? '' : DateFormat('dd MMM yyyy  HH:mm').format(d);
