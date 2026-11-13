import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:dart_server/src/utils/message_helpers.dart';
import 'package:test/test.dart';

void main() {
  group('extractToolCalls', () {
    test('extracts tool requests from model messages', () {
      final messages = [
        Message(
          role: Role.user,
          content: [TextPart(text: 'hi')],
        ),
        Message(
          role: Role.model,
          content: [
            ToolRequestPart(
              toolRequest: ToolRequest(name: 'listTables', input: const {}),
            ),
          ],
        ),
        Message(
          role: Role.tool,
          content: [
            ToolResponsePart(
              toolResponse: ToolResponse(
                name: 'listTables',
                output: 'tables...',
              ),
            ),
          ],
        ),
        Message(
          role: Role.model,
          content: [
            ToolRequestPart(
              toolRequest: ToolRequest(
                name: 'runQuery',
                input: const {'sql': 'SELECT 1'},
              ),
            ),
          ],
        ),
      ];

      final calls = extractToolCalls(messages);

      expect(calls, hasLength(2));
      expect(calls[0].tool, 'listTables');
      expect(calls[0].input, '{}');
      expect(calls[1].tool, 'runQuery');
      expect(jsonDecode(calls[1].input), {'sql': 'SELECT 1'});
    });

    test('records an input that is not a JSON object as "{}"', () {
      final messages = [
        Message(
          role: Role.model,
          content: [
            ToolRequestPart(toolRequest: ToolRequest(name: 'listTables')),
            ToolRequestPart(
              toolRequest: ToolRequest(name: 'listTables', input: 'NULL'),
            ),
            ToolRequestPart(
              toolRequest: ToolRequest(name: 'listTables', input: const [1]),
            ),
          ],
        ),
      ];

      final calls = extractToolCalls(messages);

      expect(calls.map((c) => c.input), ['{}', '{}', '{}']);
    });

    test('returns empty list when no tool requests exist', () {
      final messages = [
        Message(
          role: Role.user,
          content: [TextPart(text: 'hi')],
        ),
        Message(
          role: Role.model,
          content: [TextPart(text: 'hello')],
        ),
      ];

      expect(extractToolCalls(messages), isEmpty);
    });
  });
}
