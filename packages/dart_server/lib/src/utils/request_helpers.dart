import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:relic/relic.dart';

Future<Map<String, dynamic>?> parseJsonBody(Request request) async {
  // Relic ignores a Content-Type header it cannot parse and reads the body
  // as UTF-8. Treat such a request as invalid instead.
  final headers = request.headers;
  if (headers.contains(HeaderName.contentType) &&
      headers.tryGet(Headers.contentType) == null) {
    return null;
  }

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
    body: Body.fromString(jsonEncode(body), mimeType: MimeType.json),
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
