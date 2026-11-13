import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'package:dart_server/src/middleware/cors.dart';
import 'package:dart_server/src/routes/research.dart';

Future<void> main() async {
  final researchRoutes = ResearchRoutes();

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
