/// A part from the synced register — parts only, no stock, no price.
class RegisterPart {
  const RegisterPart({
    required this.id,
    this.number = '',
    this.description = '',
  });

  final int id;
  final String number;
  final String description;
}
