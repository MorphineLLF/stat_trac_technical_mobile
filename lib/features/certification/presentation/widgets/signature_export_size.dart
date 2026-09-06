import 'dart:ui';

/// The pen width both signature pads draw with.
///
/// Named because the export size depends on it: a stroke laid along the edge
/// of the pad is drawn half a pen either side of the point, and the package
/// measures the drawing from the outside of that.
const double signaturePenStrokeWidth = 2;

/// The canvas both signatures are exported on.
///
/// **Both sides of a certificate must be the same shape, and until this
/// existed they were not.** `toPngBytes()` with no dimensions exports the
/// bounding box of the strokes, so one signature came out 123x97 and the
/// other 180x82 on the same certificate — the file recorded how somebody
/// signed rather than what they signed on.
///
/// The pad is the right canvas because it is the one thing both signatures
/// share: the two pads are laid out under identical constraints, so exporting
/// at pad size makes the two files identical by construction rather than by
/// arithmetic that could drift.
///
/// **It is padded, never scaled.** The package centres the drawing in whatever
/// canvas it is given and asserts the canvas is at least as big as the
/// drawing — so the allowance below is not cosmetic. Without it a signature
/// touching the edge of the pad measures wider than the pad, trips that
/// assert in debug, and in release is silently cropped, which on a document
/// that is evidence is the worst of the three outcomes.
Size signatureExportSize(Size padSize) {
  const allowance = 2 * signaturePenStrokeWidth;
  return Size(
    (padSize.width + allowance).ceilToDouble(),
    (padSize.height + allowance).ceilToDouble(),
  );
}
