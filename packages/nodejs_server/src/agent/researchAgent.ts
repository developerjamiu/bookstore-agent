import type { Genkit, ToolAction } from 'genkit';
import { GenkitError, z } from 'genkit';
import { googleAI } from '@genkit-ai/google-genai';

import {
  ResearchOutputSchema,
  ResearchResultSchema,
  type ResearchResult,
} from '../schemas/researchResult.js';
import { buildResearchNotes, extractToolCalls } from '../utils/messageHelpers.js';

const RESEARCH_PROMPT =
  'You are a database analyst agent. You can ONLY answer questions ' +
  'by querying the bookstore database. Never use your own knowledge. ' +
  'You do NOT know the database schema, so you must discover it using ' +
  'the tools provided:\n' +
  '- listTables: discover what tables exist\n' +
  '- describeTable: see the columns and foreign keys of a table\n' +
  '- runQuery: execute a read-only SQL SELECT query\n\n' +
  'Strategy:\n' +
  '1. ALWAYS start by calling listTables — every question, no exceptions.\n' +
  '2. Call describeTable on relevant tables to understand columns and joins.\n' +
  '3. Write and run SQL queries to find the answer.\n' +
  '4. If a query returns unexpected results, try a different approach.\n' +
  '5. If the question cannot be answered with the available data, say so.\n\n' +
  'NEVER answer from your own knowledge. All answers must come from query results.';

const SYNTHESIS_PROMPT =
  "You are a database analyst. Using ONLY the research notes below, " +
  "produce a structured answer to the user's question.\n\n" +
  'Rules:\n' +
  '- Set confidence to "high" if the query results clearly answer the ' +
  'question, "medium" if partially, "low" if the data was not found.\n' +
  '- In the sources array, include the SQL queries from the notes ' +
  'that produced the key results (the SELECT statements).\n' +
  '- Write a clear, natural-language answer that interprets the data.';

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
    const researchResponse = await this.runResearchPhase(question);
    const toolCalls = extractToolCalls(researchResponse.messages);
    const notes = buildResearchNotes(researchResponse);
    const synthesis = await this.runSynthesisPhase(question, notes);

    return {
      answer: synthesis.answer,
      sources: synthesis.sources,
      confidence: synthesis.confidence,
      toolCalls,
    };
  }

  private async runResearchPhase(question: string) {
    try {
      return await this.ai.generate({
        model: this.model,
        system: RESEARCH_PROMPT,
        prompt: question,
        tools: [this.listTablesTool, this.describeTableTool, this.runQueryTool],
        maxTurns: 10,
      });
    } catch (e) {
      if (!(e instanceof GenkitError)) throw e;
      const msg = (e.message ?? '').toLowerCase();
      const isMaxTurns =
        msg.includes('max turns') ||
        msg.includes('maximum tool call iterations');
      if (!isMaxTurns) throw e;

      return this.ai.generate({
        model: this.model,
        system:
          'You ran out of tool-calling turns. Summarize what you ' +
          'learned from the query results below. Do not call any ' +
          'more tools.',
        prompt: question,
      });
    }
  }

  private async runSynthesisPhase(question: string, notes: string) {
    const response = await this.ai.generate({
      model: this.model,
      system: SYNTHESIS_PROMPT,
      prompt: `Question: ${question}\n\nResearch notes:\n${notes}`,
      output: { schema: ResearchOutputSchema },
    });

    return (
      response.output ?? {
        answer: 'I was unable to produce a structured answer.',
        sources: [] as string[],
        confidence: 'low' as const,
      }
    );
  }
}
