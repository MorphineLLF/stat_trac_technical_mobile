import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/sync/upload/sync_upload_batch.dart';

void main() {
  group('row ops', () {
    test('names the table, the mobile id and the data', () {
      final op = SyncUploadOp.row(
        table: 'TestCertificate',
        mobileId: 'cert-uuid',
        data: const {'TestAssetID': 9304, 'TestDate': '2026-09-05'},
      );

      expect(op.toJson(), {
        'table': 'TestCertificate',
        'mobile_id': 'cert-uuid',
        'data': {'TestAssetID': 9304, 'TestDate': '2026-09-05'},
      });
    });

    test('carries seen_at only when optimistic concurrency applies', () {
      final fresh = SyncUploadOp.row(
        table: 'TestOutput',
        mobileId: 'line',
        data: const {},
      );
      expect(fresh.toJson().containsKey('seen_at'), isFalse);

      final seen = SyncUploadOp.row(
        table: 'TestOutput',
        mobileId: 'line',
        data: const {},
        seenAt: '2026-09-05T10:00:00Z',
      );
      expect(seen.toJson()['seen_at'], '2026-09-05T10:00:00Z');
    });
  });

  group('issue op', () {
    // The five field names are exact. The server REFUSES an unknown field
    // rather than dropping it -- deliberately, because a dropped
    // complete_pm_work_order is a work order left open that everybody
    // believes is closed. This test is the guard against a typo like
    // complete_pm_workorder.
    test('spells the five fields exactly as the server expects', () {
      final op = SyncUploadOp.issue(
        mobileId: 'cert-uuid',
        verdict: 1,
        notes: 'all good',
        nextService: '2027-09-05',
        completePmWorkOrder: true,
        completePmJobCard: false,
      );

      final json = op.toJson();
      expect(json['table'], 'TestCertificate');
      expect(json['action'], 'issue');
      expect(json['mobile_id'], 'cert-uuid');
      expect(json['data'], {
        'verdict': 1,
        'notes': 'all good',
        'next_service': '2027-09-05',
        'complete_pm_work_order': true,
        'complete_pm_job_card': false,
      });
    });

    // Non-Compliant. A real verdict and the most serious one, so it must
    // survive as 0 rather than being treated as absent.
    test('sends a non-compliant verdict of 0', () {
      final json = SyncUploadOp.issue(mobileId: 'c', verdict: 0).toJson();
      expect((json['data'] as Map)['verdict'], 0);
    });

    test('omits next_service when there is none rather than sending null', () {
      final json = SyncUploadOp.issue(mobileId: 'c', verdict: 1).toJson();
      expect((json['data'] as Map).containsKey('next_service'), isFalse);
    });

    test('omits notes when empty', () {
      final json =
          SyncUploadOp.issue(mobileId: 'c', verdict: 1, notes: '  ').toJson();
      expect((json['data'] as Map).containsKey('notes'), isFalse);
    });
  });

  group('certificate line', () {
    // A measurement line names its certificate by TestOutputCertMobileID --
    // the CERTIFICATE's uuid, not its own. Its own is the mobile_id at the top
    // of the op. The device cannot know TestOutputCertID because the server
    // assigns it, which is the whole premise of a mobile id.
    test('names its certificate by the certificate mobile id', () {
      final op = SyncUploadOp.certificateLine(
        lineMobileId: 'line-uuid',
        certificateMobileId: 'cert-uuid',
        data: const {'TestDescription': 'Earth continuity', 'TestValue': '0.08'},
      );

      final json = op.toJson();
      expect(json['table'], 'TestOutput');
      expect(json['mobile_id'], 'line-uuid');

      final data = json['data']! as Map;
      expect(data['TestOutputCertMobileID'], 'cert-uuid');
      expect(data['TestDescription'], 'Earth continuity');
    });

    // Sending both is refused by the server rather than reconciled, because a
    // device that can set both can make them disagree and the disagreement is
    // invisible. Catch it here rather than at the wire.
    test('refuses to carry TestOutputCertID as well', () {
      expect(
        () => SyncUploadOp.certificateLine(
          lineMobileId: 'line',
          certificateMobileId: 'cert',
          data: const {'TestOutputCertID': 5030},
        ),
        throwsArgumentError,
      );
    });

    // Writing a 0 there is not a certificate reference — it is an orphan with
    // a plausible-looking field, and the register already holds 8,850 of them.
    test('refuses a zero certificate id smuggled through data', () {
      expect(
        () => SyncUploadOp.certificateLine(
          lineMobileId: 'line',
          certificateMobileId: 'cert',
          data: const {'TestOutputCertID': 0},
        ),
        throwsArgumentError,
      );
    });
  });

  group('batch', () {
    // Row ops apply first server-side whatever their order, but sending them
    // first keeps the wire readable and matches the documented example.
    test('serialises ops in order under an ops key', () {
      final batch = SyncUploadBatch([
        SyncUploadOp.row(table: 'TestCertificate', mobileId: 'c', data: const {}),
        SyncUploadOp.row(table: 'TestOutput', mobileId: 'l', data: const {}),
        SyncUploadOp.issue(mobileId: 'c', verdict: 1),
      ]);

      final json = batch.toJson();
      final ops = json['ops']! as List;
      expect(ops, hasLength(3));
      expect((ops[0] as Map)['table'], 'TestCertificate');
      expect((ops[2] as Map)['action'], 'issue');
    });

    // The server caps a batch at 500 ops.
    test('reports when it exceeds the server limit', () {
      final ops = List.generate(
        501,
        (i) => SyncUploadOp.row(table: 'TestOutput', mobileId: '$i', data: const {}),
      );
      expect(SyncUploadBatch(ops).exceedsServerLimit, isTrue);
      expect(SyncUploadBatch(ops.take(500).toList()).exceedsServerLimit, isFalse);
    });
  });
}
