import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/sync/sync_indicator.dart';

void main() {
  group('syncIndicatorFor', () {
    // The bug this exists to prevent. PowerSync's downloadError is STICKY:
    // SyncStatus.copyWith keeps the previous error when the new one is null,
    // so a single transient blip leaves it set for the rest of the session.
    // Reading it as "the current state" made a healthy app report failure.
    test('reports connected when a stale error sits behind a live '
        'connection', () {
      final indicator = syncIndicatorFor(
        connected: true,
        connecting: false,
        downloading: false,
        uploading: false,
        error: Exception('connection closed while receiving data'),
      );

      expect(indicator, SyncIndicator.connected);
    });

    test('reports an error only when the connection is actually down', () {
      final indicator = syncIndicatorFor(
        connected: false,
        connecting: false,
        downloading: false,
        uploading: false,
        error: Exception('404 not found'),
      );

      expect(indicator, SyncIndicator.error);
    });

    test('reports syncing while data is moving, error or not', () {
      expect(
        syncIndicatorFor(
          connected: true,
          connecting: false,
          downloading: true,
          uploading: false,
          error: Exception('stale'),
        ),
        SyncIndicator.syncing,
      );
      expect(
        syncIndicatorFor(
          connected: true,
          connecting: false,
          downloading: false,
          uploading: true,
          error: null,
        ),
        SyncIndicator.syncing,
      );
    });

    test('reports connecting while reconnecting rather than offline', () {
      expect(
        syncIndicatorFor(
          connected: false,
          connecting: true,
          downloading: false,
          uploading: false,
          error: null,
        ),
        SyncIndicator.connecting,
      );
    });

    // A reconnect in progress after a blip is not a failure to report.
    test('prefers connecting over a stale error', () {
      expect(
        syncIndicatorFor(
          connected: false,
          connecting: true,
          downloading: false,
          uploading: false,
          error: Exception('stale'),
        ),
        SyncIndicator.connecting,
      );
    });

    test('reports offline when down with nothing to report', () {
      expect(
        syncIndicatorFor(
          connected: false,
          connecting: false,
          downloading: false,
          uploading: false,
          error: null,
        ),
        SyncIndicator.offline,
      );
    });
  });
}
