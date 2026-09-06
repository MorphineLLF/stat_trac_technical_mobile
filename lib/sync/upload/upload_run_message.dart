import 'upload_worker.dart';

/// How loudly a run's outcome needs to be said.
///
/// Kept as a tone rather than a colour so the decision can be tested without a
/// widget tree. The screen maps these onto the theme.
enum UploadMessageTone {
  /// Nothing happened and nothing is wrong.
  quiet,

  /// Everything queued went.
  success,

  /// The work is safe and will go on its own. Nothing for anyone to do.
  warning,

  /// Somebody has to act, and the run must not be mistaken for a success.
  alarm,
}

/// What a drain should tell the technician.
class UploadRunMessage {
  const UploadRunMessage(this.text, this.tone);
  final String text;
  final UploadMessageTone tone;
}

/// Turns a finished run into the one sentence a technician gets.
///
/// **The order of these branches is the substance, not a formality.** Several
/// outcomes leave `applied`, `rejected` and `conflicted` all at zero, so any
/// one of them that has no branch of its own falls through to the closing
/// success case and reports "Sent 0 certificates" in green. That is the exact
/// shape of the failure this app has already had once: a device that has
/// stopped uploading, telling the person holding it that everything went.
///
/// Extracted from the dashboard so each of those branches can be tested
/// without standing up a widget tree — the auth case in particular was written
/// with no test able to reach it.
UploadRunMessage describeUploadRun(UploadRunResult r) {
  if (r.attempted == 0) {
    return const UploadRunMessage(
      'Nothing waiting to send.',
      UploadMessageTone.quiet,
    );
  }

  // Deliberately not the "no connection" wording. This one does not clear up
  // on its own — the device token is dead and somebody has to sign in — and a
  // technician told they are offline will wait instead of acting.
  if (r.stoppedForAuth) {
    return UploadRunMessage(
      'Sign in again to send — ${r.attempted} still queued.',
      UploadMessageTone.alarm,
    );
  }

  if (r.stoppedForSignal) {
    return UploadRunMessage(
      'No connection — ${r.attempted} still queued, it will go when you are '
      'back online.',
      UploadMessageTone.warning,
    );
  }

  if (r.rejected > 0 || r.failed > 0) {
    return UploadRunMessage(
      '${r.rejected + r.failed} could not be sent — open the certificate to '
      'see why.',
      UploadMessageTone.alarm,
    );
  }

  if (r.conflicted > 0) {
    return UploadRunMessage(
      '${r.conflicted} changed on the server and need you.',
      UploadMessageTone.warning,
    );
  }

  // The upload succeeded and that is exactly the problem: this server will not
  // promise a reading must name its certificate, and one that did not orphaned
  // 46 of them while reporting success.
  if (r.unguaranteed > 0) {
    return const UploadRunMessage(
      'Sent, but this server does not guarantee readings are attached — '
      'report before doing more certificates.',
      UploadMessageTone.alarm,
    );
  }

  // The server said yes and applied less than it was sent. Reporting this
  // green is what let a certificate be filed with no test data against it and
  // nobody know.
  if (r.shortApplied > 0) {
    return UploadRunMessage(
      '${r.shortApplied} certificate${r.shortApplied == 1 ? '' : 's'} reached '
      'the server without all readings — do not leave site, report this.',
      UploadMessageTone.alarm,
    );
  }

  return UploadRunMessage(
    'Sent ${r.applied} certificate${r.applied == 1 ? '' : 's'}.',
    UploadMessageTone.success,
  );
}
