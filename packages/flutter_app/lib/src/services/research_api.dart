import 'dart:convert';

import 'package:http/http.dart' as http;

class ToolCall {
  final String tool;
  final String input;

  ToolCall({required this.tool, required this.input});

  factory ToolCall.fromJson(Map<String, dynamic> json) =>
      ToolCall(tool: json['tool'] as String, input: json['input'] as String);
}

class ResearchResult {
  final String answer;
  final List<String> sources;
  final String confidence;
  final List<ToolCall> toolCalls;

  ResearchResult({
    required this.answer,
    required this.sources,
    required this.confidence,
    required this.toolCalls,
  });

  factory ResearchResult.fromJson(Map<String, dynamic> json) => ResearchResult(
    answer: json['answer'] as String,
    sources: (json['sources'] as List).cast<String>(),
    confidence: json['confidence'] as String,
    toolCalls: (json['toolCalls'] as List)
        .map((c) => ToolCall.fromJson(c as Map<String, dynamic>))
        .toList(),
  );
}

class ResearchApi {
  final Uri baseUrl;
  final http.Client _client;

  ResearchApi({required this.baseUrl, required this._client});

  Future<ResearchResult> ask(String question) async {
    final http.Response response;
    try {
      response = await _client.post(
        baseUrl.resolve('/api/research'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'question': question}),
      );
    } on http.ClientException {
      throw ResearchApiException(
        "Can't reach the server at $baseUrl. Is it running?",
      );
    }

    if (response.statusCode != 200) {
      throw ResearchApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }

    return ResearchResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// The server sends errors as `{"error": "..."}`. Falls back to a generic
  /// message when the body is something else.
  static String _errorMessage(http.Response response) {
    final fallback = 'Something went wrong (HTTP ${response.statusCode}).';
    try {
      final body = jsonDecode(response.body);
      return body is Map && body['error'] is String
          ? body['error'] as String
          : fallback;
    } on FormatException {
      return fallback;
    }
  }
}

class ResearchApiException implements Exception {
  /// A message that is safe to show in the app.
  final String message;
  final int? statusCode;

  ResearchApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
