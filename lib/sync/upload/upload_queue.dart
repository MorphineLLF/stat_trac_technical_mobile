import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'certificate_upload.dart';

/// Where a certificate waits between being finished and reaching the server.
enum UploadStatus {
  /// Will be sent, or sent again. The only state the worker picks up.
  pending,

  /// 409 — the row moved underneath the device. A person decides, never a
  /// timestamp. Retrying unchanged would only conflict again.
  conflicted,

  /// 422 — understood and refused. Retrying is the app arguing with an
  /// answer. The technician fixes it on the device and re-queues.
  rejected,

  /// 400 — the app sent something malformed. Not a technician's problem and
  /// not fixable by them, so it is held for a developer rather than retried.
  failed,
}

/// A certificate queued for upload.
///
/// **The queue must always be able to empty.** Every non-pending state here
/// has a way out — applied removes the row, conflicted and rejected can be
/// re-queued once the person has dealt with them. A queue that can only grow
/// teaches a technician to ignore it, and then it is worth nothing on the day
/// it matters.
class UploadQueueEntry {
  const UploadQueueEntry({
    required this.upload,
    required this.status,
    required this.attempts,
    this.lastError,
    this.reason,
  });

  final CertificateUpload upload;
  final UploadStatus status;
  final int attempts;
  final String? lastError;

  /// The server's 422 code — `incomplete_tests`, `incomplete_values`,
  /// `already_issued`, `void`, `not_found`, `invalid`.
  final String? reason;
}

/// The outbox.
///
/// A certificate is written here the moment the technician finishes it, before
/// anything is attempted over the network, so the work survives the app being
/// killed, the battery dying, or three weeks with no signal.
class UploadQueue {
  UploadQueue(this._db);

  final DatabaseExecutor _db;

  static const table = 'upload_queue';

  static Future<void> createTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        mobile_id   TEXT PRIMARY KEY,
        payload     TEXT NOT NULL,
        status      TEXT NOT NULL DEFAULT 'pending',
        attempts    INTEGER NOT NULL DEFAULT 0,
        last_error  TEXT,
        reason      TEXT,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_upload_queue_status '
      'ON $table(status, created_at)',
    );
  }

  /// Queues a certificate, or replaces one already queued under the same id.
  ///
  /// Replacing matters twice: a retried save must not duplicate, and a
  /// technician correcting a rejected certificate re-queues it — which is how
  /// [UploadStatus.rejected] is escaped.
  Future<void> enqueue(CertificateUpload upload) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert(table, {
      'mobile_id': upload.mobileId,
      'payload': jsonEncode(upload.toJson()),
      'status': UploadStatus.pending.name,
      'attempts': 0,
      'last_error': null,
      'reason': null,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// What the worker should send, oldest first — work reaches the office in
  /// the order it was done.
  Future<List<UploadQueueEntry>> pending() => _read(
    where: 'status = ?',
    args: [UploadStatus.pending.name],
  );

  Future<List<UploadQueueEntry>> all() => _read();

  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS n FROM $table');
    return (rows.first['n'] as num?)?.toInt() ?? 0;
  }

  /// It reached the server. The row goes: a queue entry for work that is
  /// safely filed is just something else to explain.
  Future<void> markApplied(String mobileId) async {
    await _db.delete(table, where: 'mobile_id = ?', whereArgs: [mobileId]);
  }

  Future<void> markConflicted(String mobileId, String summary) =>
      _mark(mobileId, UploadStatus.conflicted, error: summary);

  Future<void> markRejected(
    String mobileId, {
    required String reason,
    required String message,
  }) => _mark(mobileId, UploadStatus.rejected, error: message, reason: reason);

  Future<void> markFailed(String mobileId, String message) =>
      _mark(mobileId, UploadStatus.failed, error: message);

  /// Stays pending and counts the attempt. No signal is not a failure here.
  Future<void> markRetryable(String mobileId, String message) async {
    await _db.rawUpdate(
      'UPDATE $table SET attempts = attempts + 1, last_error = ?, '
      'updated_at = ? WHERE mobile_id = ?',
      [message, DateTime.now().toUtc().toIso8601String(), mobileId],
    );
  }

  Future<void> _mark(
    String mobileId,
    UploadStatus status, {
    String? error,
    String? reason,
  }) async {
    await _db.update(
      table,
      {
        'status': status.name,
        'last_error': error,
        'reason': reason,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'mobile_id = ?',
      whereArgs: [mobileId],
    );
  }

  Future<List<UploadQueueEntry>> _read({String? where, List<Object?>? args}) async {
    final rows = await _db.query(
      table,
      where: where,
      whereArgs: args,
      orderBy: 'created_at, mobile_id',
    );
    return [
      for (final r in rows)
        UploadQueueEntry(
          upload: CertificateUpload.fromJson(
            jsonDecode(r['payload']! as String) as Map<String, Object?>,
          ),
          status: UploadStatus.values.firstWhere(
            (s) => s.name == r['status'],
            orElse: () => UploadStatus.pending,
          ),
          attempts: (r['attempts'] as num?)?.toInt() ?? 0,
          lastError: r['last_error'] as String?,
          reason: r['reason'] as String?,
        ),
    ];
  }
}
