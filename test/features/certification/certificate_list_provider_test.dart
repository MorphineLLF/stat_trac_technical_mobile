import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stat_trac_technical/features/auth/domain/entities/user.dart';
import 'package:stat_trac_technical/features/auth/presentation/providers/auth_providers.dart';
import 'package:stat_trac_technical/features/auth/presentation/providers/auth_state.dart';
import 'package:stat_trac_technical/features/certification/data/datasources/cert_local_data_source.dart';
import 'package:stat_trac_technical/features/certification/data/models/certificate_summary.dart';
import 'package:stat_trac_technical/features/certification/data/powersync_cert_data_source.dart';
import 'package:stat_trac_technical/features/certification/presentation/providers/certificate_providers.dart';

class _CertLocal extends Mock implements CertLocalDataSource {}

class _Synced extends Mock implements PowerSyncCertDataSource {}

class _SignedIn extends AuthNotifier {
  _SignedIn(this._state);
  final AuthState _state;

  @override
  AuthState build() => _state;
}

CertificateSummary _cert(int id) => CertificateSummary(
  id: id,
  certType: 1,
  syncStatus: 'synced',
  createdAt: DateTime(2026),
);

// Certificates sync by hospital, so the phone holds every technician's work
// at the facilities it covers. The list shows only the signed-in
// technician's own — the other certificates stay on the phone, unlisted.
void main() {
  late _CertLocal local;
  late _Synced synced;

  setUp(() {
    local = _CertLocal();
    synced = _Synced();
    when(
      () => local.getUnconfirmedCertificates(
        technicianId: any(named: 'technicianId'),
      ),
    ).thenAnswer((_) async => [_cert(1)]);
    when(
      () => synced.getCertificates(technicianId: any(named: 'technicianId')),
    ).thenAnswer((_) async => [_cert(2)]);
  });

  ProviderContainer container(AuthState auth) {
    final c = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => _SignedIn(auth)),
        certLocalDataSourceProvider.overrideWithValue(local),
        powerSyncCertsProvider.overrideWith((ref) async => synced),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'asks both sides for the signed-in technician\'s certificates',
    () async {
      const athi = User(
        id: 31,
        name: 'Athi',
        email: '',
        role: UserRole.technician,
        technicianCode: '',
      );

      final list = await container(
        const AuthAuthenticated(athi),
      ).read(certificateListProvider.future);

      expect([for (final c in list) c.id], [1, 2]);
      verify(
        () => local.getUnconfirmedCertificates(technicianId: 31),
      ).called(1);
      verify(() => synced.getCertificates(technicianId: 31)).called(1);
    },
  );

  // Nobody signed in means nobody's certificates — not everybody's.
  test('lists nothing when nobody is signed in', () async {
    final list = await container(
      const AuthUnauthenticated(),
    ).read(certificateListProvider.future);

    expect(list, isEmpty);
    verifyNever(
      () => synced.getCertificates(technicianId: any(named: 'technicianId')),
    );
  });
}
