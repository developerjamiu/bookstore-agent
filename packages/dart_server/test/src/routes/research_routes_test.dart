import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_server/src/agent/research_agent.dart';
import 'package:dart_server/src/middleware/cors.dart';
import 'package:dart_server/src/routes/research.dart';
import 'package:dart_server/src/schemas/research_result.dart';
import 'package:dart_server/src/schemas/sql_query_input.dart';
import 'package:dart_server/src/schemas/table_name_input.dart';
import 'package:dart_server/src/schemas/tool_call.dart';
import 'package:genkit/genkit.dart';
import 'package:relic/relic.dart' hide Message;
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

import '../helpers/cors_expectations.dart';
import '../helpers/in_process_server.dart';

final _url = Uri.parse('http://localhost/api/research');

const _jsonType = 'application/json; charset=utf-8';

ResearchResult _cannedResult() => ResearchResult(
  answer: 'Rock has the most tracks, from AC/DC to Motörhead.',
  sources: ['SELECT GenreId, COUNT(*) FROM tracks GROUP BY GenreId'],
  confidence: 'high',
  toolCalls: [ToolCall(tool: 'listTables', input: '{}')],
);

Body _json(Object? value) =>
    Body.fromString(jsonEncode(value), mimeType: MimeType.json);

Headers _contentType(String value) =>
    Headers.build((headers) => headers['Content-Type'] = [value]);

