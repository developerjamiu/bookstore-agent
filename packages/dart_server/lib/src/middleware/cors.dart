import 'package:relic/relic.dart';

Middleware cors({String origin = '*'}) {
  void addCorsHeaders(MutableHeaders headers) {
    headers['Access-Control-Allow-Origin'] = [origin];
    headers['Access-Control-Allow-Methods'] = ['GET, POST, OPTIONS'];
    headers['Access-Control-Allow-Headers'] = ['Origin, Content-Type'];
  }

  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == Method.options) {
        return Response.ok(
          // An empty text/plain body. Without a body, relic would send this
          // answer with no Content-Type at all.
          body: Body.fromString(''),
          headers: Headers.build(addCorsHeaders),
        );
      }

      final result = await innerHandler(request);
      // Hijacked connections and WebSocket upgrades have no headers to set.
      if (result is! Response) return result;
      return result.copyWith(headers: result.headers.transform(addCorsHeaders));
    };
  };
}
