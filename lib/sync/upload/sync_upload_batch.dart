/// The request body for `POST /{company}/sync/upload`.
///
/// One batch carries the certificate, its measurement lines and — when the
/// technician is closing it — the instruction to issue it. Row ops apply first
/// server-side whatever order they arrive in, so the readings are on the
/// certificate before it is issued.
///
/// **A batch is all-or-nothing.** One conflict or one rejection refuses the
/// whole thing and nothing is applied, so the queue is kept intact rather than
/// partially drained.
class SyncUploadBatch {
  const SyncUploadBatch(this.ops);

  final List<SyncUploadOp> ops;

  /// The server caps a batch at 500 ops (and 1 MB).
  static const serverOpLimit = 500;

  bool get exceedsServerLimit => ops.length > serverOpLimit;

  Map<String, Object?> toJson() => {
    'ops': [for (final op in ops) op.toJson()],
  };
}

/// One operation in a batch: either a row upsert or an instruction to issue.
class SyncUploadOp {
  const SyncUploadOp._(this._json);

  /// An allowlisted column upsert, matched on `mobile_id`.
  ///
  /// Unlisted columns are **dropped silently** by the server rather than
  /// refused, so a schema skew still uploads what the server understands.
  /// That is the opposite of an issue op — see [SyncUploadOp.issue].
  ///
  /// [seenAt] carries optimistic concurrency: the `SyncUpdatedAt` the device
  /// last saw. The server refuses with 409 if the row has moved since.
  factory SyncUploadOp.row({
    required String table,
    required String mobileId,
    required Map<String, Object?> data,
    String? seenAt,
  }) {
    return SyncUploadOp._({
      'table': table,
      'mobile_id': mobileId,
      'seen_at': ?seenAt,
      'data': data,
    });
  }

  /// A measurement line, linked to its certificate by the certificate's
  /// **mobile id** rather than its server key.
  ///
  /// The device cannot know `TestOutputCertID` — the server assigns it, which
  /// is the whole premise of a mobile id. So the line carries
  /// `TestOutputCertMobileID`, the CERTIFICATE's uuid; its own uuid is the
  /// `mobile_id` at the top of the op. The server resolves it from the batch
  /// first and from `TestMobileID` on the table otherwise, so lines sent
  /// tomorrow for a certificate uploaded today still link. It is not a column
  /// and never reaches the row — `TestOutputCertID` is written from it.
  ///
  /// A line naming a certificate the server does not have is **refused, not
  /// written**: writing it would make one more orphan, and an orphan is silent
  /// — in no bucket, reaching no device, with nothing saying so. The register
  /// already holds 8,850 of them.
  ///
  /// Passing `TestOutputCertID` as well is rejected here rather than at the
  /// wire. The server refuses that combination rather than reconciling it,
  /// because a device that can set both can make them disagree and the
  /// disagreement is invisible.
  factory SyncUploadOp.certificateLine({
    required String lineMobileId,
    required String certificateMobileId,
    required Map<String, Object?> data,
    String? seenAt,
  }) {
    if (data.containsKey('TestOutputCertID')) {
      throw ArgumentError.value(
        data['TestOutputCertID'],
        'data',
        'A line linked by TestOutputCertMobileID must not also carry '
            'TestOutputCertID — the server refuses both, and a 0 here is an '
            'orphan rather than a certificate reference',
      );
    }

    return SyncUploadOp.row(
      table: 'TestOutput',
      mobileId: lineMobileId,
      seenAt: seenAt,
      data: {'TestOutputCertMobileID': certificateMobileId, ...data},
    );
  }

