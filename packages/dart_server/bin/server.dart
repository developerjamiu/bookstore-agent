import 'dart:io';

import 'package:relic/relic.dart';

import 'package:dart_server/src/routes/research.dart';

Future<void> main() async {
  final app = RelicApp()
    ..use('/', logRequests())
    ..inject(ResearchRoutes());

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await app.serve(address: InternetAddress.anyIPv4, port: port);

  print('Server running on http://localhost:${server.port}');
}
