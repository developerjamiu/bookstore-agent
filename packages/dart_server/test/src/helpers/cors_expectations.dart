import 'package:relic/relic.dart';
import 'package:test/test.dart';

/// Expects the three CORS headers that `cors()` adds, spelled exactly as
/// the Flutter client and browsers receive them.
void expectCorsHeaders(Response response, {String origin = '*'}) {
  expect(response.headers['access-control-allow-origin']?.toList(), [origin]);
  expect(response.headers['access-control-allow-methods']?.toList(), [
    'GET, POST, OPTIONS',
  ]);
  expect(response.headers['access-control-allow-headers']?.toList(), [
    'Origin, Content-Type',
  ]);
}
