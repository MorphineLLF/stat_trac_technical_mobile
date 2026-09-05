/// The four answers `POST /{company}/sync/upload` can give, as types.
///
/// They are separated because each needs a different response from the app,
/// and collapsing any two of them produces a wrong screen:
///
/// * **200** applied — take the assigned server keys, retire the queued rows.
/// * **409** conflict — the row moved underneath us. Nothing applied. Show the
///   person both versions and keep their work queued.
/// * **422** rejected — the request was understood perfectly and the answer is
///   no. **Retrying never helps.** A sentence for the technician.
/// * **400** client error — the app is broken. No technician can act on it.
///
/// The 400/422 split is the one most easily lost. Treating a 422 as a client
/// bug hides an answerable message; treating a 400 as a rejection invites a
/// technician to fix something that is not theirs to fix.
sealed class SyncUploadResult {
  const SyncUploadResult();

  /// Whether sending the same batch again could ever succeed.
  bool get isRetryable;

  factory SyncUploadResult.fromResponse(int status, Map<String, Object?> body) {
    switch (status) {
      case 200:
        return UploadApplied(
          applied: (body['applied'] as num?)?.toInt() ?? 0,
          assigned: {
            for (final e
                in ((body['assigned'] as Map?) ?? const {}).entries)
              e.key as String: (e.value as num).toInt(),
          },
          issued: [
            for (final id in (body['issued'] as List?) ?? const [])
              id as String,
          ],
        );
      case 409:
        return UploadConflict([
          for (final c in (body['conflicts'] as List?) ?? const [])
            UploadRowConflict.fromJson(c as Map<String, Object?>),
        ]);
      case 422:
        return UploadRejected([
          for (final r in (body['rejections'] as List?) ?? const [])
            UploadRejection.fromJson(r as Map<String, Object?>),
        ]);
      case 400:
        return UploadClientError(
          (body['error'] as String?) ?? 'The server rejected the request.',
        );
      default:
        return UploadTransportError(
          status,
          (body['error'] as String?) ?? 'Upload failed ($status).',
        );
    }
  }
}

/// The batch was applied. `assigned` maps each `mobile_id` to the server key it
/// was given, which is how a queued row is matched to its real identity.
class UploadApplied extends SyncUploadResult {
  const UploadApplied({
    required this.applied,
    required this.assigned,
    required this.issued,
  });

  final int applied;
  final Map<String, int> assigned;

  /// The certificates closed by an issue op. `applied` counts row ops only.
  final List<String> issued;

  @override
  bool get isRetryable => false;
}

/// Nothing was applied: at least one row moved underneath the device.
class UploadConflict extends SyncUploadResult {
  const UploadConflict(this.conflicts);
  final List<UploadRowConflict> conflicts;

  /// The local change stays queued and the person decides — never resolved by
  /// a timestamp comparison.
  @override
  bool get isRetryable => false;
}

class UploadRowConflict {
  const UploadRowConflict({
    required this.table,
    required this.mobileId,
    required this.fields,
    this.seenAt,
    this.serverAt,
  });

  factory UploadRowConflict.fromJson(Map<String, Object?> j) =>
      UploadRowConflict(
        table: j['table'] as String? ?? '',
        mobileId: j['mobile_id'] as String? ?? '',
        seenAt: j['seen_at'] as String?,
        serverAt: j['server_at'] as String?,
        fields: [
          for (final f in (j['fields'] as List?) ?? const [])
            UploadFieldDiff.fromJson(f as Map<String, Object?>),
        ],
      );

  final String table;
  final String mobileId;
  final String? seenAt;
  final String? serverAt;

  /// **Every** field the op set, not only the differing ones. Someone choosing
  /// between two versions of a certificate needs to see the readings that
  /// agree as well as the one that does not.
  final List<UploadFieldDiff> fields;

  Iterable<UploadFieldDiff> get differingFields =>
      fields.where((f) => f.differs);
}

class UploadFieldDiff {
  const UploadFieldDiff({
    required this.field,
    required this.mine,
    required this.server,
    required this.differs,
  });

  factory UploadFieldDiff.fromJson(Map<String, Object?> j) => UploadFieldDiff(
    field: j['field'] as String? ?? '',
    mine: j['mine'] as String? ?? '',
    server: j['server'] as String? ?? '',
    differs: j['differs'] as bool? ?? false,
  );

  final String field;

  /// Both sides are **text**. `server` is PostgreSQL's own `::text` rendering
  /// and is empty for a null. Render them; do not parse them back.
  final String mine;
  final String server;

  /// PostgreSQL's answer — `"col" is distinct from $n` with the device's value
  /// bound as a parameter, so the database coerces it exactly as the insert
  /// would.
  ///
  /// **Never re-derive this by comparing [mine] and [server].** The app sends
  /// JSON, so an integer column arrives as a double and a date as a string: a
  /// text comparison would call `9304` and `9304.0` different and show a
  /// technician a conflict that does not exist.
  final bool differs;
}

/// Understood, and refused. Retrying the same batch will never help.
class UploadRejected extends SyncUploadResult {
  const UploadRejected(this.rejections);
  final List<UploadRejection> rejections;

  @override
  bool get isRetryable => false;
}

class UploadRejection {
  const UploadRejection({
    required this.table,
    required this.mobileId,
    required this.reason,
    required this.message,
    this.field,
  });

  factory UploadRejection.fromJson(Map<String, Object?> j) => UploadRejection(
    table: j['table'] as String? ?? '',
    mobileId: j['mobile_id'] as String? ?? '',
    reason: j['reason'] as String? ?? 'invalid',
    message: j['message'] as String? ?? 'The server refused this certificate.',
    field: j['field'] as String?,
  );

  final String table;
  final String mobileId;

  /// `incomplete_tests`, `incomplete_values`, `already_issued`, `void`,
  /// `not_found`, `invalid`.
  ///
  /// **`not_found` also means out of scope** — a person who may not see a
  /// certificate is not told that it exists.
  final String reason;

  /// Show this to the technician. The wording may improve server-side; the
  /// [reason] code will not change.
  final String message;

  /// Set when [reason] is `invalid`.
  final String? field;
}

/// The app sent something malformed. Not a technician's problem, and not
/// something they can fix by trying again.
class UploadClientError extends SyncUploadResult {
  const UploadClientError(this.message);
  final String message;

  @override
  bool get isRetryable => false;
}

/// Anything else — an expired token, an outage, no signal. Worth retrying.
class UploadTransportError extends SyncUploadResult {
  const UploadTransportError(this.status, this.message);
  final int status;
  final String message;

  @override
  bool get isRetryable => true;
}