void main() {
  late Genkit ai;
  late List<String> questions;
  late List<String> printed;

  setUp(() {
    ai = Genkit();
    questions = [];
    printed = [];
  });

  tearDown(() async => ai.shutdown());

  /// Defines the research flow with no model behind it. It records each
  /// question and answers with [answer].
  ResearchFlow defineResearchFlow(Future<ResearchResult> Function() answer) {
    return ai.defineFlow(
      name: 'researchFlow',
      inputSchema: SchemanticType.string(),
      outputSchema: ResearchResult.$schema,
      fn: (question, _) {
        questions.add(question);
        return answer();
      },
    );
  }

  /// Sends one request through the routes and CORS middleware, mounted the
  /// way `bin/server.dart` mounts them.
  ///
  /// The lines the route prints go to [printed] instead of the test output.
  /// The route runs [flow] when given, else a flow that answers with [answer].
  Future<Response> send(
    Method method, {
    Headers? headers,
    Body? body,
    Future<ResearchResult> Function()? answer,
    ResearchFlow? flow,
  }) {
    flow ??= defineResearchFlow(answer ?? () async => _cannedResult());
    final routes = ResearchRoutes(researchFlow: flow);
    final app = RelicApp()
      ..use('/', cors())
      ..any('/**', routes.router.asHandler);
    return runZoned(
      () => handle(app.asHandler, method, _url, headers: headers, body: body),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => printed.add(line),
      ),
    );
  }

  Future<void> expectJsonError(
    Response response,
    int statusCode,
    String message,
  ) async {
    expect(response.statusCode, statusCode);
    expect(response.body.bodyType?.toHeaderValue(), _jsonType);
    expect(await response.readAsString(), '{"error":"$message"}');
    expectCorsHeaders(response);
  }

  group('POST /api/research', () {
    test('answers 200 with the flow result as JSON', () async {
      final response = await send(
        Method.post,
        // The Content-Type the Flutter client sends.
        headers: _contentType('application/json; charset=utf-8'),
        body: _json({'question': 'Which genre has the most tracks?'}),
      );

      expect(response.statusCode, 200);
      expect(response.body.bodyType?.toHeaderValue(), _jsonType);
      expect(
        await response.readAsString(),
        '{"answer":"Rock has the most tracks, from AC/DC to Motörhead.",'
        '"sources":["SELECT GenreId, COUNT(*) FROM tracks GROUP BY GenreId"],'
        '"confidence":"high",'
        '"toolCalls":[{"tool":"listTables","input":"{}"}]}',
      );
      expectCorsHeaders(response);
      expect(questions, ['Which genre has the most tracks?']);
      expect(printed, isEmpty);
    });

    final invalidBodies = <String, Body Function()>{
      'malformed JSON': () =>
          Body.fromString('{not json', mimeType: MimeType.json),
      'an empty body': Body.empty,
      'a JSON array': () => _json([1, 2]),
      // Valid JSON apart from the byte 0xff in the string, so only strict
      // UTF-8 decoding rejects it.
      'invalid UTF-8 in a JSON string': () => Body.fromData(
        Uint8List.fromList([
          ...utf8.encode('{"question":"'),
          0xff,
          ...utf8.encode('"}'),
        ]),
        mimeType: MimeType.json,
      ),
    };
    for (final MapEntry(key: description, value: body)
        in invalidBodies.entries) {
      test('answers 400 for $description', () async {
        final response = await send(Method.post, body: body());

        await expectJsonError(response, 400, 'Invalid JSON body');
        expect(questions, isEmpty);
      });
    }

    for (final contentType in ['garbage', 'application/json; charset']) {
      test('answers 400 for the Content-Type "$contentType", which does not '
          'parse', () async {
        final response = await send(
          Method.post,
          headers: _contentType(contentType),
          body: _json({'question': 'Which genre has the most tracks?'}),
        );

        await expectJsonError(response, 400, 'Invalid JSON body');
        expect(questions, isEmpty);
      });
    }

    final invalidQuestions = <String, Map<String, Object?>>{
      'a missing question': {},
      'an empty question': {'question': ''},
      'a blank question': {'question': '   '},
      'a question that is not a string': {'question': 42},
    };
    for (final MapEntry(key: description, value: payload)
        in invalidQuestions.entries) {
      test('answers 400 for $description', () async {
        final response = await send(Method.post, body: _json(payload));

        await expectJsonError(response, 400, 'question is required');
        expect(questions, isEmpty);
      });
    }

    final genkitErrors = <StatusCode, (int, String)>{
      StatusCode.resourceExhausted: (
        429,
        'API quota exceeded. Please try again later.',
      ),
      StatusCode.unavailable: (
        503,
        'Model is temporarily unavailable. Please retry.',
      ),
      StatusCode.invalidArgument: (
        500,
        'Agent failed. Check server logs for details.',
      ),
      StatusCode.internal: (
        500,
        'Agent failed. Check server logs for details.',
      ),
    };
    for (final MapEntry(key: status, value: (statusCode, message))
        in genkitErrors.entries) {
      test(
        'answers $statusCode when the flow fails with ${status.wireName}',
        () async {
          final response = await send(
            Method.post,
            body: _json({'question': 'Which genre has the most tracks?'}),
            answer: () async =>
                throw GenkitException('failed on purpose', status: status),
          );

          await expectJsonError(response, statusCode, message);
          expect(printed.single, startsWith('Genkit error: '));
          expect(printed.single, contains('failed on purpose'));
          expect(printed.single, contains(status.wireName));
        },
      );
    }

    test('maps by status, not by the words in the message', () async {
      final response = await send(
        Method.post,
        body: _json({'question': 'Which genre has the most tracks?'}),
        answer: () async => throw GenkitException(
          'RESOURCE_EXHAUSTED: quota exceeded, high demand',
          status: StatusCode.internal,
        ),
      );

      await expectJsonError(
        response,
        500,
        'Agent failed. Check server logs for details.',
      );
    });

    group('with the research agent and a fake model', () {
      /// The research agent's flow, on a fake model that answers with [fn].
      /// Every tool answers `[]`, except that runQuery runs [runQuery] when
      /// given.
      ResearchFlow agentFlow(
        Future<ModelResponse> Function(ModelRequest request) fn, {
        Future<String> Function()? runQuery,
      }) {
        ai.defineModel(name: 'fake/model', fn: (request, _) => fn(request));
        Tool<I, String> tool<I>(String name, SchemanticType<I> input) =>
            ai.defineTool(
              name: name,
              description: name,
              inputSchema: input,
              outputSchema: SchemanticType.string(),
              fn: (_, _) async => .response(
                name == 'runQuery' && runQuery != null
                    ? await runQuery()
                    : '[]',
              ),
            );
        return ResearchAgent(
          ai: ai,
          model: modelRef('fake/model'),
          listTablesTool: tool('listTables', SchemanticType.voidSchema()),
          describeTableTool: tool('describeTable', TableNameInput.$schema),
          runQueryTool: tool('runQuery', SqlQueryInput.$schema),
        ).define();
      }

      ModelResponse text(String text) => ModelResponse(
        finishReason: FinishReason.stop,
        message: Message(
          role: Role.model,
          content: [TextPart(text: text)],
        ),
      );

      /// Runs one query, then replies with [finalText] once it has a result.
      ModelResponse queryThen(ModelRequest request, String finalText) {
        if (request.messages.any((m) => m.role == Role.tool)) {
          return text(finalText);
        }
        return ModelResponse(
          finishReason: FinishReason.stop,
          message: Message(
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
        );
      }

      test('answers 500 when the model fails', () async {
        final response = await send(
          Method.post,
          body: _json({'question': 'How many artists are there?'}),
          flow: agentFlow(
            (_) async => throw GenkitException(
              'apiKey must be set to an API key',
              status: StatusCode.invalidArgument,
            ),
          ),
        );

        await expectJsonError(
          response,
          500,
          'Agent failed. Check server logs for details.',
        );
        expect(printed.single, startsWith('Genkit error: '));
        expect(printed.single, contains('apiKey must be set'));
      });

      test('answers 429 when the model reports an exhausted quota', () async {
        final response = await send(
          Method.post,
          body: _json({'question': 'How many artists are there?'}),
          flow: agentFlow(
            (_) async => throw GenkitException(
              'Quota exceeded for this model.',
              status: StatusCode.resourceExhausted,
            ),
          ),
        );

        await expectJsonError(
          response,
          429,
          'API quota exceeded. Please try again later.',
        );
      });

      test('answers 500 when a tool fails during research', () async {
        final response = await send(
          Method.post,
          body: _json({'question': 'How many artists are there?'}),
          flow: agentFlow(
            (request) async => ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
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
            ),
            runQuery: () async => throw StateError('database is locked'),
          ),
        );

        await expectJsonError(
          response,
          500,
          'Agent failed. Check server logs for details.',
        );
        expect(printed.single, startsWith('Genkit error: '));
        expect(printed.single, contains('tool "runQuery" failed'));
      });

      test('answers 500 when the final reply does not parse', () async {
        final response = await send(
          Method.post,
          body: _json({'question': 'How many artists are there?'}),
          flow: agentFlow(
            (request) async => queryThen(request, 'Sorry, no JSON today.'),
          ),
        );

        await expectJsonError(
          response,
          500,
          'Agent failed. Check server logs for details.',
        );
        expect(printed.single, startsWith('Genkit error: '));
        expect(printed.single, contains('expected schema'));
      });

      test('answers 500 when the final reply has the wrong shape', () async {
        final response = await send(
          Method.post,
          body: _json({'question': 'How many artists are there?'}),
          flow: agentFlow(
            (request) async => queryThen(request, '{"answer": 42}'),
          ),
        );

        await expectJsonError(
          response,
          500,
          'Agent failed. Check server logs for details.',
        );
        expect(printed.single, startsWith('Unexpected error: '));
      });
    });

    test('answers 500 when the flow throws any other error', () async {
      final response = await send(
        Method.post,
        body: _json({'question': 'Which genre has the most tracks?'}),
        answer: () async => throw StateError('flow failed on purpose'),
      );

      await expectJsonError(
        response,
        500,
        'Agent failed. Check server logs for details.',
      );
      expect(printed, ['Unexpected error: Bad state: flow failed on purpose']);
    });
  });

  test(
    'answers other methods with 405, Allow: POST and the CORS headers',
    () async {
      final response = await send(Method.get);

      expect(response.statusCode, 405);
      expect(response.headers['allow'], ['POST']);
      expectCorsHeaders(response);
      expect(questions, isEmpty);
    },
  );

  group('OPTIONS /api/research', () {
    test('answers the preflight with 200 and the CORS headers', () async {
      final response = await send(Method.options);

      expect(response.statusCode, 200);
      expect(await response.readAsString(), isEmpty);
      expect(
        response.body.bodyType?.toHeaderValue(),
        'text/plain; charset=utf-8',
      );
      expectCorsHeaders(response);
      expect(questions, isEmpty);
    });
  });
}
