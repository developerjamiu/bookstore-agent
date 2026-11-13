# Build Your First AI Agent with Genkit

Learn to build a Dart server that uses Genkit to create an autonomous AI agent. The agent explores a music store database by choosing which tools to call, writing SQL queries, and answering natural-language questions — all without being told what to do step by step.

This is not a chatbot. It's an **agent** — an LLM that sits in a loop, picks tools, observes results, and decides what to do next.

**What you'll learn:**

- Defining typed schemas with Schemantic for tool inputs and structured output
- Creating Genkit tools with `ai.defineTool()`
- Building an agentic flow with a tool-calling loop and `maxTurns`
- Working around Gemini's limitation of tools + outputSchema with two-phase generate
- Wiring everything together with constructor dependency injection

**Time:** ~30 minutes

**Prerequisites:**

- [Dart SDK](https://dart.dev/get-dart) >= 3.11
- [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.27
- A Google AI API key ([get one free](https://aistudio.google.com/apikey))

---

## Step 0: Get the Starter Project

```sh
git clone git@github.com:developerjamiu/music-store-agent.git
cd music-store-agent
git checkout starter
dart pub get
```

### Explore what you have

The starter project includes a **complete Flutter app** and a **Dart server skeleton**. The server currently returns placeholder data — your job is to build the AI agent that powers it.

**Browse the database:**

Open `packages/dart_server/data/music_store.db` in VS Code with the [SQLite Viewer](https://marketplace.visualstudio.com/items?itemName=qwtel.sqlite-viewer) extension. You'll see 9 tables: artists, albums, tracks, genres, customers, invoices, invoice_lines, playlists, and playlist_tracks. This is the data your agent will explore.

**Run the starter server:**

```sh
dart run packages/dart_server/bin/server.dart
```

**Test it with curl:**

```sh
curl -s http://localhost:8080/api/research \
  -H 'Content-Type: application/json' \
  -d '{"question":"What artists are in the database?"}' | jq
```

You'll see:

```json
{
  "answer": "This is a placeholder. Complete the codelab to power this with a real AI agent...",
  "sources": [],
  "confidence": "low",
  "toolCalls": []
}
```

**Run the Flutter app** (in a second terminal):

```sh
cd packages/client
flutter run
```

Type a question and tap **Research**. You'll see the same placeholder. By the end of this codelab, the same UI will show real AI-generated answers with SQL queries and a full tool trace.

---

## How the Agent Works

When a user asks _"Who is the top spending customer?"_, the agent doesn't know the answer - and it doesn't know the database schema either. It has to figure both out on its own.

To do this, it uses three tools that let it explore the database:

| Tool            | What it does                                          | Input      | Output              |
| --------------- | ----------------------------------------------------- | ---------- | ------------------- |
| `listTables`    | Discovers what tables exist in the database           | None       | List of table names |
| `describeTable` | Shows the columns, types, and foreign keys of a table | Table name | Column definitions  |
| `runQuery`      | Executes a read-only SQL SELECT query                 | SQL string | JSON rows           |

The agent decides which tool to call, in what order, and when to stop. A typical conversation looks like this:

1. Agent calls `listTables` - sees `customers`, `invoices`, `invoice_lines`, `tracks`, etc.
2. Agent calls `describeTable("customers")` - learns the column names and types
3. Agent calls `describeTable("invoices")` - sees `CustomerId` foreign key, understands the join
4. Agent calls `describeTable("invoice_lines")` - sees how individual purchases connect
5. Agent calls `runQuery("SELECT ... JOIN ... GROUP BY ... ORDER BY ... LIMIT 1")` - finds the top spender
6. Agent calls `runQuery("SELECT ... WHERE CustomerId = ...")` - finds what they bought
7. Agent decides it has enough and stops

This loop - think, act, observe, repeat - is what makes it an agent. The model chooses every step.

After the tool loop finishes, a second LLM call takes the query results and produces a structured JSON answer with the text, sources (the SQL queries), and a confidence level. This two-call approach is needed because Gemini doesn't support tools and structured output in the same request.

Here's what you'll build to make this work:

```
User question
    |
bin/server.dart (opens DB, creates Genkit, starts Shelf)
    |
routes/research.dart (receives POST, calls the agent flow)
    |
agent/setup.dart (wires tools + agent together)
    |
agent/research_agent.dart
    |-- Phase 1: tool-calling loop (maxTurns: 10)
    |   |-- listTables
    |   |-- describeTable
    |   |-- runQuery
    |   (model picks which tool, sees result, picks again)
    |
    |-- Phase 2: synthesis (outputSchema: ResearchOutput)
    |   (structured JSON from the research notes)
    |
    v
Flutter UI (renders answer + SQL sources + agent trace)
```

Each component has a clear role, and you'll build them bottom-up: schemas first, then tools, then the agent, then the wiring.

---

## Step 1: Define the Schemas

Schemas define the shape of data flowing in and out of your tools and agent. We use [Schemantic](https://pub.dev/packages/schemantic) — a code-generation package that produces typed Dart classes from abstract schema definitions.

### Tool input schemas

Create `packages/dart_server/lib/src/schemas/table_name_input.dart`:

```dart
import 'package:schemantic/schemantic.dart';

part 'table_name_input.g.dart';

@Schema(description: 'Input specifying a database table to inspect')
abstract class $TableNameInput {
  @StringField(description: 'The name of the table, as returned by listTables.')
  String get table;
}
```

Create `packages/dart_server/lib/src/schemas/sql_query_input.dart`:

```dart
import 'package:schemantic/schemantic.dart';

part 'sql_query_input.g.dart';

@Schema(description: 'A SQL query to execute against the database')
abstract class $SqlQueryInput {
  @StringField(
    description:
        'A read-only SQL SELECT statement. No INSERT, UPDATE, DELETE, '
        'or DDL statements are allowed.',
  )
  String get sql;
}
```

### Agent output schemas

Create `packages/dart_server/lib/src/schemas/tool_call.dart`:

```dart
import 'package:schemantic/schemantic.dart';

part 'tool_call.g.dart';

@Schema(description: 'A tool invocation made by the research agent')
abstract class $ToolCall {
  @StringField(description: 'Name of the tool that was called')
  String get tool;

  @StringField(description: 'JSON-encoded input passed to the tool')
  String get input;
}
```

Create `packages/dart_server/lib/src/schemas/research_output.dart`:

```dart
import 'package:schemantic/schemantic.dart';

part 'research_output.g.dart';

@Schema(description: 'Synthesized answer produced by the research agent')
abstract class $ResearchOutput {
  @StringField(description: 'The synthesized answer to the question')
  String get answer;

  @Field(description: 'SQL queries used to produce the answer')
  List<String> get sources;

  @StringField(
    description: 'How confident the agent is in the answer',
    enumValues: ['low', 'medium', 'high'],
  )
  String get confidence;
}
```

Create `packages/dart_server/lib/src/schemas/research_result.dart`:

```dart
import 'package:schemantic/schemantic.dart';

import 'tool_call.dart';

part 'research_result.g.dart';

@Schema(description: 'Final result returned by the research agent flow')
abstract class $ResearchResult {
  @StringField(description: 'The synthesized answer to the question')
  String get answer;

  @Field(description: 'SQL queries used to produce the answer')
  List<String> get sources;

  @StringField(
    description: 'How confident the agent is in the answer',
    enumValues: ['low', 'medium', 'high'],
  )
  String get confidence;

  @Field(description: 'Tools the agent invoked while researching')
  List<$ToolCall> get toolCalls;
}
```

> **Why two output schemas?** `ResearchOutput` is what the LLM produces (via `outputSchema`). `ResearchResult` is what the flow returns — it adds `toolCalls`, which the agent code assembles from the conversation history, not the LLM.

### Generate the code

```sh
cd packages/dart_server
dart run build_runner build --delete-conflicting-outputs
```

This generates a `.g.dart` file next to each schema with constructors, `fromJson`, `toJson`, and a `$schema` constant for use with Genkit.

**Verify:** `dart analyze` should show no errors.

---

## Step 2: Build the Database Tools

Each tool follows the same pattern: a class with constructor DI, a `call()` method that registers with Genkit, and a public logic method that's testable without Genkit.

### ListTablesTool

Create `packages/dart_server/lib/src/tools/list_tables.dart`:

````dart
import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';
import 'package:sqlite3/sqlite3.dart';

/// Genkit tool that lists all tables in the database.
///
/// Typically the first tool the agent calls to discover what data is available.
class ListTablesTool {
  final Genkit _ai;
  final Database _db;

  ListTablesTool({required Genkit ai, required Database db})
    : _ai = ai,
      _db = db;

  Tool<void, String> call() {
    return _ai.defineTool(
      name: 'listTables',
      description:
          'List all tables in the database. Call this first to discover '
          'what data is available before writing any queries.',
      inputSchema: SchemanticType.voidSchema(),
      outputSchema: SchemanticType.string(),
      fn: (_, _) => list(),
    );
  }

  /// Queries `sqlite_master` and returns a formatted list of table names.
  ///
  /// ```
  /// Tables in the database:
  /// - albums
  /// - artists
  /// - tracks
  /// ```
  Future<String> list() async {
    final result = _db.select(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
    );

    if (result.isEmpty) return 'The database has no tables.';

    final tables = result.map((row) => row['name'] as String).toList();
    return 'Tables in the database:\n${tables.map((t) => '- $t').join('\n')}';
  }
}
````

### DescribeTableTool

Create `packages/dart_server/lib/src/tools/describe_table.dart`:

````dart
import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';
import 'package:sqlite3/sqlite3.dart';

import '../schemas/table_name_input.dart';

/// Genkit tool that describes the columns and foreign keys of a table.
///
/// The agent calls this after [ListTablesTool] to understand a table's
/// schema before writing SQL queries.
///
/// The table name is validated against `sqlite_master` before being used
/// in PRAGMA statements to prevent SQL injection.
class DescribeTableTool {
  final Genkit _ai;
  final Database _db;

  DescribeTableTool({required Genkit ai, required Database db})
    : _ai = ai,
      _db = db;

  Tool<TableNameInput, String> call() {
    return _ai.defineTool(
      name: 'describeTable',
      description:
          'Show the columns, types, and constraints of a table. Call this '
          'to understand the schema before writing a query.',
      inputSchema: TableNameInput.$schema,
      outputSchema: SchemanticType.string(),
      fn: (input, _) => describe(input),
    );
  }

  /// Returns column info and foreign keys, or a not-found message.
  ///
  /// ```
  /// Columns in "tracks":
  /// - TrackId INTEGER NOT NULL PRIMARY KEY
  /// - Name TEXT NOT NULL
  /// - AlbumId INTEGER
  /// Foreign keys:
  /// - AlbumId -> albums(AlbumId)
  /// ```
  Future<String> describe(TableNameInput input) async {
    final tableName = input.table;

    final exists = _db.select(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    if (exists.isEmpty) {
      return 'Table "$tableName" does not exist.';
    }

    final columns = _db.select('PRAGMA table_info("$tableName")');

    final buffer = StringBuffer('Columns in "$tableName":')..writeln();
    for (final col in columns) {
      final name = col['name'] as String;
      final type = col['type'] as String;
      final notNull = col['notnull'] == 1 ? ' NOT NULL' : '';
      final pk = col['pk'] == 1 ? ' PRIMARY KEY' : '';
      buffer.writeln('- $name $type$notNull$pk');
    }

    final fks = _db.select('PRAGMA foreign_key_list("$tableName")');
    if (fks.isNotEmpty) {
      buffer.writeln('Foreign keys:');
      for (final fk in fks) {
        buffer.writeln('- ${fk['from']} -> ${fk['table']}(${fk['to']})');
      }
    }

    return buffer.toString().trim();
  }
}
````

### RunQueryTool

Create `packages/dart_server/lib/src/tools/run_query.dart`:

````dart
import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';
import 'package:sqlite3/sqlite3.dart';

import '../schemas/sql_query_input.dart';

/// Genkit tool that executes a read-only SQL query against the database.
///
/// Only `SELECT` statements are allowed. Results are capped at [_maxRows]
/// rows and returned as JSON. SQL errors are returned as tool output
/// (not thrown) so the agent can see the error and adjust its query.
class RunQueryTool {
  static const _maxRows = 50;

  final Genkit _ai;
  final Database _db;

  RunQueryTool({required Genkit ai, required Database db})
    : _ai = ai,
      _db = db;

  Tool<SqlQueryInput, String> call() {
    return _ai.defineTool(
      name: 'runQuery',
      description:
          'Execute a read-only SQL SELECT query and return the results '
          'as a formatted table. Returns up to $_maxRows rows. Only '
          'SELECT statements are allowed.',
      inputSchema: SqlQueryInput.$schema,
      outputSchema: SchemanticType.string(),
      fn: (input, _) => query(input),
    );
  }

  /// Executes the query and returns JSON rows, or an error message.
  ///
  /// ```
  /// [{"Name":"AC/DC"},{"Name":"Led Zeppelin"},{"Name":"Queen"}]
  /// ```
  Future<String> query(SqlQueryInput input) async {
    final sql = input.sql.trim();
    if (!sql.toUpperCase().startsWith('SELECT')) {
      return 'Only SELECT queries are allowed. '
          'Received: ${sql.split(' ').first}';
    }

    try {
      final result = _db.select(sql);

      if (result.isEmpty) return 'Query returned 0 rows.';

      final columns = result.first.keys.toList();
      final rows = result.take(_maxRows).map((row) {
        return {for (final col in columns) col: row[col]};
      }).toList();

      final truncated = result.length > _maxRows
          ? '\n(showing $_maxRows of ${result.length} rows)'
          : '';

      return '${jsonEncode(rows)}$truncated';
    } on SqliteException catch (e) {
      return 'SQL error: ${e.message}';
    }
  }
}
````

**Verify:** `dart analyze` should show no errors.

---

## Step 3: Build the Message Helpers

When the agent finishes its tool-calling loop, we need to extract two things from the conversation: what tools were called (for the UI trace), and what query results came back (for the synthesis phase).

Create `packages/dart_server/lib/src/utils/message_helpers.dart`:

````dart
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
````

> **Why filter out `listTables` and `describeTable` results?** The synthesis phase only needs query results to write its answer. Schema exploration output wastes tokens and can confuse the model.

---

## Step 4: Build the Research Agent

This is the core of the codelab — the agentic flow with two phases.

**Phase 1 - Research:** The model gets the user's question and three tools. It autonomously decides to call `listTables` first, then `describeTable` on relevant tables, then `runQuery` to fetch data. It loops up to `maxTurns: 10` and stops when it has enough information.

**Phase 2 - Synthesis:** The model gets the query results from phase 1 and produces a structured `ResearchOutput` via `outputSchema`.

> **Why two phases?** Gemini doesn't support `tools` + `outputSchema` in the same API call. This is a known limitation.

Create `packages/dart_server/lib/src/agent/research_agent.dart`:

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:schemantic/schemantic.dart';

import '../schemas/research_output.dart';
import '../schemas/research_result.dart';
import '../schemas/sql_query_input.dart';
import '../schemas/table_name_input.dart';
import '../utils/message_helpers.dart';

class ResearchAgent {
  static const _researchPrompt =
      'You are a database analyst agent. You can ONLY answer questions '
      'by querying the music store database — never use your own knowledge. '
      'You do NOT know the database schema, so you must discover it using '
      'the tools provided:\n'
      '- listTables: discover what tables exist\n'
      '- describeTable: see the columns and foreign keys of a table\n'
      '- runQuery: execute a read-only SQL SELECT query\n\n'
      'Strategy:\n'
      '1. ALWAYS start by calling listTables — every question, no exceptions.\n'
      '2. Call describeTable on relevant tables to understand columns and joins.\n'
      '3. Write and run SQL queries to find the answer.\n'
      '4. If a query returns unexpected results, try a different approach.\n'
      '5. If the question cannot be answered with the available data, say so.\n\n'
      'NEVER answer from your own knowledge. All answers must come from query results.';

  static const _synthesisPrompt =
      'You are a database analyst. Using ONLY the research notes below, '
      'produce a structured answer to the user\'s question.\n\n'
      'Rules:\n'
      '- Set confidence to "high" if the query results clearly answer the '
      'question, "medium" if partially, "low" if the data was not found.\n'
      '- In the sources array, include the SQL queries from the notes '
      'that produced the key results (the SELECT statements).\n'
      '- Write a clear, natural-language answer that interprets the data.';

  final Genkit _ai;
  final ModelRef<GeminiOptions> _model;
  final Tool<void, String> _listTablesTool;
  final Tool<TableNameInput, String> _describeTableTool;
  final Tool<SqlQueryInput, String> _runQueryTool;

  ResearchAgent({
    required Genkit ai,
    ModelRef<GeminiOptions>? model,
    required Tool<void, String> listTablesTool,
    required Tool<TableNameInput, String> describeTableTool,
    required Tool<SqlQueryInput, String> runQueryTool,
  }) : _ai = ai,
       _model = model ?? googleAI.gemini('gemini-2.5-flash'),
       _listTablesTool = listTablesTool,
       _describeTableTool = describeTableTool,
       _runQueryTool = runQueryTool;

  Flow<String, ResearchResult, Never, Never> call() {
    return _ai.defineFlow(
      name: 'researchFlow',
      inputSchema: SchemanticType.string(),
      outputSchema: ResearchResult.$schema,
      fn: (input, _) => research(input),
    );
  }

  Future<ResearchResult> research(String question) async {
    final researchResponse = await _runResearchPhase(question);
    final toolCalls = extractToolCalls(researchResponse.messages);
    final notes = buildResearchNotes(researchResponse);

    final synthesis = await _runSynthesisPhase(question, notes);

    return ResearchResult(
      answer: synthesis.answer,
      sources: synthesis.sources,
      confidence: synthesis.confidence,
      toolCalls: toolCalls,
    );
  }

  Future<GenerateResponseHelper> _runResearchPhase(String question) async {
    try {
      return await _ai.generate(
        model: _model,
        messages: [
          Message(
            role: Role.system,
            content: [TextPart(text: _researchPrompt)],
          ),
          Message(role: Role.user, content: [TextPart(text: question)]),
        ],
        tools: [_listTablesTool, _describeTableTool, _runQueryTool],
        maxTurns: 10,
      );
    } on GenkitException catch (e) {
      if (!e.message.contains('max turns')) rethrow;

      return _ai.generate(
        model: _model,
        messages: [
          Message(
            role: Role.system,
            content: [
              TextPart(
                text:
                    'You ran out of tool-calling turns. Summarize what you '
                    'learned from the query results below. Do not call any '
                    'more tools.',
              ),
            ],
          ),
          Message(role: Role.user, content: [TextPart(text: question)]),
        ],
      );
    }
  }

  Future<ResearchOutput> _runSynthesisPhase(
    String question,
    String notes,
  ) async {
    final response = await _ai.generate(
      model: _model,
      messages: [
        Message(
          role: Role.system,
          content: [TextPart(text: _synthesisPrompt)],
        ),
        Message(
          role: Role.user,
          content: [
            TextPart(text: 'Question: $question\n\nResearch notes:\n$notes'),
          ],
        ),
      ],
      outputSchema: ResearchOutput.$schema,
    );

    return response.output ??
        ResearchOutput(
          answer: 'I was unable to produce a structured answer.',
          sources: const [],
          confidence: 'low',
        );
  }
}
```

**Key things to notice:**

- `maxTurns: 10` — the model can call tools up to 10 times before Genkit stops it
- The catch block handles the "max turns" case gracefully
- `extractToolCalls` and `buildResearchNotes` come from the helpers you built in Step 4
- `model` is injectable — tests swap in a fake, production uses Gemini

---

## Step 5: Wire Everything in the Composition Root

The composition root creates all dependencies and wires them together in one place.

Create `packages/dart_server/lib/src/agent/setup.dart`:

```dart
import 'package:genkit/genkit.dart';
import 'package:sqlite3/sqlite3.dart';

import '../schemas/research_result.dart';
import '../tools/describe_table.dart';
import '../tools/list_tables.dart';
import '../tools/run_query.dart';
import 'research_agent.dart';

class AISetup {
  final Genkit _ai;
  final Database _db;

  AISetup({required Genkit ai, required Database db})
    : _ai = ai,
      _db = db;

  Flow<String, ResearchResult, Never, Never> call() {
    final listTablesTool = ListTablesTool(ai: _ai, db: _db);
    final describeTableTool = DescribeTableTool(ai: _ai, db: _db);
    final runQueryTool = RunQueryTool(ai: _ai, db: _db);

    return ResearchAgent(
      ai: _ai,
      listTablesTool: listTablesTool(),
      describeTableTool: describeTableTool(),
      runQueryTool: runQueryTool(),
    )();
  }
}
```

> Notice: each tool class is instantiated, then `()` calls its `call()` method to register it with Genkit and get back the typed `Tool` object. The same pattern applies to `ResearchAgent`.

---

## Step 6: Connect the Agent to the Route

Replace the placeholder in `packages/dart_server/lib/src/routes/research.dart`:

```dart
import 'package:genkit/genkit.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../schemas/research_result.dart';
import '../utils/request_helpers.dart';

typedef ResearchFlow = Flow<String, ResearchResult, Never, Never>;

class ResearchRoutes {
  final ResearchFlow _researchFlow;

  ResearchRoutes({required ResearchFlow researchFlow})
    : _researchFlow = researchFlow;

  Router get router {
    final router = Router();
    router.post('/api/research', _research);
    return router;
  }

  Future<Response> _research(Request request) async {
    final body = await parseJsonBody(request);
    if (body == null) return errorResponse(400, 'Invalid JSON body');

    final question = body['question'];
    if (question is! String || question.trim().isEmpty) {
      return errorResponse(400, 'question is required');
    }

    try {
      final result = await _researchFlow(question);
      return jsonResponse(result.toJson());
    } on GenkitException catch (e) {
      return handleGenkitError(e);
    } catch (e) {
      print('Unexpected error: $e');
      return errorResponse(500, 'Agent failed. Check server logs for details.');
    }
  }
}
```

---

## Step 7: Update the Server Entrypoint

Replace `packages/dart_server/bin/server.dart` to initialize Genkit and the database:

```dart
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:sqlite3/sqlite3.dart';

import 'package:dart_server/src/agent/setup.dart';
import 'package:dart_server/src/middleware/cors.dart';
import 'package:dart_server/src/routes/research.dart';

Future<void> main() async {
  final dbPath = Platform.script.resolve('../data/music_store.db').toFilePath();
  if (!File(dbPath).existsSync()) {
    stderr.writeln('Database not found at $dbPath.');
    exit(1);
  }
  final db = sqlite3.open(dbPath);

  final ai = Genkit(plugins: [googleAI()]);
  final researchFlow = AISetup(ai: ai, db: db)();

  final researchRoutes = ResearchRoutes(researchFlow: researchFlow);

  final handler = const Pipeline()
      .addMiddleware(cors())
      .addMiddleware(logRequests())
      .addHandler(researchRoutes.router.call);

  final server = await io.serve(handler, '0.0.0.0', 8080);
  print('');
  print('Server running on http://localhost:${server.port}');
  print('');
  print('Try it:');
  print('  curl -s http://localhost:${server.port}/api/research \\');
  print('    -H "Content-Type: application/json" \\');
  print('    -d \'{"question":"Which genre has the most tracks?"}\' | jq');
  print('');
}
```

**Test it live:**

```sh
export GOOGLE_API_KEY=your-key-here
dart run packages/dart_server/bin/server.dart
```

```sh
curl -s http://localhost:8080/api/research \
  -H 'Content-Type: application/json' \
  -d '{"question":"Which genre has the most tracks?"}' | jq
```

You should see a real answer with `toolCalls` showing the agent's exploration sequence. Open the Flutter app and try it there too — the placeholder is gone.

---

## You're Done

**Verify:** Run `dart analyze` — no errors. Start the server, open the Flutter app, and ask a question. You should see a real AI-generated answer with SQL sources and a full agent trace.

### What you built

| Component            | What it does                                                    |
| -------------------- | --------------------------------------------------------------- |
| **5 schemas**        | Define typed data shapes for tool inputs and agent output       |
| **3 tools**          | Explore a database: list tables, describe schema, run queries   |
| **Message helpers**  | Extract tool calls and build research notes from conversations  |
| **Research agent**   | Two-phase generate: autonomous tool loop + structured synthesis |
| **Composition root** | Wire all dependencies together                                  |
| **Route handler**    | Connect the agent flow to the HTTP endpoint                     |

### Try these questions

```sh
# Simple lookup
curl -s http://localhost:8080/api/research \
  -H 'Content-Type: application/json' \
  -d '{"question":"What artists are in the database?"}' | jq

# Multi-table JOINs
curl -s http://localhost:8080/api/research \
  -H 'Content-Type: application/json' \
  -d '{"question":"Who is the top spending customer and what did they buy?"}' | jq

# Many-to-many relationship
curl -s http://localhost:8080/api/research \
  -H 'Content-Type: application/json' \
  -d '{"question":"What songs are in the Chill Jazz playlist?"}' | jq

# Out of scope — agent should gracefully refuse
curl -s http://localhost:8080/api/research \
  -H 'Content-Type: application/json' \
  -d '{"question":"What is the weather today?"}' | jq
```

### What's Next

- **Add more tools** — a `sampleRows` tool that returns a few rows from any table
- **Add tests** — use `ai.defineModel()` to create fake models that simulate the tool-calling loop without API calls (see the `main` branch for examples)
- **Add streaming** — stream tool activity to the UI in real-time via SSE
- **Try a different database** — swap `music_store.db` for your own data
