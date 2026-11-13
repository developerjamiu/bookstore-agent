import 'dart:io';

import 'package:relic/relic.dart';

import 'package:dart_server/src/middleware/cors.dart';
import 'package:dart_server/src/routes/research.dart';

Future<void> main() async {
  final routes = ResearchRoutes();

  // Middleware only runs for requests that match a route, so the router is
  // mounted for every method and path. That way cors() also answers
  // preflights and adds its headers to 404 and 405 responses.
  final app = RelicApp()
    ..use('/', cors())
    ..use('/', logRequests())
    ..any('/**', routes.router.asHandler);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await app.serve(address: InternetAddress.anyIPv4, port: port);

  print('Server running on http://localhost:${server.port}');
}
