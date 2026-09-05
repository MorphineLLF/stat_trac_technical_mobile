/// Short-lived credentials for the PowerSync stream.
///
/// Returned by `GET /{company}/sync/token`. The token lasts one hour; the
/// endpoint is handed back with it deliberately so the sync service can move
/// without an app release — configure one thing, not two.
class SyncCredentialsModel {
  const SyncCredentialsModel({
    required this.token,
    required this.endpoint,
    required this.expiresAt,
    required this.userId,
  });

  factory SyncCredentialsModel.fromJson(Map<String, dynamic> json) {
    return SyncCredentialsModel(
      token: json['token'] as String,
      endpoint: json['endpoint'] as String,
      expiresAt: DateTime.parse(json['expires'] as String).toUtc(),
      userId: json['user_id'] as int,
    );
  }

  final String token;
  final String endpoint;
  final DateTime expiresAt;
  final int userId;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);
}
