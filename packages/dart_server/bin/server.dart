import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:sqlite3/sqlite3.dart';

import 'package:dart_server/src/agent/setup.dart';
import 'package:dart_server/src/middleware/cors.dart';
import 'package:dart_server/src/routes/research.dart';

Future<void> main() async {
  final dbPath = Platform.script.resolve('../data/music_store.db').toFilePath();
  if (!File(dbPath).existsSync()) {
    stderr.writeln('Database not found at $dbPath.');
    exit(1);
  }
  final db = sqlite3.open(dbPath);

  final ai = Genkit(plugins: [googleAI()]);
  final researchFlow = AISetup(ai: ai, db: db)();

  final researchRoutes = ResearchRoutes(researchFlow: researchFlow);

  final handler = const Pipeline()
      .addMiddleware(cors())
      .addMiddleware(logRequests())
      .addHandler(researchRoutes.router.call);

  final server = await io.serve(handler, '0.0.0.0', 8080);
  print('');
  print('Server running on http://localhost:${server.port}');
  print('');
  print('Try it:');
  print('  curl -s http://localhost:${server.port}/api/research \\');
  print('    -H "Content-Type: application/json" \\');
  print('    -d \'{"question":"Which genre has the most tracks?"}\' | jq');
  print('');
}
