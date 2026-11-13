import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';
import 'package:dart_server/src/agent/research_agent.dart';
import 'package:dart_server/src/schemas/sql_query_input.dart';
import 'package:dart_server/src/schemas/table_name_input.dart';
import 'package:test/test.dart';

void main() {
  late Genkit ai;
  late ResearchAgent agent;

  /// What the fake runQuery tool answers. Rows unless a test changes it.
  late String runQueryOutput;

  /// Builds an agent that talks to the fake model named [model], with
  /// [runQueryTool] in place of the fake runQuery tool when given.
  late ResearchAgent Function(
    String model, {
    Tool<SqlQueryInput, String>? runQueryTool,
  })
  agentFor;

  setUp(() {
    ai = Genkit();
    runQueryOutput = jsonEncode([
      {'Name': 'AC/DC'},
      {'Name': 'Led Zeppelin'},
      {'Name': 'Queen'},
    ]);

    ai.defineModel(
      name: 'fake/model',
      fn: (request, _) async {
        if (request.output != null) {
          return _structuredResponse(request);
        }
        return _toolCallingResponse(request);
      },
    );

    final listTablesTool = ai.defineTool(
      name: 'listTables',
      description: 'List tables.',
      inputSchema: SchemanticType.voidSchema(),
      outputSchema: SchemanticType.string(),
      fn: (_, _) async => .response(
        'Tables in the database:\n- artists\n- albums\n- tracks\n- genres',
      ),
    );

    final describeTableTool = ai.defineTool(
      name: 'describeTable',
      description: 'Describe a table.',
      inputSchema: TableNameInput.$schema,
      outputSchema: SchemanticType.string(),
      fn: (input, _) async => .response(
        'Columns in "${input.table}":\n'
        '- ArtistId INTEGER PRIMARY KEY\n'
        '- Name TEXT NOT NULL',
      ),
    );

    final defaultRunQueryTool = ai.defineTool(
      name: 'runQuery',
      description: 'Run a SQL query.',
      inputSchema: SqlQueryInput.$schema,
      outputSchema: SchemanticType.string(),
      fn: (input, _) async => .response(runQueryOutput),
    );

    agentFor = (model, {Tool<SqlQueryInput, String>? runQueryTool}) =>
        ResearchAgent(
          ai: ai,
          model: modelRef(model),
          listTablesTool: listTablesTool,
          describeTableTool: describeTableTool,
          runQueryTool: runQueryTool ?? defaultRunQueryTool,
        );
    agent = agentFor('fake/model');
  });

  tearDown(() async => ai.shutdown());

  group('ResearchAgent', () {
    test('answers a database question with high confidence', () async {
      final result = await agent.research('What artists are in the database?');

      expect(result.confidence, 'high');
      expect(result.answer, contains('AC/DC'));
    });

    test('records the exploration sequence', () async {
      final result = await agent.research('What artists are in the database?');

      final toolNames = result.toolCalls.map((c) => c.tool).toList();
      expect(toolNames, contains('listTables'));
      expect(toolNames, contains('describeTable'));
      expect(toolNames, contains('runQuery'));
    });

    test('includes SQL queries in sources', () async {
      final result = await agent.research('What artists are in the database?');

      expect(result.sources, isNotEmpty);
      expect(result.sources.first, contains('SELECT'));
    });

    test('returns low confidence for unanswerable questions', () async {
      final result = await agent.research('xyzzy nonsense gibberish');

      expect(result.confidence, 'low');
    });

    test('returns low confidence and no sources when no query ran, even if '
        'synthesis says high', () async {
      ai.defineModel(
        name: 'fake/refuses',
        fn: (request, _) async => _textResponse(
          request.output != null
              ? jsonEncode({
                  'answer': 'I have no weather data.',
                  'sources': ['SELECT 1'],
                  'confidence': 'high',
                })
              : 'The database has no weather data.',
        ),
      );

      final result = await agentFor(
        'fake/refuses',
      ).research('What is the weather in Paris?');

      expect(result.answer, 'I have no weather data.');
      expect(result.confidence, 'low');
      expect(result.sources, isEmpty);
    });

    test('returns low confidence when every query failed', () async {
      runQueryOutput = 'SQL error: no such table: weather';

      final result = await agent.research('What artists are in the database?');

      expect(result.toolCalls.map((c) => c.tool), contains('runQuery'));
      expect(result.confidence, 'low');
      expect(result.sources, isEmpty);
    });
  });

  group('ResearchAgent out of turns', () {
    /// Defines a model named [name] that never stops calling tools: every
    /// research turn requests [nextTool]. Synthesis requests go to
    /// [synthesisRequests] and get a structured answer.
    void defineEndlessModel(
      String name,
      ToolRequest Function(int turn) nextTool,
      List<ModelRequest> synthesisRequests,
    ) {
      ai.defineModel(
        name: name,
        fn: (request, _) async {
          if (request.output != null) {
            synthesisRequests.add(request);
            return _structuredResponse(request);
          }
          final turn = request.messages.where((m) => m.role == Role.tool);
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [ToolRequestPart(toolRequest: nextTool(turn.length))],
            ),
          );
        },
      );
    }

    test('synthesizes from the query results it already has', () async {
      final synthesisRequests = <ModelRequest>[];
      defineEndlessModel(
        'fake/endless-queries',
        (turn) => ToolRequest(
          ref: 'q$turn',
          name: 'runQuery',
          input: {'sql': 'SELECT Name FROM artists LIMIT $turn'},
        ),
        synthesisRequests,
      );

      final result = await agentFor(
        'fake/endless-queries',
      ).research('What artists are in the database?');

      expect(synthesisRequests, hasLength(1));
      final notes = synthesisRequests.single.messages
          .where((m) => m.role == Role.user)
          .map((m) => m.text)
          .join('\n');
      expect(notes, contains('[Query: SELECT Name FROM artists LIMIT 0]'));
      expect(notes, contains('Led Zeppelin'));
      expect(
        notes,
        isNot(contains('No query results were produced during research.')),
      );
      expect(result.toolCalls, hasLength(10));
      expect(result.toolCalls.map((c) => c.tool).toSet(), {'runQuery'});
      expect(result.confidence, 'high');
    });

    test('answers with low confidence and skips synthesis when no query '
        'ran', () async {
      final synthesisRequests = <ModelRequest>[];
      defineEndlessModel(
        'fake/endless-exploring',
        (turn) => ToolRequest(ref: 't$turn', name: 'listTables', input: {}),
        synthesisRequests,
      );

      final result = await agentFor(
        'fake/endless-exploring',
      ).research('What artists are in the database?');

      expect(synthesisRequests, isEmpty);
      expect(
        result.answer,
        "I couldn't finish researching this question within the allowed "
        'steps. Try asking something more specific.',
      );
      expect(result.sources, isEmpty);
      expect(result.confidence, 'low');
      expect(result.toolCalls, hasLength(10));
      expect(result.toolCalls.first.tool, 'listTables');
    });

    test('answers with low confidence and skips synthesis when every query '
        'failed', () async {
      runQueryOutput = 'SQL error: no such table: weather';
      final synthesisRequests = <ModelRequest>[];
      defineEndlessModel(
        'fake/endless-failing-queries',
        (turn) => ToolRequest(
          ref: 'q$turn',
          name: 'runQuery',
          input: {'sql': 'SELECT * FROM weather LIMIT $turn'},
        ),
        synthesisRequests,
      );

      final result = await agentFor(
        'fake/endless-failing-queries',
      ).research('What is the weather in Paris?');

      expect(synthesisRequests, isEmpty);
      expect(result.answer, startsWith("I couldn't finish researching"));
      expect(result.confidence, 'low');
      expect(result.toolCalls, hasLength(10));
    });
  });

  group('ResearchAgent failures', () {
    test('throws the model\'s GenkitException when the model fails', () async {
      ai.defineModel(
        name: 'fake/overloaded',
        fn: (_, _) async => throw GenkitException(
          'This model is currently experiencing high demand.',
          status: StatusCode.unavailable,
        ),
      );

      await expectLater(
        agentFor('fake/overloaded').research('How many artists?'),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCode.unavailable)
              .having((e) => e.message, 'message', contains('high demand')),
        ),
      );
    });

    test(
      'throws a GenkitException when the model throws anything else',
      () async {
        ai.defineModel(
          name: 'fake/broken',
          fn: (_, _) async => throw StateError('model failed on purpose'),
        );

        await expectLater(
          agentFor('fake/broken').research('How many artists?'),
          throwsA(
            isA<GenkitException>()
                .having((e) => e.status, 'status', StatusCode.internal)
                .having((e) => e.message, 'message', contains('on purpose')),
          ),
        );
      },
    );

    test('throws when only the research phase fails', () async {
      // Synthesis would succeed, so only the research-phase check can turn
      // this failure into an error instead of an answer.
      ai.defineModel(
        name: 'fake/research-quota',
        fn: (request, _) async {
          if (request.output != null) return _structuredResponse(request);
          throw GenkitException(
            'Quota exceeded for this model.',
            status: StatusCode.resourceExhausted,
          );
        },
      );

      await expectLater(
        agentFor('fake/research-quota').research('How many artists?'),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCode.resourceExhausted)
              .having((e) => e.message, 'message', contains('Quota exceeded')),
        ),
      );
    });

    test('throws when a tool fails during research', () async {
      final failingRunQuery = ai.defineTool(
        name: 'failingRunQuery',
        description: 'Run a SQL query.',
        inputSchema: SqlQueryInput.$schema,
        outputSchema: SchemanticType.string(),
        fn: (_, _) async => throw StateError('database is locked'),
      );
      ai.defineModel(
        name: 'fake/query-first',
        fn: (request, _) async {
          if (request.output != null) return _structuredResponse(request);
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(
                    name: 'failingRunQuery',
                    input: const {'sql': 'SELECT Name FROM artists'},
                  ),
                ),
              ],
            ),
          );
        },
      );
      await expectLater(
        agentFor(
          'fake/query-first',
          runQueryTool: failingRunQuery,
        ).research('How many artists?'),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCode.internal)
              .having(
                (e) => e.message,
                'message',
                contains('tool "failingRunQuery" failed'),
              )
              .having((e) => e.message, 'message', contains('database is')),
        ),
      );
    });

    test('throws when the synthesis reply is not JSON', () async {
      ai.defineModel(
        name: 'fake/prose',
        fn: (request, _) async => _textResponse(
          request.output != null ? 'Sorry, no JSON today.' : 'No data.',
        ),
      );

      await expectLater(
        agentFor('fake/prose').research('How many artists?'),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            contains('expected schema'),
          ),
        ),
      );
    });

    test('throws when the synthesis reply does not match the schema', () async {
      ai.defineModel(
        name: 'fake/wrong-shape',
        fn: (request, _) async => _textResponse(
          request.output != null ? '{"answer": 42}' : 'No data.',
        ),
      );

      // The JSON parses, so Genkit returns it as output. The agent reads
      // every field and reports the mistyped one as a schema mismatch.
      await expectLater(
        agentFor('fake/wrong-shape').research('How many artists?'),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCode.internal)
              .having((e) => e.message, 'message', contains('expected schema'))
              .having((e) => e.cause, 'cause', isA<TypeError>()),
        ),
      );
    });

    test('throws when a source in the synthesis reply is not a '
        'string', () async {
      ai.defineModel(
        name: 'fake/wrong-source',
        fn: (request, _) async => _textResponse(
          request.output != null
              ? '{"answer": "x", "sources": [1], "confidence": "low"}'
              : 'No data.',
        ),
      );

      await expectLater(
        agentFor('fake/wrong-source').research('How many artists?'),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            contains('expected schema'),
          ),
        ),
      );
    });
  });
}

