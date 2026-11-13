import 'package:dart_server/src/middleware/cors.dart';
import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../helpers/cors_expectations.dart';
import '../helpers/in_process_server.dart';

final _url = Uri.parse('http://localhost/api/research');

Response _created(Request request) => Response(
  201,
  body: Body.fromString('created'),
  headers: Headers.build((headers) => headers['X-Custom'] = ['kept']),
);

void main() {
  group('cors', () {
    test('answers a preflight itself with 200, an empty body and the '
        'CORS headers', () async {
      var innerCalled = false;
      final handler = cors()((request) {
        innerCalled = true;
        return Response.ok();
      });

      final response = await handle(handler, Method.options, _url);

      expect(response.statusCode, 200);
      expect(await response.readAsString(), isEmpty);
      expect(
        response.body.bodyType?.toHeaderValue(),
        'text/plain; charset=utf-8',
      );
      expectCorsHeaders(response);
      expect(innerCalled, isFalse);
    });

    test('adds the CORS headers to the inner response and keeps the '
        'rest of it', () async {
      final response = await handle(cors()(_created), Method.post, _url);

      expect(response.statusCode, 201);
      expect(await response.readAsString(), 'created');
      expect(response.headers['x-custom']?.toList(), ['kept']);
      expectCorsHeaders(response);
    });

    test('allows the given origin', () async {
      final handler = cors(origin: 'https://example.com')(_created);

      final response = await handle(handler, Method.post, _url);

      expectCorsHeaders(response, origin: 'https://example.com');
    });
  });
}
