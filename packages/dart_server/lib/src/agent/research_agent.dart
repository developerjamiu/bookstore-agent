import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:schemantic/schemantic.dart';

import '../schemas/research_output.dart';
import '../schemas/research_result.dart';
import '../schemas/sql_query_input.dart';
import '../schemas/table_name_input.dart';
import '../utils/message_helpers.dart';

class ResearchAgent {
  static const _prompt =
      'You are a database analyst agent. You can ONLY answer questions '
      'by querying the music store database. Never use your own knowledge. '
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
      'When you are done, reply with:\n'
      '- answer: a clear answer that interprets the query results. When '
      'listing items such as tracks, name each distinct item once and give '
      'a count when it appears more than once.\n'
      '- sources: the SELECT statements that produced the key results.\n'
      '- confidence: "high" if the query results clearly answer the '
      'question, "medium" if partially, "low" if the data was not found.\n\n'
      'NEVER answer from your own knowledge. All answers must come from query results.';

  static const _maxTurns = 10;

  static const _outOfTurnsAnswer =
      "I couldn't finish researching this question within the allowed "
      'steps. Try asking something more specific.';

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
    // One call: the model uses the tools as often as it needs, up to
    // _maxTurns times, then replies in the ResearchOutput shape.
    final response = await _ai.generate(
      model: _model,
      system: _prompt,
      prompt: question,
      tools: [_listTablesTool, _describeTableTool, _runQueryTool],
      outputSchema: ResearchOutput.$schema,
      maxTurns: _maxTurns,
    );
    _throwIfFailed(response);
    final toolCalls = extractToolCalls(response.messages);

    // The model hit the turn limit before it wrote an answer.
    if (response.finishReason == FinishReason.aborted) {
      return ResearchResult(
        answer: _outOfTurnsAnswer,
        sources: const [],
        confidence: 'low',
        toolCalls: toolCalls,
      );
    }

    // A reply that does not match the schema comes back as an error on the
    // result instead of a throw. Fail here so the route answers 500.
    final output = response.output;
    if (output == null) {
      throw GenkitException(
        response.error?.message ?? 'The model returned no structured answer.',
        cause: response.cause,
      );
    }

    // No query ran, so nothing in the answer came from the database.
    final ranQuery = toolCalls.any((call) => call.tool == 'runQuery');
    return ResearchResult(
      answer: output.answer,
      sources: ranQuery ? output.sources : const [],
      confidence: ranQuery ? output.confidence : 'low',
      toolCalls: toolCalls,
    );
  }

  /// Throws if the model call failed.
  ///
  /// Genkit 1.0 reports failures in the result instead of throwing, so this
  /// turns them back into an error the route can send as an HTTP error.
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
