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
      '- Write a clear, natural-language answer that interprets the data.';

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
    final researchResponse = await _runResearchPhase(question);
    final toolCalls = extractToolCalls(researchResponse.messages);

    // The tool loop ran out of turns. The result still holds the history,
    // so the notes come from the queries the agent really ran. With no query
    // results at all, there is nothing true to synthesize from.
    final outOfTurns = researchResponse.finishReason == FinishReason.aborted;
    if (outOfTurns && !hasQueryResults(researchResponse.messages)) {
      return ResearchResult(
        answer: _outOfTurnsAnswer,
        sources: const [],
        confidence: 'low',
        toolCalls: toolCalls,
      );
    }

    final notes = buildResearchNotes(researchResponse);
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

    // The reply did not parse as the schema. Genkit reports that as an error
    // on the result instead of throwing, so throw it here: the route must
    // answer 500 rather than a canned 200.
    final error = response.error;
    if (response.output == null && error != null) {
      throw GenkitException(error.message, status: _statusOf(error));
    }

    return response.output ??
        ResearchOutput(
          answer: 'I was unable to produce a structured answer.',
          sources: const [],
          confidence: 'low',
        );
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

    final error = response.error;
    throw GenkitException(
      error?.message ?? 'Generation failed.',
      status: error == null ? null : _statusOf(error),
      cause: cause,
    );
  }

  static StatusCode? _statusOf(RuntimeError error) {
    final status = error.status;
    return status == null ? null : StatusCode.fromWireName(status);
  }
}
