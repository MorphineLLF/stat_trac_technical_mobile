import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/features/assets/presentation/widgets/asset_picker_dialog.dart';

// Typing in the hospital search narrows by the start of the name: "a" lists
// the hospitals beginning with A, not every hospital with an a anywhere in it.
void main() {
  const hospitals = [
    'ADDINGTON HOSPITAL',
    'ALBERT LUTHULI HOSPITAL',
    'BARAGWANATH HOSPITAL',
    'KING EDWARD VIII HOSPITAL',
  ];

  List<String> search(String q) => filterHospitals(hospitals, q);

  test('matches from the first letter of the name', () {
    expect(search('a'), ['ADDINGTON HOSPITAL', 'ALBERT LUTHULI HOSPITAL']);
    expect(search('al'), ['ALBERT LUTHULI HOSPITAL']);
  });

  test('does not match letters in the middle of the name', () {
    // "king" contains no leading b, and "BARAGWANATH" is the only B.
    expect(search('b'), ['BARAGWANATH HOSPITAL']);
    expect(search('hospital'), isEmpty);
  });

  test('ignores case and surrounding spaces', () {
    expect(search('  King '), ['KING EDWARD VIII HOSPITAL']);
  });

  test('an empty search lists every hospital', () {
    expect(search(''), hospitals);
  });
}