ModelResponse _textResponse(String text) => ModelResponse(
  finishReason: FinishReason.stop,
  message: Message(
    role: Role.model,
    content: [TextPart(text: text)],
  ),
);

ModelResponse _toolCallingResponse(ModelRequest request) {
  final question = _userQuestion(request);
  final toolResponseCount = request.messages
      .where((m) => m.role == Role.tool)
      .length;

  if (_isUnanswerable(question)) {
    return ModelResponse(
      finishReason: FinishReason.stop,
      message: Message(
        role: Role.model,
        content: [TextPart(text: 'I could not find relevant data.')],
      ),
    );
  }

  if (toolResponseCount == 0) {
    return ModelResponse(
      finishReason: FinishReason.stop,
      message: Message(
        role: Role.model,
        content: [
          ToolRequestPart(
            toolRequest: ToolRequest(name: 'listTables', input: const {}),
          ),
        ],
      ),
    );
  }

  if (toolResponseCount == 1) {
    return ModelResponse(
      finishReason: FinishReason.stop,
      message: Message(
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
    );
  }

  if (toolResponseCount == 2) {
    return ModelResponse(
      finishReason: FinishReason.stop,
      message: Message(
        role: Role.model,
        content: [
          ToolRequestPart(
            toolRequest: ToolRequest(
              name: 'runQuery',
              input: const {'sql': 'SELECT Name FROM artists LIMIT 3'},
            ),
          ),
        ],
      ),
    );
  }

  return ModelResponse(
    finishReason: FinishReason.stop,
    message: Message(
      role: Role.model,
      content: [
        TextPart(
          text: 'The database contains artists: AC/DC, Led Zeppelin, Queen.',
        ),
      ],
    ),
  );
}

ModelResponse _structuredResponse(ModelRequest request) {
  final question = _userQuestion(request);

  final Map<String, Object?> output;
  if (_isUnanswerable(question)) {
    output = {
      'answer': 'No relevant data found in the database.',
      'sources': const <String>[],
      'confidence': 'low',
    };
  } else {
    output = {
      'answer':
          'The database contains the following artists: AC/DC, Led Zeppelin, '
          'and Queen (among others).',
      'sources': const ['SELECT Name FROM artists LIMIT 3'],
      'confidence': 'high',
    };
  }

  return ModelResponse(
    finishReason: FinishReason.stop,
    message: Message(
      role: Role.model,
      content: [TextPart(text: jsonEncode(output))],
    ),
  );
}

String _userQuestion(ModelRequest request) {
  final firstUser = request.messages.firstWhere(
    (m) => m.role == Role.user,
    orElse: () => Message(
      role: Role.user,
      content: [TextPart(text: '')],
    ),
  );
  return firstUser.text;
}

bool _isUnanswerable(String question) =>
    question.contains('gibberish') || question.contains('xyzzy');
