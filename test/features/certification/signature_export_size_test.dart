import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/certification/presentation/widgets/signature_export_size.dart';

void main() {
  // Two signatures on one certificate came out 123x97 and 180x82, because
  // toPngBytes() with no dimensions exports the bounding box of the strokes —
  // so the file size was a record of how somebody signed rather than of what
  // the pad is. Both sides of a certificate should be the same shape.
  test('the same pad gives the same size, whatever was drawn on it', () {
    const pad = Size(1000, 180);

    expect(signatureExportSize(pad), signatureExportSize(pad));
  });

  test('is never smaller than the pad, whose drawing it must contain', () {
    const pad = Size(1000, 180);
    final size = signatureExportSize(pad);

    // The package pads and centres, it never scales, and it asserts that the
    // export is at least as big as the drawing. A stroke reaching the edge of
    // the pad measures penStrokeWidth wider than the pad on each side, so the
    // export has to allow for it or a real signature is cropped.
    expect(size.width, greaterThanOrEqualTo(1000 + 2 * signaturePenStrokeWidth));
    expect(
      size.height,
      greaterThanOrEqualTo(180 + 2 * signaturePenStrokeWidth),
    );
  });

  test('is whole pixels — an image cannot be 183.5 wide', () {
    final size = signatureExportSize(const Size(999.6, 180.4));

    expect(size.width, size.width.roundToDouble());
    expect(size.height, size.height.roundToDouble());
  });

  test('a narrower pad still contains its own drawing', () {
    final size = signatureExportSize(const Size(320, 180));

    expect(size.width, greaterThanOrEqualTo(320 + 2 * signaturePenStrokeWidth));
  });
}
