import 'package:flutter/foundation.dart';

enum ChangeOperation { insert, update, delete }

@immutable
class ChangeLogEntry {
  const ChangeLogEntry({
    required this.id,
    required this.tableName,
    required this.rowId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    this.syncedAt,
  });

  final int id;
  final String tableName;
  final int rowId;
  final ChangeOperation operation;

  /// JSON snapshot of the changed fields.
  final Map<String, dynamic> payload;

  final DateTime createdAt;

  /// Null until successfully replayed against the Horse API.
  final DateTime? syncedAt;

  bool get isSynced => syncedAt != null;
}
