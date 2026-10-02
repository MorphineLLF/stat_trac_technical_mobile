import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_online.g.dart';

/// Whether the phone has any network at all — wifi, mobile data, anything.
///
/// It says nothing about whether the server is reachable; that is PowerSync's
/// to say. It exists so "no signal" is never shown as a failure.
bool isDeviceOnline(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

/// The phone's network, live. Starts with a check so the first answer does not
/// wait for a change.
@riverpod
Stream<bool> deviceOnline(Ref ref) async* {
  final connectivity = Connectivity();
  yield isDeviceOnline(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(isDeviceOnline);
}
