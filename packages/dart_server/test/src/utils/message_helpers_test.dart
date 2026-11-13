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

  group('hasQueryResults', () {
    Message toolResponse(String name) => Message(
      role: Role.tool,
      content: [
        ToolResponsePart(
          toolResponse: ToolResponse(name: name, output: 'output'),
        ),
      ],
    );

    test('is true when a runQuery call returned output', () {
      expect(
        hasQueryResults([toolResponse('listTables'), toolResponse('runQuery')]),
        isTrue,
      );
    });

    test('is false when only schema tools returned output', () {
      expect(
        hasQueryResults([
          toolResponse('listTables'),
          toolResponse('describeTable'),
        ]),
        isFalse,
      );
    });

    test('is false for an empty history', () {
      expect(hasQueryResults(const []), isFalse);
    });
  });

  group('buildResearchNotes', () {
    test('includes runQuery results with their SQL', () {
      final response = _buildResponse(
        requestMessages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'question')],
          ),
          Message(
            role: Role.model,
            content: [
              ToolRequestPart(
                toolRequest: ToolRequest(
                  ref: 'q1',
                  name: 'runQuery',
                  input: const {'sql': 'SELECT Name FROM artists'},
                ),
              ),
            ],
          ),
          Message(
            role: Role.tool,
            content: [
              ToolResponsePart(
                toolResponse: ToolResponse(
                  ref: 'q1',
                  name: 'runQuery',
                  output: '[{"Name":"AC/DC"}]',
                ),
              ),
            ],
          ),
        ],
        finalText: 'Found 1 artist.',
      );

      final notes = buildResearchNotes(response);

      expect(notes, contains('[Query: SELECT Name FROM artists]'));
      expect(notes, contains('AC/DC'));
      expect(notes, contains('[Agent summary]'));
      expect(notes, contains('Found 1 artist.'));
    });

    test('excludes listTables and describeTable results', () {
      final response = _buildResponse(
        requestMessages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'question')],
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
                  output: '- artists\n- albums',
                ),
              ),
            ],
          ),
          Message(
            role: Role.model,
            content: [
              ToolRequestPart(
                toolRequest: ToolRequest(
                  name: 'describeTable',
                  input: const {'table': 'artists'},
                ),
              ),
            ],
          ),
          Message(
            role: Role.tool,
            content: [
              ToolResponsePart(
                toolResponse: ToolResponse(
                  name: 'describeTable',
                  output: 'ArtistId INTEGER, Name TEXT',
                ),
              ),
            ],
          ),
        ],
        finalText: 'Schema explored.',
      );

      final notes = buildResearchNotes(response);

      expect(notes, isNot(contains('artists\n- albums')));
      expect(notes, isNot(contains('ArtistId')));
      expect(notes, contains('Schema explored.'));
    });

    test('returns fallback message when no query results exist', () {
      final response = _buildResponse(
        requestMessages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'question')],
          ),
        ],
        finalText: '',
      );

      final notes = buildResearchNotes(response);

      expect(notes, 'No query results were produced during research.');
    });
  });
}

GenerateResult _buildResponse({
  required List<Message> requestMessages,
  required String finalText,
}) {
  final modelResponse = ModelResponse(
    finishReason: FinishReason.stop,
    message: Message(
      role: Role.model,
      content: [TextPart(text: finalText)],
    ),
  );

  return GenerateResult(
    modelResponse,
    request: ModelRequest(messages: requestMessages),
  );
}
