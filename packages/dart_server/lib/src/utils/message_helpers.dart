import 'dart:convert';

import 'package:genkit/genkit.dart';

import '../schemas/tool_call.dart';

/// Extracts all tool requests from a conversation as [ToolCall] records.
///
/// ```
/// [ToolCall(tool: "listTables", input: "{}"),
///  ToolCall(tool: "describeTable", input: "{\"table\":\"artists\"}"),
///  ToolCall(tool: "runQuery", input: "{\"sql\":\"SELECT Name FROM artists\"}")]
/// ```
List<ToolCall> extractToolCalls(List<Message> messages) {
  final calls = <ToolCall>[];
  for (final message in messages) {
    for (final part in message.content) {
      final toolRequestPart = part.toolRequestPart;
      if (toolRequestPart == null) continue;
      final request = toolRequestPart.toolRequest;
      calls.add(
        ToolCall(
          tool: request.name,
          input: jsonEncode(request.input ?? const <String, dynamic>{}),
        ),
      );
    }
  }
  return calls;
}

/// Builds synthesis-ready notes from a completed research response.
///
/// Includes only `runQuery` results (not schema exploration output)
/// paired with the SQL that produced them, plus the agent's summary.
///
/// ```
/// [Query: SELECT Name FROM artists LIMIT 3]
/// [{"Name":"AC/DC"},{"Name":"Led Zeppelin"},{"Name":"Queen"}]
///
/// [Agent summary]
/// The database contains 15 artists.
/// ```
String buildResearchNotes(GenerateResponseHelper response) {
  final buffer = StringBuffer();

  for (final message in response.messages) {
    if (message.role == Role.tool) {
      for (final part in message.content) {
        final toolResponsePart = part.toolResponsePart;
        if (toolResponsePart == null) continue;
        final toolResponse = toolResponsePart.toolResponse;
        if (toolResponse.name != 'runQuery') continue;
        final output = toolResponse.output;
        if (output == null) continue;

        final sql = _findQueryForResponse(response.messages, toolResponse);
        if (sql != null) buffer.writeln('[Query: $sql]');
        buffer.writeln(output is String ? output : jsonEncode(output));
        buffer.writeln();
      }
    }
  }

  final modelSummary = response.text;
  if (modelSummary.isNotEmpty) {
    buffer.writeln('[Agent summary]');
    buffer.writeln(modelSummary);
  }

  final result = buffer.toString();
  if (result.trim().isEmpty) {
    return 'No query results were produced during research.';
  }
  return result;
}

String? _findQueryForResponse(
  List<Message> messages,
  ToolResponse toolResponse,
) {
  for (final message in messages) {
    for (final part in message.content) {
      final request = part.toolRequestPart;
      if (request == null) continue;
      if (request.toolRequest.ref == toolResponse.ref &&
          request.toolRequest.name == 'runQuery') {
        final input = request.toolRequest.input;
        return input?['sql'] as String?;
      }
    }
  }
  return null;
}
