import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/sync/upload/upload_run_message.dart';
import 'package:stat_trac_technical/sync/upload/upload_worker.dart';

UploadRunResult _run({
  int attempted = 1,
  int applied = 0,
  int conflicted = 0,
  int rejected = 0,
  int failed = 0,
  int shortApplied = 0,
  int unguaranteed = 0,
  bool stoppedForSignal = false,
  bool stoppedForAuth = false,
}) => UploadRunResult(
  attempted: attempted,
  applied: applied,
  conflicted: conflicted,
  rejected: rejected,
  failed: failed,
  shortApplied: shortApplied,
  unguaranteed: unguaranteed,
  stoppedForSignal: stoppedForSignal,
  stoppedForAuth: stoppedForAuth,
);

void main() {
  test('says so plainly when there was nothing to send', () {
    final m = describeUploadRun(_run(attempted: 0));

    expect(m.text, contains('Nothing waiting'));
    expect(m.tone, UploadMessageTone.quiet);
  });

  // The regression this file exists for. A run stopped by a dead token has
  // nothing applied, nothing rejected and nothing conflicted, so with no
  // branch of its own it reaches the closing case and reports "Sent 0
  // certificates" in green — a device that has stopped uploading telling the
  // technician it succeeded.
  test('a dead device token is never reported as a successful send', () {
    final m = describeUploadRun(_run(attempted: 2, stoppedForAuth: true));

    expect(m.text, contains('Sign in'));
    expect(m.text, contains('2'));
    expect(m.text, isNot(contains('Sent')));
    expect(m.tone, UploadMessageTone.alarm);
  });

  // Two stops that need opposite things from the person holding the device:
  // signal returns on its own, a dead token waits for a sign-in that nobody
  // performs while the app is telling them they are offline.
  test('a dead device token is not dressed up as no connection', () {
    final m = describeUploadRun(_run(attempted: 2, stoppedForAuth: true));

    expect(m.text, isNot(contains('connection')));
    expect(m.text, isNot(contains('online')));
  });

  test('no signal is a warning that resolves itself, not an alarm', () {
    final m = describeUploadRun(_run(attempted: 3, stoppedForSignal: true));

    expect(m.text, contains('No connection'));
    expect(m.tone, UploadMessageTone.warning);
  });

  test('a clean run reports what went', () {
    final m = describeUploadRun(_run(attempted: 2, applied: 2));

    expect(m.text, 'Sent 2 certificates.');
    expect(m.tone, UploadMessageTone.success);
  });

  test('a single certificate is not reported in the plural', () {
    expect(describeUploadRun(_run(applied: 1)).text, 'Sent 1 certificate.');
  });

  test('an oversized batch reaches the technician as something to open', () {
    final m = describeUploadRun(_run(attempted: 2, applied: 1, failed: 1));

    expect(m.text, contains('could not be sent'));
    expect(m.tone, UploadMessageTone.alarm);
  });

  // A 200 that applied fewer ops than were sent, and a server that will not
  // promise a reading names its certificate, both outrank the closing
  // success case — that precedence is the whole point of them.
  test('a short apply outranks the success message', () {
    final m = describeUploadRun(_run(applied: 1, shortApplied: 1));

    expect(m.text, contains('without all readings'));
    expect(m.tone, UploadMessageTone.alarm);
  });

  test('a server giving no cert-ref guarantee outranks the success message',
      () {
    final m = describeUploadRun(_run(applied: 1, unguaranteed: 1));

    expect(m.text, contains('does not guarantee'));
    expect(m.tone, UploadMessageTone.alarm);
  });
}
