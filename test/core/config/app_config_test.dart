import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/config/app_config.dart';

void main() {
  group('AppConfig.baseUrl', () {
    // Port 9000 was the Horse API's. Horse is retired, and the Go rep API
    // deliberately took that port so the rep handsets would not notice the
    // swap. It does not serve this app's entities, so pointing here again
    // would silently talk to the wrong service rather than fail loudly.
    test('does not point at the retired Horse port', () {
      expect(AppConfig.baseUrl, isNot(contains(':9000')));
      expect(AppConfig.baseUrl, isNot(contains('10.0.2.2')));
    });

    test('uses TLS', () {
      expect(AppConfig.baseUrl, startsWith('https://'));
    });

    test('has no trailing slash so path joins stay predictable', () {
      expect(AppConfig.baseUrl, isNot(endsWith('/')));
    });
  });
}
