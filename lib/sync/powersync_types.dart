/// Coercions for values arriving over the PowerSync stream.
///
/// PowerSync's SQLite columns are text, integer or real, so Postgres types are
/// flattened on the way across. The mappings, confirmed against a captured
/// stream rather than read out of the Postgres catalogue:
///
///   integer, smallint, boolean         -> integer   (boolean arrives 0/1)
///   numeric                            -> TEXT      ("125896.00", a string)
///   date, time, timestamp, timestamptz -> TEXT      (ISO 8601)
///   varchar, char, text, uuid, jsonb   -> TEXT
///
/// **numeric being text is the one that bites.** A direct `as int` cast on
/// `TestTemplateTestEquipQty` throws, because it arrives as `"2.00"`. Read
/// every numeric column through [psNum] or [psInt].
///
/// These return null rather than throwing on unusable input: a malformed value
/// in one column should not take down a technician's whole sync.
library;

/// Parses a numeric column, which arrives as a string.
double? psNum(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

/// Parses a numeric column that is logically a whole number.
///
/// Truncates toward zero rather than throwing, because `"2.00"` and `"2"` are
/// both legitimate representations of the same value.
int? psInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  return psNum(value)?.truncate();
}

/// Reads a boolean column, which arrives as 0 or 1.
///
/// Null is false: an absent flag is not a set flag.
bool psBool(Object? value) {
  if (value == null) return false;
  if (value is bool) return value;
  return (psNum(value) ?? 0) != 0;
}

/// Parses a date, time or timestamp column, which arrives as ISO 8601 text.
DateTime? psDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value.trim());
  return null;
}
