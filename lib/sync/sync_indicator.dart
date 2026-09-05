/// What the sync indicator should say right now.
enum SyncIndicator { syncing, connecting, connected, offline, error }

/// Decides the indicator from PowerSync's status fields.
///
/// **PowerSync's `downloadError` is sticky.** `SyncStatus.copyWith` keeps the
/// previous error whenever the new one is null:
///
/// ```dart
/// downloadError: downloadError ?? this.downloadError,
/// ```
///
/// So a single transient blip — a dropped stream, a reconnect — leaves it set
/// for the rest of the session. Treating "an error exists" as "sync is
/// failing" therefore makes a perfectly healthy app report failure for ever,
/// which is exactly what happened: one `ClientException: Connection closed
/// while receiving data`, recovered five seconds later, and the chip stayed red
/// while 166,259 rows sat correctly on the device.
///
/// A field app that cries wolf is worse than one with no indicator at all,
/// because a technician who learns to ignore it will also ignore a real
/// failure. So live state wins over remembered state: an error is only
/// reported when the connection is actually down and nothing is being retried.
SyncIndicator syncIndicatorFor({
  required bool connected,
  required bool connecting,
  required bool downloading,
  required bool uploading,
  required Object? error,
}) {
  if (downloading || uploading) return SyncIndicator.syncing;
  if (connected) return SyncIndicator.connected;
  if (connecting) return SyncIndicator.connecting;
  if (error != null) return SyncIndicator.error;
  return SyncIndicator.offline;
}
