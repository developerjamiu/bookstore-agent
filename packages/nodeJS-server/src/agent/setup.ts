import type { Database } from 'better-sqlite3';
import type { Genkit } from 'genkit';
import { genkit } from 'genkit';
import { googleAI } from '@genkit-ai/google-genai';

import { ResearchAgent } from './researchAgent.js';
import { createDescribeTableTool } from '../tools/describeTable.js';
import { createListTablesTool } from '../tools/listTables.js';
import { createRunQueryTool } from '../tools/runQuery.js';

export function createResearchFlow(db: Database) {
  const ai: Genkit = genkit({ plugins: [googleAI()] });
  const listTablesTool = createListTablesTool(ai, db);
  const describeTableTool = createDescribeTableTool(ai, db);
  const runQueryTool = createRunQueryTool(ai, db);

  const agent = new ResearchAgent(
    ai,
    listTablesTool,
    describeTableTool,
    runQueryTool,
  );

  return agent.createFlow();
}
