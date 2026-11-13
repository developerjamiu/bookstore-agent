import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:schemantic/schemantic.dart';

import '../schemas/research_output.dart';
import '../schemas/research_result.dart';
import '../schemas/sql_query_input.dart';
import '../schemas/table_name_input.dart';
import '../utils/message_helpers.dart';

/// A Genkit flow that takes a question and returns a [ResearchResult].
typedef ResearchFlow = Flow<String, ResearchResult, Never, Never>;

class ResearchAgent {
  static const _prompt =
      'You are a database analyst. Answer questions ONLY from the results of '
      'queries you run on the bookstore database, never from your own '
      'knowledge.\n\n'
      'You do not know the database schema. To answer:\n'
      '1. Use listTables to see what tables exist.\n'
      '2. Use describeTable on the relevant tables to learn their columns and joins.\n'
      '3. Write and run SQL queries with runQuery.\n'
      '4. If a query returns unexpected results, try a different approach.\n'
      '5. If the data cannot answer the question, say so.\n'
      '6. As soon as your query results answer the question, stop calling '
      'tools and reply.\n\n'
      'In your reply:\n'
      '- answer: interpret the query results clearly. When listing items such '
      'as books, name each distinct item once and give a count when it '
      'appears more than once.\n'
      '- sources: the SELECT statements that produced the key results.\n'
      '- confidence: "high" if the results clearly answer the question, '
      '"medium" if partially, "low" if the database cannot answer it.';

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

  ResearchFlow define() {
    return _ai.defineFlow(
      name: 'researchFlow',
      inputSchema: SchemanticType.string(),
      outputSchema: ResearchResult.$schema,
      fn: (input, _) => research(input),
    );
  }

  Future<ResearchResult> research(String question) async {
    // The model uses the tools as often as it needs, up to _maxTurns
    // times, then replies in the ResearchOutput shape.
    final response = await _ai.generate(
      model: _model,
      system: _prompt,
      prompt: question,
      tools: [_listTablesTool, _describeTableTool, _runQueryTool],
      outputSchema: ResearchOutput.$schema,
      maxTurns: _maxTurns,
    );
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

    // Genkit reports failures in the result instead of throwing.
    // Throw here so the route answers with an HTTP error.
    final output = response.output;
    if (output == null) {
      final cause = response.cause;
      if (cause is GenkitException) throw cause;
      throw GenkitException(
        response.error?.message ?? 'The model returned no answer.',
        cause: cause,
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
}
