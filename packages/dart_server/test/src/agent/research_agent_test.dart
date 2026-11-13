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
      {'Name': 'Jane Austen'},
      {'Name': 'Charles Dickens'},
      {'Name': 'Mark Twain'},
    ]);

    ai.defineModel(
      name: 'fake/model',
      fn: (request, _) async => _toolCallingResponse(request),
    );

    final listTablesTool = ai.defineTool(
      name: 'listTables',
      description: 'List tables.',
      inputSchema: SchemanticType.voidSchema(),
      outputSchema: SchemanticType.string(),
      fn: (_, _) async => .response(
        'Tables in the database:\n- authors\n- books\n- genres\n- orders',
      ),
    );

    final describeTableTool = ai.defineTool(
      name: 'describeTable',
      description: 'Describe a table.',
      inputSchema: TableNameInput.$schema,
      outputSchema: SchemanticType.string(),
      fn: (input, _) async => .response(
        'Columns in "${input.table}":\n'
        '- AuthorId INTEGER PRIMARY KEY\n'
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
      final result = await agent.research('What authors are in the database?');

      expect(result.confidence, 'high');
      expect(result.answer, contains('Jane Austen'));
    });

    test('records the exploration sequence', () async {
      final result = await agent.research('What authors are in the database?');

      final toolNames = result.toolCalls.map((c) => c.tool).toList();
      expect(toolNames, contains('listTables'));
      expect(toolNames, contains('describeTable'));
      expect(toolNames, contains('runQuery'));
    });

    test('sends the tools and the answer schema in one call', () async {
      final requests = <ModelRequest>[];
      ai.defineModel(
        name: 'fake/recording',
        fn: (request, _) async {
          requests.add(request);
          return _toolCallingResponse(request);
        },
      );

      await agentFor(
        'fake/recording',
      ).research('What authors are in the database?');

      expect(requests, hasLength(4));
      for (final request in requests) {
        expect(request.tools, isNotEmpty);
        expect(request.output, isNotNull);
      }
    });

    test('includes SQL queries in sources', () async {
      final result = await agent.research('What authors are in the database?');

      expect(result.sources, isNotEmpty);
      expect(result.sources.first, contains('SELECT'));
    });

    test('returns low confidence for unanswerable questions', () async {
      final result = await agent.research('xyzzy nonsense gibberish');

      expect(result.confidence, 'low');
    });

    test('answers with low confidence and no sources when no query '
        'ran', () async {
      ai.defineModel(
        name: 'fake/refuses',
        fn: (request, _) async => _textResponse(
          jsonEncode({
            'answer': 'I have no weather data.',
            'sources': ['SELECT 1'],
            'confidence': 'high',
          }),
        ),
      );

      final result = await agentFor(
        'fake/refuses',
      ).research('What is the weather in Paris?');

      expect(result.answer, 'I have no weather data.');
      expect(result.confidence, 'low');
      expect(result.sources, isEmpty);
    });
  });

  group('ResearchAgent out of turns', () {
    const outOfTurnsAnswer =
        "I couldn't finish researching this question within the allowed "
        'steps. Try asking something more specific.';

    /// Defines a model named [name] that never stops calling tools: every
    /// turn requests [nextTool], so it never writes an answer.
    void defineEndlessModel(
      String name,
      ToolRequest Function(int turn) nextTool,
    ) {
      ai.defineModel(
        name: name,
        fn: (request, _) async {
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

    test(
      'says it could not finish, with low confidence, after queries',
      () async {
        defineEndlessModel(
          'fake/endless-queries',
          (turn) => ToolRequest(
            ref: 'q$turn',
            name: 'runQuery',
            input: {'sql': 'SELECT Name FROM authors LIMIT $turn'},
          ),
        );

        final result = await agentFor(
          'fake/endless-queries',
        ).research('What authors are in the database?');

        expect(result.answer, outOfTurnsAnswer);
        expect(result.confidence, 'low');
        expect(result.sources, isEmpty);
        expect(result.toolCalls, hasLength(10));
        expect(result.toolCalls.map((c) => c.tool).toSet(), {'runQuery'});
      },
    );

    test('says it could not finish when no query ran', () async {
      defineEndlessModel(
        'fake/endless-exploring',
        (turn) => ToolRequest(ref: 't$turn', name: 'listTables', input: {}),
      );

      final result = await agentFor(
        'fake/endless-exploring',
      ).research('What authors are in the database?');

      expect(result.answer, outOfTurnsAnswer);
      expect(result.confidence, 'low');
      expect(result.toolCalls, hasLength(10));
      expect(result.toolCalls.first.tool, 'listTables');
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
        agentFor('fake/overloaded').research('How many authors?'),
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
          agentFor('fake/broken').research('How many authors?'),
          throwsA(
            isA<GenkitException>()
                .having((e) => e.status, 'status', StatusCode.internal)
                .having((e) => e.message, 'message', contains('on purpose')),
          ),
        );
      },
    );

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
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(
                    name: 'failingRunQuery',
                    input: const {'sql': 'SELECT Name FROM authors'},
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
        ).research('How many authors?'),
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

    test('throws when the final reply is not JSON', () async {
      ai.defineModel(
        name: 'fake/prose',
        fn: (request, _) async =>
            _researchThen(request, 'Sorry, no JSON today.'),
      );

      await expectLater(
        agentFor('fake/prose').research('How many authors?'),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            contains('expected schema'),
          ),
        ),
      );
    });

    test('throws when the final reply does not match the schema', () async {
      ai.defineModel(
        name: 'fake/wrong-shape',
        fn: (request, _) async => _researchThen(request, '{"answer": 42}'),
      );

      // The JSON parses, so Genkit returns it as output, and the mistyped
      // field throws when read. The route maps any error to 500.
      await expectLater(
        agentFor('fake/wrong-shape').research('How many authors?'),
        throwsA(isA<TypeError>()),
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

  if (_isUnanswerable(question)) return _structuredResponse(request);

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
              input: const {'table': 'authors'},
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
              input: const {'sql': 'SELECT Name FROM authors LIMIT 3'},
            ),
          ),
        ],
      ),
    );
  }

  return _structuredResponse(request);
}

/// Runs the default tool loop, then replies with [finalText] instead of
/// a valid answer.
ModelResponse _researchThen(ModelRequest request, String finalText) {
  final toolResponseCount = request.messages
      .where((m) => m.role == Role.tool)
      .length;
  if (toolResponseCount < 3) return _toolCallingResponse(request);
  return _textResponse(finalText);
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
          'The database contains the following authors: Jane Austen, '
          'Charles Dickens, and Mark Twain (among others).',
      'sources': const ['SELECT Name FROM authors LIMIT 3'],
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
