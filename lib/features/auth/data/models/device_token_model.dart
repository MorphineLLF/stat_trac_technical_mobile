/// The ninety-day device token returned by `POST /{company}/device/token`.
///
/// This is what belongs in secure storage. It is deliberately long-lived so
/// that a sync-token expiry costs a round trip, never a password prompt.
class DeviceTokenModel {
  const DeviceTokenModel({
    required this.token,
    required this.expiresAt,
    required this.name,
  });

  factory DeviceTokenModel.fromJson(Map<String, dynamic> json) {
    return DeviceTokenModel(
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expires'] as String).toUtc(),
      name: json['name'] as String?,
    );
  }

  final String token;
  final DateTime expiresAt;
  final String? name;

  Map<String, dynamic> toJson() => {
    'token': token,
    'expires': expiresAt.toIso8601String(),
    'name': name,
  };
}
