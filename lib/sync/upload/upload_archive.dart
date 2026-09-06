import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'certificate_upload.dart';

/// What was sent, and what the server said it did with it.
///
/// The outbox deletes a row the moment it is applied, which is right for a
/// queue and wrong for an investigation: it destroys the only record of what
/// left the device. A certificate that reached the server without its
/// readings was diagnosed by reasoning rather than by evidence precisely
/// because there was nothing left to read.
///
/// So every applied upload is written here first. This is a diagnostic record,
/// not a second queue — nothing retries from it and nothing blocks on it.
class UploadArchive {
  UploadArchive(this._db);

  final DatabaseExecutor _db;

  static const table = 'upload_archive';

  /// How many archived uploads are kept. Old enough to cover the certificates
  /// a technician did last week, small enough that a handset is not storing a
  /// year of payloads for nobody.
  static const keep = 200;

  static Future<void> createTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        mobile_id   TEXT NOT NULL,
        archived_at TEXT NOT NULL,
        ops_sent    INTEGER NOT NULL,
        lines_sent  INTEGER NOT NULL,
        applied     INTEGER NOT NULL,
        assigned    TEXT NOT NULL,
        payload     TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_upload_archive_at '
      'ON $table(archived_at DESC)',
    );
  }

  /// Files one applied upload.
  ///
  /// A certificate re-queued after a rejection archives every attempt rather
  /// than replacing the last — the history of what was tried is the point.
  Future<void> record({
    required CertificateUpload upload,
    required int applied,
    required Map<String, int> assigned,
  }) async {
    await _db.insert(table, {
      'mobile_id': upload.mobileId,
      'archived_at': DateTime.now().toUtc().toIso8601String(),
      'ops_sent': upload.rowOpCount,
      'lines_sent': upload.lines.length,
      'applied': applied,
      'assigned': jsonEncode(assigned),
      'payload': jsonEncode(upload.toJson()),
    });
    await _trim();
  }

  Future<List<UploadArchiveEntry>> all() async {
    final rows = await _db.query(table, orderBy: 'id DESC');
    return [
      for (final r in rows)
        UploadArchiveEntry(
          mobileId: r['mobile_id']! as String,
          archivedAt:
              DateTime.parse(r['archived_at']! as String),
          opsSent: (r['ops_sent'] as num).toInt(),
          linesSent: (r['lines_sent'] as num).toInt(),
          applied: (r['applied'] as num).toInt(),
          assigned: {
            for (final e in (jsonDecode(r['assigned']! as String) as Map)
                .entries)
              e.key as String: (e.value as num).toInt(),
          },
          upload: CertificateUpload.fromJson(
            jsonDecode(r['payload']! as String) as Map<String, Object?>,
          ),
        ),
    ];
  }

  /// The most recent uploads the server did not apply in full.
  Future<List<UploadArchiveEntry>> shortApplies() async =>
      (await all()).where((e) => e.isShort).toList();

  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS n FROM $table');
    return (rows.first['n'] as num?)?.toInt() ?? 0;
  }

  Future<void> _trim() async {
    await _db.rawDelete(
      'DELETE FROM $table WHERE id NOT IN '
      '(SELECT id FROM $table ORDER BY id DESC LIMIT ?)',
      [keep],
    );
  }
}

/// One archived upload.
class UploadArchiveEntry {
  const UploadArchiveEntry({
    required this.mobileId,
    required this.archivedAt,
    required this.opsSent,
    required this.linesSent,
    required this.applied,
    required this.assigned,
    required this.upload,
  });

  final String mobileId;
  final DateTime archivedAt;

  /// Row ops in the batch: the certificate plus one per reading. An issue op
  /// is not counted, because the server does not count it in `applied`.
  final int opsSent;

  final int linesSent;

  /// The server's own count of row ops it applied.
  final int applied;

  final Map<String, int> assigned;
  final CertificateUpload upload;

  /// How many row ops the server did not apply.
  ///
  /// Never negative: a server applying more than it was sent would be a
  /// different bug, and clamping keeps this readable as "readings missing".
  int get shortBy => opsSent - applied < 0 ? 0 : opsSent - applied;

  /// The server took the batch and did not apply all of it.
  ///
  /// This is the state that had no way of being seen. A 200 was read as
  /// success and the count that contradicted it was discarded, so a
  /// certificate filed without its readings looked identical to one filed
  /// with them.
  bool get isShort => shortBy > 0;
}
