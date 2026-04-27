abstract interface class SyncService {
  /// Replays all unsynced change-log entries against the Horse API.
  /// Implementations live in a concrete class wired up once the database
  /// and API layers are built (Phase 1 — §8 of spec).
  Future<void> sync();

  /// Queues a binary artefact (photo, signature) for upload with
  /// exponential backoff. [tableRef] identifies the owning table,
  /// [rowId] the owning row.
  Future<void> enqueueBinaryUpload({
    required String filePath,
    required String tableRef,
    required int rowId,
  });
}
