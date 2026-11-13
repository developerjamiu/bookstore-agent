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
    final response = await _client.post(
      baseUrl.resolve('/api/research'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'question': question}),
    );

    if (response.statusCode != 200) {
      throw ResearchApiException(
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    return ResearchResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

class ResearchApiException implements Exception {
  final int statusCode;
  final String body;

  ResearchApiException({required this.statusCode, required this.body});

  @override
  String toString() => 'ResearchApiException($statusCode): $body';
}
