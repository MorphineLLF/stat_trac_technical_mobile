import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/auth/data/models/sync_credentials_model.dart';

void main() {
  group('SyncCredentialsModel.fromJson', () {
    // The exact payload documented in the Go handover section 4, step 2.
    test('maps the documented sync token response', () {
      final model = SyncCredentialsModel.fromJson(const {
        'token': 'eyJhbGciOiJIUzI1NiIsImtpZCI6InN0YXR0cmFjIn0.abc.def',
        'expires': '2026-09-05T13:03:41Z',
        'expires_in': 3599,
        'endpoint': 'https://demo.stattrac.net/sync',
        'user_id': 35,
      });

      expect(
        model.token,
        'eyJhbGciOiJIUzI1NiIsImtpZCI6InN0YXR0cmFjIn0.abc.def',
      );
      expect(model.endpoint, 'https://demo.stattrac.net/sync');
      expect(model.userId, 35);
      expect(model.expiresAt, DateTime.utc(2026, 9, 5, 13, 3, 41));
    });

    test('reports expiry against a supplied clock', () {
      final model = SyncCredentialsModel.fromJson(const {
        'token': 't',
        'expires': '2026-09-05T13:00:00Z',
        'expires_in': 3599,
        'endpoint': 'https://demo.stattrac.net/sync',
        'user_id': 35,
      });

      expect(model.isExpiredAt(DateTime.utc(2026, 9, 5, 12, 59, 59)), isFalse);
      expect(model.isExpiredAt(DateTime.utc(2026, 9, 5, 13, 0, 1)), isTrue);
    });
  });
}
