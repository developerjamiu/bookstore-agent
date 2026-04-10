import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../utils/request_helpers.dart';

class ResearchRoutes {
  Router get router {
    final router = Router();
    router.post('/api/research', _research);
    return router;
  }

  Future<Response> _research(Request request) async {
    final body = await parseJsonBody(request);
    if (body == null) return errorResponse(400, 'Invalid JSON body');

    final question = body['question'];
    if (question is! String || question.trim().isEmpty) {
      return errorResponse(400, 'question is required');
    }

    // TODO: Replace this placeholder with a real agent flow.
    return jsonResponse({
      'answer': 'This is a placeholder. Complete the codelab to power this '
          'with a real AI agent that explores the music store database!',
      'sources': <String>[],
      'confidence': 'low',
      'toolCalls': <Map<String, String>>[],
    });
  }
}
