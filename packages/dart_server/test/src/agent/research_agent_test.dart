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

  /// Builds an agent that talks to the fake model named [model].
  late ResearchAgent Function(String model) agentFor;

  setUp(() {
    ai = Genkit();

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

    final runQueryTool = ai.defineTool(
      name: 'runQuery',
      description: 'Run a SQL query.',
      inputSchema: SqlQueryInput.$schema,
      outputSchema: SchemanticType.string(),
      fn: (input, _) async => .response(
        jsonEncode([
          {'Name': 'AC/DC'},
          {'Name': 'Led Zeppelin'},
          {'Name': 'Queen'},
        ]),
      ),
    );

    agentFor = (model) => ResearchAgent(
      ai: ai,
      model: modelRef(model),
      listTablesTool: listTablesTool,
      describeTableTool: describeTableTool,
      runQueryTool: runQueryTool,
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

      // The JSON parses, so Genkit returns it as output. Reading the
      // mistyped field then throws, and the route answers 500 for that too.
      await expectLater(
        agentFor('fake/wrong-shape').research('How many artists?'),
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
