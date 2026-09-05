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

  final Map<String, Object?> _json;

  Map<String, Object?> toJson() => _json;
}
