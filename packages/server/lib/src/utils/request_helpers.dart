import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:shelf/shelf.dart';

Future<Map<String, dynamic>?> parseJsonBody(Request request) async {
  try {
    final text = await request.readAsString();
    if (text.isEmpty) return null;
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    return null;
  } on FormatException {
    return null;
  }
}

Response jsonResponse(Object? body, {int statusCode = 200}) {
  return Response(
    statusCode,
    body: jsonEncode(body),
    headers: {'Content-Type': 'application/json'},
  );
}

Response errorResponse(int statusCode, String message) {
  return jsonResponse({'error': message}, statusCode: statusCode);
}

Response handleGenkitError(GenkitException e) {
  print('Genkit error: $e');
  final message = e.message.toLowerCase();
  if (message.contains('quota') || message.contains('resource_exhausted')) {
    return errorResponse(429, 'API quota exceeded. Please try again later.');
  }
  if (message.contains('high demand')) {
    return errorResponse(
      503,
      'Model is temporarily unavailable. Please retry.',
    );
  }
  return errorResponse(500, 'Agent failed. Check server logs for details.');
}
