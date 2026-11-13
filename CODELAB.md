# Build Your First AI Agent with Genkit

In this codelab, you'll build your first AI agent with Genkit and Dart. Ask it a question about a store's database, and it works out the answer itself: it decides which tables to look at, writes its own SQL, and explains what it found, with the queries to prove it.

That is what makes it an **agent** rather than a chatbot. A chatbot answers from what it already knows. An agent takes actions, here calling tools that read the database, then looks at each result and decides what to do next, until it has an answer.

**What you'll learn:**

- Defining typed schemas with Schemantic for tool inputs and structured output
- Creating Genkit tools with `ai.defineTool()`
- Building an agentic flow with a tool-calling loop and `maxTurns`
- Splitting the work into two `generate` calls: one that uses tools, one that returns structured output
- Making the agent admit when it can't answer, instead of inventing one
- Wiring everything together with constructor dependency injection

**Time:** 45 to 60 minutes

**Prerequisites:**

- [Flutter SDK](https://docs.flutter.dev/get-started/install) with Dart 3.12 or later (check with `flutter --version`)
- A Google AI API key ([get one free](https://aistudio.google.com/apikey))
- An iOS Simulator (Xcode) or Android emulator (Android Studio) to run the Flutter app
- [jq](https://jqlang.org/download/) to format JSON in the terminal

---

## Step 0: Get the Starter Project

```sh
git clone https://github.com/developerjamiu/music-store-agent.git
cd music-store-agent
git checkout starter
flutter pub get
```

### Explore what you have

The starter project includes a **complete Flutter app** and a **Dart server skeleton**. The server currently returns placeholder data. Your job is to build the AI agent that powers it.

The server uses [Relic](https://docs.dartrelic.dev/), a Dart HTTP server framework. Some of it is pre-built scaffolding you won't change: `packages/dart_server/lib/src/middleware/cors.dart` adds CORS headers so browsers can call the API, and `packages/dart_server/lib/src/utils/request_helpers.dart` parses JSON bodies and builds JSON responses.

**Browse the database:**

Open `packages/dart_server/data/music_store.db` in VS Code with the [SQLite Viewer](https://marketplace.visualstudio.com/items?itemName=qwtel.sqlite-viewer) extension. You'll see 9 tables: artists, albums, tracks, genres, customers, invoices, invoice_lines, playlists, and playlist_tracks. This is the data your agent will explore.

**Run the starter server:**

```sh
dart run packages/dart_server/bin/server.dart
```

It listens on port 8080, where the Flutter app expects it. To try curl on another port, set `PORT`, for example `PORT=8081`.

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

**Run the Flutter app.** Start an iOS Simulator or Android emulator first, then in a second terminal run:

```sh
cd packages/client
flutter run
```

Type a question and tap the send arrow. You'll see the same placeholder. By the end of this codelab, the same screen will show real answers, the SQL queries behind them, and the agent trace.

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

After the tool loop finishes, if the agent ran at least one query, a second LLM call takes the query results and produces a structured JSON answer with the text, sources (the SQL queries), and a confidence level. Keeping these as two separate calls makes each one simpler and more reliable. Step 4 explains why.

Here's what you'll build to make this work:

```
User question
    |
bin/server.dart (opens DB, creates Genkit, starts Relic)
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
    |-- Phase 2: synthesis (outputSchema: ResearchOutput), only if a query ran
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

The code generator, `schemantic_builder`, is already a dev dependency in `packages/dart_server/pubspec.yaml`. Run it from the server package:

```sh
cd packages/dart_server
dart run build_runner build
```

This generates a `.g.dart` file next to each schema with constructors, `fromJson`, `toJson`, and a `$schema` constant for use with Genkit.

**Verify:** `dart analyze` should show no errors.

---

## Step 2: Build the Database Tools

Each tool follows the same pattern: a class with constructor DI, a `call()` method that registers with Genkit, and a public logic method that's testable without Genkit.

Two things in the code are new in recent Dart and Genkit:

- `required this._ai` fills the private field `_ai` straight from a named parameter. Dart 3.12 allows this for private fields, and callers still write `ai:`.
- Genkit 1.0 expects a tool function to return a `ToolResult`. `.response(...)` is short for `ToolResult.response(...)`: Dart lets you drop the class name when it already knows the return type.

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

  ListTablesTool({required this._ai, required this._db});

  Tool<void, String> call() {
    return _ai.defineTool(
      name: 'listTables',
      description:
          'List all tables in the database. Call this first to discover '
          'what data is available before writing any queries.',
      inputSchema: SchemanticType.voidSchema(),
      outputSchema: SchemanticType.string(),
      fn: (_, _) async => .response(await list()),
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

  DescribeTableTool({required this._ai, required this._db});

  Tool<TableNameInput, String> call() {
    return _ai.defineTool(
      name: 'describeTable',
      description:
          'Show the columns, types, and constraints of a table. Call this '
          'to understand the schema before writing a query.',
      inputSchema: TableNameInput.$schema,
      outputSchema: SchemanticType.string(),
      fn: (input, _) async => .response(await describe(input)),
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

  RunQueryTool({required this._ai, required this._db});

  Tool<SqlQueryInput, String> call() {
    return _ai.defineTool(
      name: 'runQuery',
      description:
          'Execute a read-only SQL SELECT query and return the results '
          'as a formatted table. Returns up to $_maxRows rows. Only '
          'SELECT statements are allowed.',
      inputSchema: SqlQueryInput.$schema,
      outputSchema: SchemanticType.string(),
      fn: (input, _) async => .response(await query(input)),
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

Both helpers work with a `GenerateResult`, the object `ai.generate()` returns. Its `messages` hold the whole conversation, including every tool request and tool response, and its `text` holds the model's final reply. `extractToolCalls` takes the `messages`, and `buildResearchNotes` takes the whole result. A tool with no input, like `listTables`, is recorded with `{}` as its input.

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
      final input = request.input;
      calls.add(
        ToolCall(
          tool: request.name,
          // A tool with no input can arrive as null or "NULL": record "{}".
          input: jsonEncode(input is Map ? input : const <String, dynamic>{}),
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
String buildResearchNotes(GenerateResult response) {
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
        if (request.toolRequest.input case {'sql': final String sql}) {
          return sql;
        }
        return null;
      }
    }
  }
  return null;
}
````

> **Why filter out `listTables` and `describeTable` results?** The synthesis phase only needs query results to write its answer. Schema exploration output wastes tokens and can confuse the model.

---

## Step 4: Build the Research Agent

This is the core of the codelab: the agentic flow. It answers a question in two phases.

**Phase 1 - Research:** One `generate` call runs the whole tool loop. The model asks for a tool, Genkit runs it and sends back the result, and the model decides what to do next, until it has enough information. `maxTurns` caps the loop at 10 rounds of tool calls. Reaching the cap is not an error: Genkit stops and returns everything that happened so far.

**The no-query rule:** Next, the agent checks whether `runQuery` ran at least once. If it did not, there are no query results to summarize. The agent skips Phase 2 and returns the model's reply from Phase 1 with `low` confidence and no sources. That is how an out-of-scope question, like the weather, gets a polite refusal. If the model ran out of turns before writing any reply, the agent says it couldn't finish researching instead. When at least one query did run, the agent always goes on to Phase 2, so the answer comes from real query results.

**Phase 2 - Synthesis:** `buildResearchNotes` collects the query results and the model's reply from Phase 1, and a second `generate` call turns them into a `ResearchOutput`. `outputSchema: ResearchOutput.$schema` asks the model for JSON in exactly that shape, and Genkit parses it into a typed Dart object. If the reply doesn't match the schema, `response.output` is `null` and the agent throws, so the route answers with an error instead of a made-up answer.

**Checking for failures:** Genkit 1.0 reports a failed model call in the result instead of throwing. `_throwIfFailed` checks each result and throws, so the route in Step 6 can turn the failure into an HTTP error.

> **Why two phases?** Gemini can take tools and a fixed answer format (`outputSchema`) in one call, but only as a preview feature. When we tried one call with both, the model kept calling tools and never answered. Two separate calls give each step one simple job, which is more reliable.

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
      '1. Use listTables to discover what tables exist.\n'
      '2. Call describeTable on relevant tables to understand columns and joins.\n'
      '3. Write and run SQL queries to find the answer.\n'
      '4. If a query returns unexpected results, try a different approach.\n'
      '5. If the question cannot be answered with the available data, say so.\n\n'
      'NEVER answer from your own knowledge. All answers must come from query results.';

  static const _maxTurns = 10;

  static const _outOfTurnsAnswer =
      "I couldn't finish researching this question within the allowed "
      'steps. Try asking something more specific.';

  static const _synthesisPrompt =
      'You are a database analyst. Using ONLY the research notes below, '
      'produce a structured answer to the user\'s question.\n\n'
      'Rules:\n'
      '- Set confidence to "high" if the query results clearly answer the '
      'question, "medium" if partially, "low" if the data was not found.\n'
      '- In the sources array, include the SQL queries from the notes '
      'that produced the key results (the SELECT statements).\n'
      '- Write a clear, natural-language answer that interprets the data.\n'
      '- When listing items such as tracks, name each distinct item once and '
      'give a count when it appears more than once.';

  final Genkit _ai;
  final ModelRef<GeminiOptions> _model;
  final Tool<void, String> _listTablesTool;
  final Tool<TableNameInput, String> _describeTableTool;
  final Tool<SqlQueryInput, String> _runQueryTool;

  ResearchAgent({
    required this._ai,
    ModelRef<GeminiOptions>? model,
    required this._listTablesTool,
    required this._describeTableTool,
    required this._runQueryTool,
  }) : _model = model ?? googleAI.gemini('gemini-3.5-flash-lite');

  Flow<String, ResearchResult, Never, Never> call() {
    return _ai.defineFlow(
      name: 'researchFlow',
      inputSchema: SchemanticType.string(),
      outputSchema: ResearchResult.$schema,
      fn: (input, _) => research(input),
    );
  }

  Future<ResearchResult> research(String question) async {
    final research = await _runResearchPhase(question);
    final toolCalls = extractToolCalls(research.messages);

    // No query ran, so nothing came from the database: answer with low
    // confidence. That covers out-of-scope questions and an agent that ran
    // out of turns before querying.
    if (!toolCalls.any((call) => call.tool == 'runQuery')) {
      return ResearchResult(
        answer: research.text.isNotEmpty ? research.text : _outOfTurnsAnswer,
        sources: const [],
        confidence: 'low',
        toolCalls: toolCalls,
      );
    }

    final notes = buildResearchNotes(research);
    final synthesis = await _runSynthesisPhase(question, notes);
    return ResearchResult(
      answer: synthesis.answer,
      sources: synthesis.sources,
      confidence: synthesis.confidence,
      toolCalls: toolCalls,
    );
  }

  /// Runs the tool loop.
  ///
  /// When the loop reaches `maxTurns`, Genkit returns a result with
  /// `finishReason: aborted` that keeps the messages so far, instead of
  /// throwing. A cancel also ends as aborted, but this agent passes no
  /// cancellation token, so here aborted always means the turn limit.
  Future<GenerateResult> _runResearchPhase(String question) async {
    final response = await _ai.generate(
      model: _model,
      system: _researchPrompt,
      prompt: question,
      tools: [_listTablesTool, _describeTableTool, _runQueryTool],
      maxTurns: _maxTurns,
    );
    _throwIfFailed(response);
    return response;
  }

  Future<ResearchOutput> _runSynthesisPhase(
    String question,
    String notes,
  ) async {
    final response = await _ai.generate(
      model: _model,
      system: _synthesisPrompt,
      prompt: 'Question: $question\n\nResearch notes:\n$notes',
      outputSchema: ResearchOutput.$schema,
    );
    _throwIfFailed(response);

    // A reply that does not match the schema comes back as an error on the
    // result instead of a throw. Fail here so the route answers 500.
    final output = response.output;
    if (output == null) {
      throw GenkitException(
        response.error?.message ?? 'The model returned no structured answer.',
        cause: response.cause,
      );
    }
    return output;
  }

  /// Throws when [response] reports a failed generation.
  ///
  /// Genkit 1.0 no longer throws when the model or a tool fails. It returns
  /// a result with `finishReason: failed`, the thrown object as `cause` and
  /// a structured `error`. Rethrowing keeps the route's error handling, which
  /// maps a [GenkitException] status to an HTTP status.
  static void _throwIfFailed(GenerateResult response) {
    if (response.finishReason != FinishReason.failed) return;

    final cause = response.cause;
    if (cause is GenkitException) throw cause;
    throw GenkitException(
      response.error?.message ?? 'Generation failed.',
      cause: cause,
    );
  }
}
```

**Key things to notice:**

- `research()` reads top to bottom: the research phase, the no-query rule, then the synthesis phase
- In the research call, `system:` holds the instructions, `prompt:` the user's question, and `tools:` the three tools
- `_maxTurns` and `_outOfTurnsAnswer` are named constants next to the prompts, so the turn limit and the fallback answer are easy to find and change
- `extractToolCalls` and `buildResearchNotes` come from the helpers you built in Step 3
- `model` is injectable: tests swap in a fake, production uses `gemini-3.5-flash-lite`

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

  AISetup({required this._ai, required this._db});

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
import 'package:relic/relic.dart';

import '../schemas/research_result.dart';
import '../utils/request_helpers.dart';

typedef ResearchFlow = Flow<String, ResearchResult, Never, Never>;

class ResearchRoutes {
  final ResearchFlow _researchFlow;

  ResearchRoutes({required this._researchFlow});

  RelicRouter get router {
    final router = RelicRouter();
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

The `RelicRouter` and the request validation stay as they were in the placeholder. A `RelicRouter` maps a method and a path to a handler: `router.post('/api/research', _research)` sends every POST request for `/api/research` to `_research`. What's new is the injected `ResearchFlow`: the route calls it with the question and returns its result as JSON. Genkit errors become clear HTTP errors through `handleGenkitError`, which is pre-built in `request_helpers.dart`. Every `GenkitException` has a `status` of type `StatusCode`, and the helper maps it to an HTTP status: `resourceExhausted` (your API quota ran out) becomes 429, `unavailable` (the model is overloaded) becomes 503, and anything else becomes 500.

Until you update the entrypoint in Step 7, `dart analyze` reports a missing `researchFlow` argument in `bin/server.dart`. That is expected.

---

## Step 7: Update the Server Entrypoint

Replace `packages/dart_server/bin/server.dart` to initialize Genkit and the database:

```dart
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:relic/relic.dart';
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

  final ai = Genkit(plugins: [googleAI()]);
  final researchFlow = AISetup(ai: ai, db: sqlite3.open(dbPath))();
  final routes = ResearchRoutes(researchFlow: researchFlow);

  // Mounted for every path so cors() also reaches preflights and 404/405s.
  final app = RelicApp()
    ..use('/', cors())
    ..use('/', logRequests())
    ..any('/**', routes.router.asHandler);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await app.serve(address: InternetAddress.anyIPv4, port: port);

  print('Server running on http://localhost:${server.port}');
}
```

The `RelicApp` setup, reading `PORT` and `app.serve` are the same as in the starter entrypoint. The new parts open the database, create Genkit with the Google AI plugin, and build the research flow you wired in Step 5. `RelicApp` is the server's router: `use` adds middleware, here the pre-built `cors()` and Relic's `logRequests()`. Relic only runs middleware for requests that match a route, so `any('/**', ...)` mounts your router for every method and path; that way CORS headers also reach browser preflights and 404 and 405 answers. `app.serve` starts the HTTP server on `port`. Relic listens only on localhost unless you pass an address, so `address: InternetAddress.anyIPv4` makes the server reachable from other machines on your network as well.

**Test it live** from the repository root. If your shell is still in `packages/dart_server` from Step 1, run `cd ../..` first.

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
