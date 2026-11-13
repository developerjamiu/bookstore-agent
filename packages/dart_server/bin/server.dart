import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:relic/relic.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:dart_server/src/agent/setup.dart';
import 'package:dart_server/src/app.dart';
import 'package:dart_server/src/routes/research.dart';

Future<void> main() async {
  final portText = Platform.environment['PORT'] ?? '8080';
  final port = int.tryParse(portText);
  if (port == null || port < 0 || port > 65535) {
    stderr.writeln('PORT must be a number from 0 to 65535, got "$portText".');
    exit(1);
  }

  final dbPath = Platform.script.resolve('../data/music_store.db').toFilePath();
  if (!File(dbPath).existsSync()) {
    stderr.writeln('Database not found at $dbPath.');
    exit(1);
  }
  final db = sqlite3.open(dbPath);

  final ai = Genkit(plugins: [googleAI()]);
  final researchFlow = AISetup(ai: ai, db: db)();

  final researchRoutes = ResearchRoutes(researchFlow: researchFlow);

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
