import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';

import '../../../sync/powersync_types.dart';
import '../domain/work_order_record.dart';
import '../domain/work_order_summary.dart';
import '../domain/work_type.dart';

typedef SqlRead =
    Future<List<Map<String, Object?>>> Function(String sql, List<Object?> args);

/// What the Worklist could read from the synced tables.
class SyncedWorklist {
  const SyncedWorklist(this.items, {required this.complete});

  final List<WorkOrderSummary> items;

  /// False when the job cards could not be read in time. The synced part is
  /// then empty rather than unfiltered — without the cards a booked-in work
  /// order cannot be told from a capture.
  final bool complete;
}

/// Reads work orders from PowerSync's local database.
///
/// **No joins.** A PowerSync table is a view over JSON with no index on an
/// arbitrary column, so a join scans the whole store per row — joining
/// certificates to assets made that list spin for ever. Each table is read on
/// its own and the pieces are put together here.
///
/// Takes a [SqlRead] rather than the database so the SQL can be tested against
/// plain SQLite tables of the same names.
class PowerSyncWorkOrderDataSource {
  PowerSyncWorkOrderDataSource(
    this._read, {
    this.timeout = const Duration(seconds: 5),
  });

  factory PowerSyncWorkOrderDataSource.of(PowerSyncDatabase db) =>
      PowerSyncWorkOrderDataSource((sql, args) => db.getAll(sql, args));

  final SqlRead _read;

  /// Applied to every read after the first. The first is the list itself and
  /// is allowed to take as long as it takes.
  final Duration timeout;

  /// The lowest-numbered open repair work order on [assetId], from anyone.
  ///
  /// The server's own test (`workorder_write.go:348`): a repair work order
  /// whose status is not 9. A blank status is open. A warning only — it is as
  /// current as the last sync, and the server decides.
  Future<int?> openRepairOn(int assetId) async {
    final rows = await _read(
      'SELECT "RepairTrackID" FROM "Repair" '
      'WHERE "RepairAssetID" = ? AND "RepairRequest" = 1 '
      'AND coalesce("RepairStatus", 0) <> 9 '
      'ORDER BY "RepairTrackID" LIMIT 1',
      [assetId],
    );
    return rows.isEmpty ? null : psInt(rows.first['RepairTrackID']);
  }

  /// The technician's captured work orders, newest first.
  Future<SyncedWorklist> capturedBy(int technicianId) async {
    final repairs = await _read(
      'SELECT "RepairTrackID", "RepairAssetID", "RepairDate", "RepairType", '
      '"RepairStatus", "RepairMobileID" FROM "Repair" '
      'WHERE "RepairTechID" = ? AND "RepairRequest" = 1 '
      'ORDER BY "RepairDate" DESC, "RepairTrackID" DESC LIMIT 500',
      [technicianId],
    );
    if (repairs.isEmpty) return const SyncedWorklist([], complete: true);

    final ids = [for (final r in repairs) ?psInt(r['RepairTrackID'])];

    final Set<int> captured;
    try {
      final cards = await _read(
        'SELECT "RepairDetailTrackID" FROM "RepairDetail" '
        'WHERE "RepairDetailType" = 3 '
        'AND "RepairDetailTrackID" IN (${_marks(ids.length)})',
        ids,
      ).timeout(timeout);
      captured = {for (final c in cards) ?psInt(c['RepairDetailTrackID'])};
    } catch (e) {
      debugPrint('[work orders] job cards unreadable: $e');
      return const SyncedWorklist([], complete: false);
    }

    final kept = [
      for (final r in repairs)
        if (captured.contains(psInt(r['RepairTrackID']))) r,
    ];
    final statuses = await _statusNames({
      for (final r in kept) psInt(r['RepairStatus']) ?? 0,
    });
    final assets = await assetsByIds({
      for (final r in kept) ?psInt(r['RepairAssetID']),
    });

    return SyncedWorklist([
      for (final r in kept)
        WorkOrderSummary(
          trackId: psInt(r['RepairTrackID']),
          mobileId: r['RepairMobileID'] as String?,
          dateIn: psDate(r['RepairDate']),
          assetId: psInt(r['RepairAssetID']),
          asset: assets[psInt(r['RepairAssetID'])],
          workType: WorkType.fromCode(psInt(r['RepairType'])),
          status:
              statuses[psInt(r['RepairStatus']) ?? 0] ??
              'Status ${psInt(r['RepairStatus']) ?? 0}',
        ),
    ], complete: true);
  }

