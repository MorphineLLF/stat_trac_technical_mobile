/// Sign-in refused: the server accepted the credentials, but this phone is
/// registered to another technician.
class PhoneRegisteredElsewhere implements Exception {
  const PhoneRegisteredElsewhere(this.ownerName);

  final String ownerName;

  @override
  String toString() => 'PhoneRegisteredElsewhere($ownerName)';
}
