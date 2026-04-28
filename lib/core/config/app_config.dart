class AppConfig {
  const AppConfig._();

  // Replace with real server URL per environment before first deploy.
  static const String baseUrl = 'http://10.0.2.2:9000';

  // PostgreSQL database name sent with every login request.
  static const String dbName = 'stat_trac';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
