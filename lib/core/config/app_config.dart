class AppConfig {
  const AppConfig._();

  // Replace with real server URL per environment before first deploy.
  static const String baseUrl = 'http://10.0.2.2:9000';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