  /// Close a certificate — this runs `IssueCertificate`'s whole transaction:
  /// the completeness rules, the totals, `TestNextService`, the PM schedule
  /// move and the work order.
  ///
  /// **The five field names are exact and unknown fields are REFUSED, not
  /// dropped.** That is deliberate and it is the opposite of a row op: a
  /// dropped column is something the office fills in anyway, but a dropped
  /// `complete_pm_work_order` is a work order left open that everybody
  /// believes is closed.
  ///
  /// [verdict] is required and must never be defaulted — `0` is Non-Compliant,
  /// the most serious verdict there is, so it has to be a choice the
  /// technician made rather than a value that fell out of an empty form.
  ///
  /// [nextService] is only wanted when the certificate's template asks for it.
  /// Sent when absent it is ignored; missing when required it is refused.
  ///
  /// The test date is deliberately absent: it is whatever is already on the
  /// certificate from when the test started. Issuing does not ask twice.
  factory SyncUploadOp.issue({
    required String mobileId,
    required int verdict,
    String? notes,
    String? nextService,
    bool completePmWorkOrder = false,
    bool completePmJobCard = false,
  }) {
    final trimmedNotes = notes?.trim();

    return SyncUploadOp._({
      'table': 'TestCertificate',
      'mobile_id': mobileId,
      'action': 'issue',
      'data': {
        'verdict': verdict,
        if (trimmedNotes != null && trimmedNotes.isNotEmpty)
          'notes': trimmedNotes,
        'next_service': ?nextService,
        'complete_pm_work_order': completePmWorkOrder,
        'complete_pm_job_card': completePmJobCard,
      },
    });
  }

  /// Attach a signature to a certificate.
  ///
  /// **An action, not a column, and that is the whole design.** The two
  /// signature columns are `bytea` and are deliberately absent from the row
  /// allowlist: a device able to write them directly would bypass every rule
  /// that makes a signature mean anything — that the certificate is not void,
  /// that this side has not already signed, that the design asked for a client
  /// signature at all, that a client signature carries the name of the person
  /// who gave it. The op calls the server's `SaveSignature`, so those rules
  /// run.
  ///
  /// **Signing is allowed after issue** — the only write in this application
  /// that is. What was measured cannot change; who signed for it is what
  /// happens next. Sign ops are therefore applied after issue ops.
  ///
  /// [png] must be **standard, padded** base64. URL-safe or unpadded is
  /// refused rather than guessed at, so it is checked here instead of costing
  /// a round trip.
  ///
  /// [clientName] is required for the client side and refused on the
  /// technician's: a client signature with no record of who signed is not
  /// evidence of anything, and unknown fields are refused rather than dropped.
  factory SyncUploadOp.sign({
    required String mobileId,
    required SignatureSide which,
    required String png,
    String? clientName,
  }) {
    if (png.isEmpty) {
      throw ArgumentError.value(png, 'png', 'a signature with no bytes');
    }
    if (!_standardPaddedBase64.hasMatch(png)) {
      throw ArgumentError.value(
        '${png.length} chars',
        'png',
        'the server takes standard, padded base64 and refuses URL-safe or '
            'unpadded rather than guessing — encode with base64Encode, not '
            'base64UrlEncode',
      );
    }

    final name = clientName?.trim();
    if (which == SignatureSide.client && (name == null || name.isEmpty)) {
      throw ArgumentError.value(
        clientName,
        'clientName',
        'a client signature must name the person who gave it',
      );
    }
    if (which == SignatureSide.tech && name != null && name.isNotEmpty) {
      throw ArgumentError.value(
        clientName,
        'clientName',
        'client_name belongs to the client signature; the server refuses '
            'unknown fields on a sign op rather than dropping them',
      );
    }

    return SyncUploadOp._({
      'table': 'TestCertificate',
      'mobile_id': mobileId,
      'action': 'sign',
      'data': {
        'which': which.wire,
        'png': png,
        if (which == SignatureSide.client) 'client_name': name,
      },
    });
  }

  /// Standard base64: the alphabet plus `+/`, padded to a multiple of four.
  static final _standardPaddedBase64 = RegExp(
    r'^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$',
  );

  final Map<String, Object?> _json;

  Map<String, Object?> toJson() => _json;
}


/// Which side of a certificate a signature belongs to.
///
/// A signature is per side and each side signs once — the first stands, and a
/// second attempt is refused as `already_signed` rather than overwriting it.
enum SignatureSide {
  tech('tech'),
  client('client');

  const SignatureSide(this.wire);

  /// The value the server expects in `which`.
  final String wire;
}
