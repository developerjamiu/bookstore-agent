import 'dart:io';

import 'package:relic/relic.dart';

import 'package:dart_server/src/app.dart';
import 'package:dart_server/src/routes/research.dart';

Future<void> main() async {
  final routes = ResearchRoutes();

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await buildApp(
    routes.router,
  ).serve(address: InternetAddress.anyIPv4, port: port);

  print('Server running on http://localhost:${server.port}');
}
