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
  const SyncUploadResult({this.enforces = const []});

  /// What this build of the server guarantees, sent on **every** response
  /// including the refusals.
  ///
  /// **A missing key means "no guarantees", never "not yet deployed".** That
  /// distinction is the whole point: a server running a binary older than its
  /// code is otherwise indistinguishable from a compliant one at the moment it
  /// matters, and one such server silently orphaned 46 real readings by
  /// dropping `TestOutputCertMobileID` as an unknown column.
  final List<String> enforces;

  /// The server promises a measurement line must name its certificate.
  ///
  /// Without this, a line's certificate reference is dropped silently and the
  /// reading is written attached to nothing — applied, counted, and lost.
  bool get guaranteesCertRef => enforces.contains(SyncUploadGuarantee.certRef);

  /// Whether sending the same batch again could ever succeed.
  bool get isRetryable;

  static List<String> _enforcesOf(Map<String, Object?> body) => [
    for (final e in (body['enforces'] as List?) ?? const []) e as String,
  ];

  factory SyncUploadResult.fromResponse(int status, Map<String, Object?> body) {
    final enforces = _enforcesOf(body);
    switch (status) {
      case 200:
        return UploadApplied(
          enforces: enforces,
          signed: [
            for (final id in (body['signed'] as List?) ?? const [])
              id as String,
          ],
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
        return UploadConflict(enforces: enforces, [
          for (final c in (body['conflicts'] as List?) ?? const [])
            UploadRowConflict.fromJson(c as Map<String, Object?>),
        ]);
      case 422:
        return UploadRejected(enforces: enforces, [
          for (final r in (body['rejections'] as List?) ?? const [])
            UploadRejection.fromJson(r as Map<String, Object?>),
        ]);
      case 400:
        return UploadClientError(
          (body['error'] as String?) ?? 'The server rejected the request.',
          enforces: enforces,
        );
      case 413:
        return UploadTooLarge(
          (body['error'] as String?) ??
              'This certificate is too big to send in one batch.',
          enforces: enforces,
        );
      case 401:
        return UploadAuthExpired(
          (body['error'] as String?) ??
              'This device needs to sign in again before it can upload.',
          enforces: enforces,
        );
      default:
        return UploadTransportError(
          status,
          (body['error'] as String?) ?? 'Upload failed ($status).',
          enforces: enforces,
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
    this.signed = const [],
    super.enforces,
  });

  final int applied;
  final Map<String, int> assigned;

  /// The certificates closed by an issue op. `applied` counts row ops only.
  final List<String> issued;

  /// The certificates this batch signed, by mobile id.
  ///
  /// A certificate signed by both sides appears twice — a signature is per
  /// side, and this says which ops landed rather than which certificates have
  /// a signature.
  final List<String> signed;

  @override
  bool get isRetryable => false;
}

/// Nothing was applied: at least one row moved underneath the device.
class UploadConflict extends SyncUploadResult {
  const UploadConflict(this.conflicts, {super.enforces});
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
  const UploadRejected(this.rejections, {super.enforces});
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

  /// `incomplete_tests`, `incomplete_values`, `already_issued`,
  /// `already_signed`, `no_client_signature`, `void`, `not_found`, `invalid`.
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
  const UploadClientError(this.message, {super.enforces});
  final String message;

  @override
  bool get isRetryable => false;
}

/// The batch was over the server's 1 MB body cap or its 500 op cap.
///
/// **Permanent, and the fix is fewer ops rather than another attempt.** This
/// exists as its own type because the alternative was the retryable default,
/// where the same oversized batch is resent for ever — a device that has
/// silently stopped uploading while telling the technician it has no signal.
///
/// Splitting is not yet automatic. The batch is parked with its size named so
/// somebody can see what happened, which is the honest state until it is.
class UploadTooLarge extends SyncUploadResult {
  const UploadTooLarge(this.message, {super.enforces});
  final String message;

  @override
  bool get isRetryable => false;
}

/// The device token is dead, revoked, or was never valid.
///
/// **Not refreshable in the background, whatever the batch's merits.** This
/// route authenticates with the ninety-day *device* token, and the only way to
/// obtain one is `POST /{company}/device/token` with a username and password —
/// there is no renewal endpoint and this app stores no password. The hourly
/// refresh described in the handover is the PowerSync JWT, which this route
/// does not use.
///
/// So [isRetryable] is false: the same batch with the same token cannot
/// succeed. The queued work is not condemned by it — the certificate is fine
/// and goes up once somebody signs in — but nothing is achieved by sending it
/// again first.
class UploadAuthExpired extends SyncUploadResult {
  const UploadAuthExpired(this.message, {super.enforces});
  final String message;

  @override
  bool get isRetryable => false;
}

/// Anything else — an outage, no signal. Worth retrying.
class UploadTransportError extends SyncUploadResult {
  const UploadTransportError(this.status, this.message, {super.enforces});
  final int status;
  final String message;

  @override
  bool get isRetryable => true;
}


/// The guarantee names a server can advertise in `enforces`.
abstract final class SyncUploadGuarantee {
  /// A measurement line must name its certificate, or the batch is refused.
  static const certRef = 'cert_ref_required';

  /// A batch is applied whole or not at all.
  static const batchAtomic = 'batch_atomic';

  /// A 409 lists every field the op set, with the server's own `differs`.
  static const conflictFields = 'conflict_fields';

  /// `action: "issue"` runs the certificate's whole issue transaction.
  static const issueAction = 'issue_action';

  /// `action: "sign"` attaches a signature through `SaveSignature`.
  static const signAction = 'sign_action';
}

/// The 422 codes, and what each means for the person holding the device.
abstract final class UploadRejectionReason {
  static const alreadyIssued = 'already_issued';

  /// That side has already signed. **The first signature stands** — a batch
  /// sent twice, or the office signing while the handset was out of signal.
  static const alreadySigned = 'already_signed';

  /// The certificate's design does not ask for a client signature.
  static const noClientSignature = 'no_client_signature';

  static const incompleteTests = 'incomplete_tests';
  static const incompleteValues = 'incomplete_values';
  static const notFound = 'not_found';
  static const voided = 'void';
  static const invalid = 'invalid';

  /// Whether the technician has already got what they wanted.
  ///
  /// A signature refused because that side has already signed is not a
  /// failure to show anyone: the certificate has the signature. Telling a
  /// technician their work was rejected when it is safely filed teaches them
  /// to ignore the message that matters.
  static bool isBenign(String reason) =>
      reason == alreadySigned || reason == alreadyIssued;
}
