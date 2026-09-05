import 'sync_upload_batch.dart';

/// A certificate as it leaves the device: the header, its readings, and — when
/// the technician is closing it — the decisions that issue it.
///
/// One of these becomes exactly one batch, and a batch is all-or-nothing. That
/// matters here: a certificate and its readings must never be half-uploaded,
/// because a certificate missing readings is not an incomplete record, it is a
/// wrong one.
class CertificateUpload {
  CertificateUpload({
    required this.mobileId,
    required this.certificate,
    required this.lines,
    this.issue,
    this.seenAt,
  }) {
    for (final column in _serverOwned) {
      if (certificate.containsKey(column)) {
        throw ArgumentError.value(
          certificate[column],
          'certificate',
          '$column is the server\'s to write, not the device\'s — '
              '${_serverOwnedReason[column]}',
        );
      }
    }

    if (issue != null && lines.isEmpty) {
      throw ArgumentError.value(
        lines,
        'lines',
        'a certificate with no readings cannot be issued — the server '
            'refuses it as incomplete_tests, and a technician should be told '
            'that before they leave the site rather than after',
      );
    }
  }

  /// Columns the device must never set, and why.
  static const _serverOwned = ['TestTotalTest', 'TestTotalDone',
      'TestNextService'];

  static const _serverOwnedReason = {
    'TestTotalTest': 'the server counts the actual lines, and a second '
        'opinion on a fact is only ever a disagreement',
    'TestTotalDone': 'the server counts the actual lines, and a second '
        'opinion on a fact is only ever a disagreement',
    'TestNextService': 'it is written by the issue op from next_service, '
        'which also moves the PM schedule — setting the column directly '
        'would bypass both the design switch and the schedule move',
  };

  /// The certificate's client-generated UUIDv4. Its readings name it by this,
  /// and the server returns the real key against it in `assigned`.
  final String mobileId;

  /// Allowlisted columns only. An unlisted one is dropped silently server-side.
  final Map<String, Object?> certificate;

  final List<CertificateLineUpload> lines;

  /// Present only when the technician is closing the certificate.
  final CertificateIssue? issue;

  /// The `SyncUpdatedAt` last seen, for optimistic concurrency.
  final String? seenAt;

  /// Assembles the batch.
  ///
  /// Certificate first, then readings, then the issue op — so the wire reads
  /// in the order the work happened. The server writes certificates before
  /// other row ops regardless, so this ordering is for the reader rather than
  /// for correctness.
  SyncUploadBatch toBatch() => SyncUploadBatch([
    SyncUploadOp.row(
      table: 'TestCertificate',
      mobileId: mobileId,
      data: certificate,
      seenAt: seenAt,
    ),
    for (final line in lines)
      SyncUploadOp.certificateLine(
        lineMobileId: line.mobileId,
        certificateMobileId: mobileId,
        data: line.data,
      ),
    if (issue case final i?)
      SyncUploadOp.issue(
        mobileId: mobileId,
        verdict: i.verdict,
        notes: i.notes,
        nextService: i.nextService,
        completePmWorkOrder: i.completePmWorkOrder,
        completePmJobCard: i.completePmJobCard,
      ),
  ]);
}

/// One measurement line.
class CertificateLineUpload {
  const CertificateLineUpload({required this.mobileId, required this.data});

  /// The line's own UUIDv4 — not the certificate's.
  final String mobileId;
  final Map<String, Object?> data;
}

/// The decisions that close a certificate.
///
/// Every field here is a technician's answer, not a computed value. That is
/// why [verdict] has no default: `0` is Non-Compliant, and a machine that
/// failed its test has to be certifiable as having failed by someone's
/// deliberate choice.
class CertificateIssue {
  const CertificateIssue({
    required this.verdict,
    this.notes,
    this.nextService,
    this.completePmWorkOrder = false,
    this.completePmJobCard = false,
  });

  /// 0 Non-Compliant, 1 Compliant, 2 Incomplete.
  final int verdict;

  final String? notes;

  /// Only when the template's design asks for one. Ignored otherwise, refused
  /// when required and missing.
  ///
  /// For a meter-based PM task there is no computed answer — it comes round on
  /// readings rather than months — so the technician is asked rather than
  /// offered a date.
  final String? nextService;

  /// Completes the PM work order open on the task. Leaving it false touches
  /// nothing at all: the schedule does not move either, because a date that
  /// moves while a work order is open leaves that work order raised against a
  /// date that no longer exists.
  final bool completePmWorkOrder;

  /// Completes that work order's job card. Asked separately, because the
  /// person issuing the certificate may not be the person writing it up.
  final bool completePmJobCard;
}
