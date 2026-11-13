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
       _model = model ?? googleAI.gemini('gemini-3.1-flash-lite-preview'),
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
          Message(
            role: Role.user,
            content: [TextPart(text: question)],
          ),
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
          Message(
            role: Role.user,
            content: [TextPart(text: question)],
          ),
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
