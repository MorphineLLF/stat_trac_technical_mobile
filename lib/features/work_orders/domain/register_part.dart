/// A row from the synced register — a part or a charged rate. No stock, no
/// price.
class RegisterPart {
  const RegisterPart({
    required this.id,
    this.number = '',
    this.description = '',
    this.kind = 1,
  });

  final int id;
  final String number;
  final String description;

  /// `PartType`: 1 a part, anything else a charged rate.
  final int kind;
}
