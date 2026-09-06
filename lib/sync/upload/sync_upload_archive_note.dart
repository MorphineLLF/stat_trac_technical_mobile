/// The wording of the upload diagnostics, in one place.
///
/// These lines exist to answer one question that could not be answered when a
/// certificate reached the server without its readings: at which boundary did
/// the readings go missing. Each note names the count on one side of a
/// boundary, so a single run reads as a chain rather than as a guess.
///
/// They are built as pure functions so the tests can assert what a technician's
/// log will actually say, and so the counts cannot drift apart from the words
/// describing them.
library;

/// Marker every upload diagnostic carries, so one filter finds the chain.
const uploadLogTag = 'upload';

/// The wizard handing a finished certificate to the outbox.
///
/// This is the first boundary. If the count here is already 0, the readings
/// never left the screen and nothing downstream is at fault.
String queuedNote({
  required String mobileId,
  required int lines,
  required int savedLocally,
}) {
  final agreement = lines == savedLocally
      ? 'agrees with the local save'
      : 'DISAGREES with the local save ($savedLocally saved)';
  return '[$uploadLogTag] queued $mobileId with $lines readings — $agreement';
}

/// The server accepting a batch but applying less of it than was sent.
///
/// Deliberately loud. A 200 with a short count is the exact shape of the bug
/// that filed a certificate with no test data against it, and it previously
/// printed nothing at all.
String shortApplyNote({
  required String mobileId,
  required int opsSent,
  required int lines,
  required int applied,
}) =>
    '[$uploadLogTag] SHORT APPLY $mobileId — sent $opsSent row ops '
    '($lines readings), server applied $applied. '
    'The certificate is on the server without all of its readings.';

/// A server that will not promise a reading must name its certificate.
///
/// Loud, and deliberately so. This is the exact condition that orphaned 46
/// real readings: a deployed binary older than its code, dropping the
/// certificate reference as an unknown column and counting the write as
/// applied. Nothing in a 200 distinguishes it — only this list does.
String noGuaranteeNote({
  required String mobileId,
  required List<String> enforces,
}) {
  final what = enforces.isEmpty ? 'nothing at all' : enforces.join(', ');
  return '[$uploadLogTag] SERVER GIVES NO CERT-REF GUARANTEE for $mobileId — '
      'it enforces $what. Readings may have been written attached to nothing. '
      'Check the server build before sending more.';
}

/// The signatures leaving the device.
///
/// A certificate is not evidence without them, and until there was a route
/// they existed only on the handset — so their departure is worth a line.
String signaturesQueuedNote({
  required String mobileId,
  required List<String> sides,
  required bool clientNameMissing,
}) {
  final what = sides.isEmpty ? 'none' : sides.join(' + ');
  final warn = clientNameMissing
      ? ' — a client signature was captured but no name was given, so it '
            'CANNOT be sent'
      : '';
  return '[$uploadLogTag] queued signatures for $mobileId: $what$warn';
}
