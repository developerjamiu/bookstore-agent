import type { Genkit, StatusName, ToolAction } from 'genkit';
import { GenkitError, z } from 'genkit';
import { googleAI } from '@genkit-ai/google-genai';

import {
  ResearchOutputSchema,
  ResearchResultSchema,
  type ResearchResult,
} from '../schemas/researchResult.js';
import { extractToolCalls } from '../utils/messageHelpers.js';

const PROMPT =
  'You are a database analyst. Answer questions ONLY from the results of ' +
  'queries you run on the bookstore database, never from your own ' +
  'knowledge.\n\n' +
  'You do not know the database schema. To answer:\n' +
  '1. Use listTables to see what tables exist.\n' +
  '2. Use describeTable on the relevant tables to learn their columns and joins.\n' +
  '3. Write and run SQL queries with runQuery.\n' +
  '4. If a query returns unexpected results, try a different approach.\n' +
  '5. If the data cannot answer the question, say so.\n' +
  '6. As soon as your query results answer the question, stop calling ' +
  'tools and reply.\n\n' +
  'In your reply:\n' +
  '- answer: interpret the query results clearly. When listing items such ' +
  'as books, name each distinct item once and give a count when it ' +
  'appears more than once.\n' +
  '- sources: the SELECT statements that produced the key results.\n' +
  '- confidence: "low" if the database cannot answer the question, even ' +
  'if you ran queries. Otherwise "high" if the results clearly answer it, ' +
  'or "medium" if they answer it partially.';

const MAX_TURNS = 10;

const OUT_OF_TURNS_ANSWER =
  "I couldn't finish researching this question within the allowed " +
  'steps. Try asking something more specific.';

const DEFAULT_MODEL = 'gemini-3.5-flash-lite';

export class ResearchAgent {
  private readonly model;

  constructor(
    private readonly ai: Genkit,
    private readonly listTablesTool: ToolAction,
    private readonly describeTableTool: ToolAction,
    private readonly runQueryTool: ToolAction,
    modelId: string = DEFAULT_MODEL,
  ) {
    this.model = googleAI.model(modelId);
  }

  createFlow() {
    return this.ai.defineFlow(
      {
        name: 'researchFlow',
        inputSchema: z.string(),
        outputSchema: ResearchResultSchema,
      },
      async (question: string) => this.research(question),
    );
  }

  async research(question: string): Promise<ResearchResult> {
    // The model uses the tools as often as it needs, up to MAX_TURNS
    // times, then replies in the ResearchOutput shape. With throwOnError
    // off, a failure comes back on the response instead of being thrown.
    const response = await this.ai.generate({
      model: this.model,
      system: PROMPT,
      prompt: question,
      tools: [this.listTablesTool, this.describeTableTool, this.runQueryTool],
      output: { schema: ResearchOutputSchema },
      maxTurns: MAX_TURNS,
      throwOnError: false,
    });
    const toolCalls = extractToolCalls(response.messages);

    // The model hit the turn limit before it wrote an answer.
    if (response.finishReason === 'aborted') {
      return {
        answer: OUT_OF_TURNS_ANSWER,
        sources: [],
        confidence: 'low',
        toolCalls,
      };
    }

    // A failed model call, or a reply that does not match the schema. Throw
    // with Genkit's status so the route can answer 429, 503 or 500.
    const output = response.output;
    if (response.error || !output) {
      throw new GenkitError({
        status: (response.error?.status as StatusName | undefined) ?? 'INTERNAL',
        message: response.error?.message ?? 'The model returned no answer.',
      });
    }

    // No query ran, so nothing in the answer came from the database.
    const ranQuery = toolCalls.some((call) => call.tool === 'runQuery');
    return {
      answer: output.answer,
      sources: ranQuery ? output.sources : [],
      confidence: ranQuery ? output.confidence : 'low',
      toolCalls,
    };
  }
}
