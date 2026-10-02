import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/sync/device_online.dart';

void main() {
  test('airplane mode is offline', () {
    expect(isDeviceOnline([ConnectivityResult.none]), isFalse);
    expect(isDeviceOnline(const []), isFalse);
  });

  test('wifi or mobile data is online', () {
    expect(isDeviceOnline([ConnectivityResult.wifi]), isTrue);
    expect(isDeviceOnline([ConnectivityResult.mobile]), isTrue);
    expect(
      isDeviceOnline([ConnectivityResult.none, ConnectivityResult.mobile]),
      isTrue,
    );
  });
}
