class AppConfig {
  const AppConfig._();

  /// The Go application. Serves the device-token and sync-token endpoints,
  /// both scoped by company: `/{company}/device/token`, `/{company}/sync/token`.
  ///
  /// The PowerSync stream is NOT reached through this URL — the sync token
  /// response carries its own `endpoint`, so the sync service can move without
  /// an app release. Use the value it returns, not a constant.
  ///
  /// Was `http://10.0.2.2:9000` (the emulator's route to the Horse API). Horse
  /// is retired and the Go rep API deliberately took port 9000 so the rep
  /// handsets would not notice the swap — it does not serve this app's
  /// entities. Pointing there again talks to the wrong service silently.
  static const String baseUrl = 'https://demo.stattrac.net';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
