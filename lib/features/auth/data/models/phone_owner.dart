/// The technician this phone is registered to.
///
/// A phone belongs to one technician: the first to sign in on it. It is kept
/// through log out, like the company, and only reinstalling the app clears it
/// — the user's rule, 2026-09-30.
class PhoneOwner {
  const PhoneOwner({required this.userId, required this.name});

  /// The user id the server returned at sign-in, not the typed username, so
  /// case and spacing cannot get around it.
  final int userId;
  final String name;

  factory PhoneOwner.fromJson(Map<String, dynamic> json) => PhoneOwner(
    userId: json['user_id'] as int,
    name: json['name'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'user_id': userId, 'name': name};
}
