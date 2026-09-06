import 'dart:convert';
import 'dart:typed_data';

import '../../../../sync/upload/certificate_upload.dart';
import '../../../../sync/upload/sync_upload_batch.dart';

/// A facility signature for a certificate that is already issued.
///
/// **Signing after issue is the one write this application allows on a closed
/// certificate, and that is deliberate.** What was measured cannot change;
/// who signed for it is what happens next. A certificate can sit issued and
/// unsigned indefinitely, so this fills that gap rather than working around a
/// rule — confirmed against the server's own `SaveSignature`.
///
/// The certificate is named by its **mobile id**, never its server key. The
/// server resolves it from the table when it is not in the batch, so a
/// certificate uploaded last week signs today with nothing special.
///
/// A batch of one sign op is fine — nothing else needs to travel with it.
CertificateUpload facilitySignatureUpload({
  required String certificateMobileId,
  required Uint8List png,
  required String clientName,
}) {
  return CertificateUpload(
    mobileId: certificateMobileId,
    // Its own key. The outbox is keyed, and reusing the issue-time batch's
    // key would REPLACE work still waiting to go rather than queue beside
    // it — which is how a set of readings was nearly lost to a signature
    // once already.
    queueKey: '$certificateMobileId:sign-client-later',
    certificate: const {},
    lines: const [],
    signatures: [
      CertificateSignature(
        which: SignatureSide.client,
        // Standard, padded base64. The server refuses URL-safe or unpadded
        // rather than guessing at it.
        png: base64Encode(png),
        clientName: clientName.trim(),
      ),
    ],
  );
}
