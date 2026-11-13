import 'dart:io';

import 'package:relic/relic.dart';

import 'package:dart_server/src/app.dart';
import 'package:dart_server/src/routes/research.dart';

Future<void> main() async {
  final portText = Platform.environment['PORT'] ?? '8080';
  final port = int.tryParse(portText);
  if (port == null || port < 0 || port > 65535) {
    stderr.writeln('PORT must be a number from 0 to 65535, got "$portText".');
    exit(1);
  }

  final researchRoutes = ResearchRoutes();

  final app = buildApp(researchRoutes.router);

  final server = await app.serve(address: InternetAddress.anyIPv4, port: port);
  print('');
  print('Server running on http://localhost:${server.port}');
  print('');
  print('Try it:');
  print('  curl -s http://localhost:${server.port}/api/research \\');
  print('    -H "Content-Type: application/json" \\');
  print('    -d \'{"question":"Which genre has the most tracks?"}\' | jq');
  print('');
}
