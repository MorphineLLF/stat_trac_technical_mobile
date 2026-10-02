/// One part used on a job card — the desktop's Work Order tab "Parts" grid
/// (`RepairPart`), not Spares.
///
/// **No price, ever.** The phone never sees one: a picked line is priced from
/// the register by the server, a typed line at nought for the office.
class PartUsed {
  const PartUsed({
    this.partId,
    this.partNo = '',
    this.description = '',
    required this.qty,
  });

  /// The register's `PartID` when picked; null when typed.
  final int? partId;
  final String partNo;
  final String description;
  final double qty;

  /// The server's limits (`maxUsedPartNo`, `maxUsedPartDesc`).
  static const maxPartNo = 50;
  static const maxDescription = 100;

  bool get picked => partId != null;

  /// "FUSE-5A — Fuse 5A", or whichever half there is.
  String get label => [
    partNo.trim(),
    description.trim(),
  ].where((s) => s.isNotEmpty).join(' — ');

  String get qtyText =>
      qty == qty.truncateToDouble() ? qty.toInt().toString() : qty.toString();

  /// A quantity as typed. A comma is a decimal point — South African keyboards.
  static double? parseQty(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  /// A picked line sends its number and description as well as its id: if the
  /// part has left the register since this phone synced, the server keeps what
  /// was sent as a typed line rather than losing it.
  Map<String, Object?> toWire() => {
    'part_id': ?partId,
    'part_no': partNo.trim(),
    'description': description.trim(),
    'qty': qty,
  };

  factory PartUsed.fromWire(Map<String, Object?> w) => PartUsed(
    partId: (w['part_id'] as num?)?.toInt(),
    partNo: w['part_no'] as String? ?? '',
    description: w['description'] as String? ?? '',
    qty: (w['qty'] as num?)?.toDouble() ?? 0,
  );
}
