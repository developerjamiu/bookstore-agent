import 'package:dart_server/src/app.dart';
import 'package:relic/relic.dart';
import 'package:test/test.dart';

import 'helpers/cors_expectations.dart';
import 'helpers/in_process_server.dart';

Uri _url(String path) => Uri.parse('http://localhost$path');

void main() {
  late List<String> logLines;
  late Handler app;

  setUp(() {
    logLines = [];
    final routes = RelicRouter()
      ..post('/api/research', (request) => Response.ok());
    app = buildApp(
      routes,
      logger: (message, {stackTrace, type = LoggerType.info}) =>
          logLines.add(message),
    ).asHandler;
  });

  group('buildApp', () {
    test('passes a matching request to the routes and logs it', () async {
      final response = await handle(app, Method.post, _url('/api/research'));

      expect(response.statusCode, 200);
      expectCorsHeaders(response);
      expect(logLines.single, matches(r'POST +\[200\] /api/research$'));
    });

    test('passes a path with a trailing slash to the same route', () async {
      // Relic normalizes the path before routing, so /api/research/ matches
      // /api/research.
      final response = await handle(app, Method.post, _url('/api/research/'));

      expect(response.statusCode, 200);
      expectCorsHeaders(response);
      expect(logLines.single, matches(r'POST +\[200\] /api/research/$'));
    });

    test('answers an unknown path with 404, CORS headers and a log '
        'line', () async {
      final response = await handle(app, Method.get, _url('/nope'));

      expect(response.statusCode, 404);
      expectCorsHeaders(response);
      expect(logLines.single, matches(r'GET +\[404\] /nope$'));
    });

    test('answers a wrong method with 405, Allow, CORS headers and a log '
        'line', () async {
      final response = await handle(app, Method.get, _url('/api/research'));

      expect(response.statusCode, 405);
      expect(response.headers['allow']?.toList(), ['POST']);
      expectCorsHeaders(response);
      expect(logLines.single, matches(r'GET +\[405\] /api/research$'));
    });

    test('answers a preflight on any path before logging', () async {
      final response = await handle(app, Method.options, _url('/nope'));

      expect(response.statusCode, 200);
      expectCorsHeaders(response);
      expect(logLines, isEmpty);
    });
  });
}
