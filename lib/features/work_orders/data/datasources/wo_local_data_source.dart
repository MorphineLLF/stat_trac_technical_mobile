import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../../database/database_helper.dart';
import '../../../../sync/change_log_entry.dart';
import '../../domain/entities/work_order.dart';
import '../../domain/entities/work_order_enums.dart';
import '../models/work_order_model.dart';

abstract interface class WoLocalDataSource {
  Future<List<WorkOrderModel>> getAll({DateTime? since});
  Future<List<WorkOrderModel>> getTodays();
  Future<WorkOrderModel?> getById(int id);
  Future<int> insert(WorkOrderModel wo);
  Future<void> upsert(WorkOrderModel wo);
  Future<void> insertStatusHistory({
    required int workOrderId,
    required WoStatus? oldStatus,
    required WoStatus newStatus,
    required int changedBy,
    String? notes,
    double? gpsLat,
    double? gpsLng,
  });
  Future<List<WorkOrderStatusHistory>> getStatusHistory(int workOrderId);
  Future<void> insertChangeLog({
    required String tableName,
    required int rowId,
    required ChangeOperation operation,
    required Map<String, dynamic> payload,
    required int userId,
  });
}

class WoLocalDataSourceImpl implements WoLocalDataSource {
  WoLocalDataSourceImpl(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Future<Database> get _db => _dbHelper.database;

  @override
  Future<List<WorkOrderModel>> getAll({DateTime? since}) async {
    final db = await _db;
    final rows = since == null
        ? await db.query('work_orders', orderBy: 'sla_due_at ASC')
        : await db.query(
            'work_orders',
            where: 'updated_at > ?',
            whereArgs: [since.toIso8601String()],
            orderBy: 'sla_due_at ASC',
          );
    return rows.map(WorkOrderModel.fromMap).toList();
  }

  @override
  Future<List<WorkOrderModel>> getTodays() async {
    final db = await _db;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).toIso8601String();
    final end =
        DateTime(today.year, today.month, today.day, 23, 59, 59).toIso8601String();
    final rows = await db.query(
      'work_orders',
      where: '''
        status NOT IN ('closed','cancelled','rejected')
        AND (
          (scheduled_start >= ? AND scheduled_start <= ?)
          OR (sla_due_at >= ? AND sla_due_at <= ?)
          OR status IN ('in_progress','paused','awaiting_parts','on_site','en_route','accepted')
        )
      ''',
      whereArgs: [start, end, start, end],
      orderBy: 'priority ASC, sla_due_at ASC',
    );
    return rows.map(WorkOrderModel.fromMap).toList();
  }

  @override
  Future<WorkOrderModel?> getById(int id) async {
    final db = await _db;
    final rows =
        await db.query('work_orders', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return WorkOrderModel.fromMap(rows.first);
  }

  @override
  Future<int> insert(WorkOrderModel wo) async {
    final db = await _db;
    final map = Map<String, dynamic>.from(wo.toMap())..remove('id');
    return db.insert('work_orders', map);
  }

  @override
  Future<void> upsert(WorkOrderModel wo) async {
    final db = await _db;
    await db.insert(
      'work_orders',
      wo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertStatusHistory({
    required int workOrderId,
    required WoStatus? oldStatus,
    required WoStatus newStatus,
    required int changedBy,
    String? notes,
    double? gpsLat,
    double? gpsLng,
  }) async {
    final db = await _db;
    await db.insert('work_order_status_history', {
      'work_order_id': workOrderId,
      'old_status': oldStatus?.value,
      'new_status': newStatus.value,
      'changed_by': changedBy,
      'notes': notes,
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      'changed_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<WorkOrderStatusHistory>> getStatusHistory(
      int workOrderId) async {
    final db = await _db;
    final rows = await db.query(
      'work_order_status_history',
      where: 'work_order_id = ?',
      whereArgs: [workOrderId],
      orderBy: 'changed_at ASC',
    );
    return rows
        .map((r) => WorkOrderStatusHistory(
              id: r['id'] as int,
              workOrderId: r['work_order_id'] as int,
              oldStatus: r['old_status'] != null
                  ? WoStatus.fromValue(r['old_status'] as String)
                  : null,
              newStatus: WoStatus.fromValue(r['new_status'] as String),
              changedBy: r['changed_by'] as int,
              notes: r['notes'] as String?,
              gpsLat: r['gps_lat'] as double?,
              gpsLng: r['gps_lng'] as double?,
              changedAt: DateTime.parse(r['changed_at'] as String),
            ))
        .toList();
  }

  @override
  Future<void> insertChangeLog({
    required String tableName,
    required int rowId,
    required ChangeOperation operation,
    required Map<String, dynamic> payload,
    required int userId,
  }) async {
    final db = await _db;
    await db.insert('change_log', {
      'table_name': tableName,
      'row_id': rowId,
      'operation': operation.name,
      'payload': jsonEncode(payload),
      'device_id': 'device', // TODO(phase1): inject real device ID
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
