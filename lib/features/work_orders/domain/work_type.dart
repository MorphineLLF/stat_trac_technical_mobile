/// The kinds of work a captured work order can be.
///
/// The server's repair-module list (`internal/stats/workorder.go`). **PM (5) is
/// absent on purpose** — PM work orders belong to the PM module and the
/// server refuses one raised here.
enum WorkType {
  repair(1, 'Repair'),
  warranty(2, 'Warranty Repair'),
  callOut(3, 'Call-out'),
  qa(4, 'Quality Assurance'),
  installation(6, 'Installation');

  const WorkType(this.code, this.label);

  final int code;
  final String label;

  static WorkType? fromCode(int? code) {
    for (final w in values) {
      if (w.code == code) return w;
    }
    return null;
  }
}
