import 'dart:io';

import 'package:relic/relic.dart';

import 'package:dart_server/src/middleware/cors.dart';
import 'package:dart_server/src/routes/research.dart';

Future<void> main() async {
  final routes = ResearchRoutes();

  // Mounted for every path so cors() also reaches preflights and 404/405s.
  final app = RelicApp()
    ..use('/', cors())
    ..use('/', logRequests())
    ..any('/**', routes.router.asHandler);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await app.serve(address: InternetAddress.anyIPv4, port: port);

  print('Server running on http://localhost:${server.port}');
}