  /// Machines by id. Missing or slow comes back empty — a list without the
  /// hospital is worth more than a list that never arrives.
  Future<Map<int, AssetBrief>> assetsByIds(Set<int> ids) async {
    if (ids.isEmpty) return const {};
    try {
      final rows = await _read(
        'SELECT "AssetID", "AssetEquipmentType", "AssetSerialNo", '
        '"AssetHospital" FROM "Asset" WHERE "AssetID" IN (${_marks(ids.length)})',
        ids.toList(),
      ).timeout(timeout);
      final found = <int, AssetBrief>{};
      for (final a in rows) {
        final id = psInt(a['AssetID']);
        if (id == null) continue;
        found[id] = AssetBrief(
          id: id,
          equipment: a['AssetEquipmentType'] as String?,
          serial: a['AssetSerialNo'] as String?,
          hospital: a['AssetHospital'] as String?,
        );
      }
      return found;
    } catch (e) {
      debugPrint('[work orders] assets unreadable: $e');
      return const {};
    }
  }

  /// One work order and its job card.
  Future<WorkOrderRecord?> record(int trackId) async {
    final repairs = await _read(
      'SELECT "RepairTrackID", "RepairAssetID", "RepairStatus", '
      '"RepairMobileID" FROM "Repair" WHERE "RepairTrackID" = ? LIMIT 1',
      [trackId],
    );
    if (repairs.isEmpty) return null;
    final r = repairs.first;

    final cards = await _read(
      'SELECT * FROM "RepairDetail" WHERE "RepairDetailTrackID" = ? '
      'ORDER BY "RepairDetailJobID" DESC LIMIT 1',
      [trackId],
    ).timeout(timeout);
    final c = cards.isEmpty ? const <String, Object?>{} : cards.first;

    final status = psInt(r['RepairStatus']) ?? 0;
    final names = await _statusNames({status});

    return WorkOrderRecord(
      trackId: trackId,
      mobileId: r['RepairMobileID'] as String?,
      assetId: psInt(r['RepairAssetID']),
      workType: WorkType.fromCode(psInt(c['RepairDetailManualWoType'])),
      status: names[status] ?? 'Status $status',
      started: _at(c['RepairDetailDateIN'], c['RepairDetailTimeIn']),
      finished: _at(c['RepairDetailDate'], c['RepairDetailTimeOut']),
      equipHrs: psInt(c['RepairDetailHrs']),
      nop: psInt(c['RepairDetailNop']),
      fault: c['RepairDetailFault'] as String? ?? '',
      work: c['RepairDetailWork'] as String? ?? '',
      note: c['RepairDetailNote'] as String? ?? '',
      clientName: c['RepairDetailClient'] as String? ?? '',
      jobCardNo: c['RepairDetailJobCard'] as String? ?? '',
      tech: c['RepairDetailTech'] as String? ?? '',
    );
  }

  Future<Map<int, String>> _statusNames(Set<int> ids) async {
    if (ids.isEmpty) return const {};
    try {
      final rows = await _read(
        'SELECT "StatusID", "StatusDescription" FROM "ComboStatus" '
        'WHERE "StatusID" IN (${_marks(ids.length)})',
        ids.toList(),
      ).timeout(timeout);
      final names = <int, String>{};
      for (final s in rows) {
        final id = psInt(s['StatusID']);
        if (id == null) continue;
        names[id] = (s['StatusDescription'] as String? ?? '').trim();
      }
      return names;
    } catch (_) {
      return const {};
    }
  }

  static String _marks(int n) => List.filled(n, '?').join(',');

  /// A date column and a time column, as one moment.
  static DateTime? _at(Object? date, Object? time) {
    final d = psDate(date);
    if (d == null) return null;
    final parts = (time is String ? time : '').split(':');
    return DateTime(
      d.year,
      d.month,
      d.day,
      parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }
}
