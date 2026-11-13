# Build Your First AI Agent with Genkit — Node.js Track

This guide documents the **complete** Node implementation (same files as on [`developerjamiu/music-store-agent`](https://github.com/developerjamiu/music-store-agent) branch **`main`**). On **this `starter` fork**, you build those files from scratch on top of the placeholder shell in `packages/nodejs_server/`, or read along with the reference repo.

**Prerequisites:** Node.js 20+, `GEMINI_API_KEY` or `GOOGLE_API_KEY` in the environment (never commit keys).

**API shape:** `POST /api/research` with JSON `{"question": "..."}` returns `answer`, `sources`, `confidence`, `toolCalls` (same as the Flutter client expects).

---

## Step 0: Install and run the reference server

```sh
cd packages/nodejs_server
npm install
export GEMINI_API_KEY=your-key-here
npm start
```

The server reads SQLite from `packages/dart_server/data/music_store.db`.

---

## Step 1–8: Implementation files (reference)

The following files form the Node agent. On **`main`** they are already present under `packages/nodejs_server/src/`.

### Schemas — `src/schemas/researchResult.ts`

```typescript
import { z } from 'genkit';

export const ToolCallSchema = z.object({
  tool: z.string().describe('Name of the tool that was called'),
  input: z.string().describe('JSON-encoded input passed to the tool'),
});

export const ResearchOutputSchema = z.object({
  answer: z.string().describe('The synthesized answer to the question'),
  sources: z.array(z.string()).describe('SQL queries used to produce the answer'),
  confidence: z
    .enum(['low', 'medium', 'high'])
    .describe('How confident the agent is in the answer'),
});

export const ResearchResultSchema = z.object({
  answer: z.string().describe('The synthesized answer to the question'),
  sources: z.array(z.string()).describe('SQL queries used to produce the answer'),
  confidence: z
    .enum(['low', 'medium', 'high'])
    .describe('How confident the agent is in the answer'),
  toolCalls: z.array(ToolCallSchema).describe('Tools the agent invoked while researching'),
});

export type ResearchResult = z.infer<typeof ResearchResultSchema>;
export type ResearchOutput = z.infer<typeof ResearchOutputSchema>;
export type ToolCall = z.infer<typeof ToolCallSchema>;

```

### Tool: listTables — `src/tools/listTables.ts`

```typescript
import type { Database } from 'better-sqlite3';
import type { Genkit } from 'genkit';
import { z } from 'genkit';

const listTablesSql =
  "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name";

export function createListTablesTool(ai: Genkit, db: Database) {
  return ai.defineTool(
    {
      name: 'listTables',
      description:
        'List all tables in the database. Call this first to discover ' +
        'what data is available before writing any queries.',
      inputSchema: z.object({}),
      outputSchema: z.string(),
    },
    async () => {
      const rows = db.prepare(listTablesSql).all() as { name: string }[];
      if (rows.length === 0) return 'The database has no tables.';
      const lines = rows.map((r) => `- ${r.name}`).join('\n');
      return `Tables in the database:\n${lines}`;
    },
  );
}

```

### Tool: describeTable — `src/tools/describeTable.ts`

```typescript
import type { Database } from 'better-sqlite3';
import type { Genkit } from 'genkit';
import { z } from 'genkit';

const tableExistsSql =
  "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?";

export function createDescribeTableTool(ai: Genkit, db: Database) {
  return ai.defineTool(
    {
      name: 'describeTable',
      description:
        'Show the columns, types, and constraints of a table. Call this ' +
        'to understand the schema before writing a query.',
      inputSchema: z.object({
        table: z
          .string()
          .describe('The name of the table, as returned by listTables.'),
      }),
      outputSchema: z.string(),
    },
    async (input) => {
      const tableName = input.table;
      const exists = db.prepare(tableExistsSql).get(tableName);
      if (!exists) {
        return `Table "${tableName}" does not exist.`;
      }

      const columns = db.prepare(`PRAGMA table_info("${tableName}")`).all() as {
        name: string;
        type: string;
        notnull: number;
        pk: number;
      }[];

      let buf = `Columns in "${tableName}":\n`;
      for (const col of columns) {
        const notNull = col.notnull === 1 ? ' NOT NULL' : '';
        const pk = col.pk === 1 ? ' PRIMARY KEY' : '';
        buf += `- ${col.name} ${col.type}${notNull}${pk}\n`;
      }

      const fks = db.prepare(`PRAGMA foreign_key_list("${tableName}")`).all() as {
        from: string;
        table: string;
        to: string;
      }[];

      if (fks.length > 0) {
        buf += 'Foreign keys:\n';
        for (const fk of fks) {
          buf += `- ${fk.from} -> ${fk.table}(${fk.to})\n`;
        }
      }

      return buf.trim();
    },
  );
}

```

### Tool: runQuery — `src/tools/runQuery.ts`

```typescript
import type { Database } from 'better-sqlite3';
import type { Genkit } from 'genkit';
import { z } from 'genkit';

const MAX_ROWS = 50;

export function createRunQueryTool(ai: Genkit, db: Database) {
  return ai.defineTool(
    {
      name: 'runQuery',
      description:
        'Execute a read-only SQL SELECT query and return the rows ' +
        'as JSON. Returns up to ' +
        MAX_ROWS +
        ' rows. Only SELECT statements are allowed.',
      inputSchema: z.object({
        sql: z
          .string()
          .describe(
            'A read-only SQL SELECT statement. No INSERT, UPDATE, DELETE, ' +
              'or DDL statements are allowed.',
          ),
      }),
      outputSchema: z.string(),
    },
    async (input) => {
      const sql = input.sql.trim();
      const firstToken = sql.split(/\s+/)[0] ?? '';
      if (!sql.toUpperCase().startsWith('SELECT')) {
        return `Only SELECT queries are allowed. Received: ${firstToken}`;
      }

      try {
        const stmt = db.prepare(sql);
        const rows = stmt.all() as Record<string, unknown>[];
        if (rows.length === 0) return 'Query returned 0 rows.';

        const limited = rows.slice(0, MAX_ROWS);
        const truncated =
          rows.length > MAX_ROWS
            ? `\n(showing ${MAX_ROWS} of ${rows.length} rows)`
            : '';

        return `${JSON.stringify(limited)}${truncated}`;
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        return `SQL error: ${msg}`;
      }
    },
  );
}

```

### Message helpers — `src/utils/messageHelpers.ts`

```typescript
import type { GenerateResponse, MessageData, Part } from 'genkit';

import type { ToolCall } from '../schemas/researchResult.js';

function isToolRequestPart(
  part: Part,
): part is Part & { toolRequest: { name: string; ref?: string; input?: unknown } } {
  return (
    typeof part === 'object' &&
    part !== null &&
    'toolRequest' in part &&
    part.toolRequest !== undefined &&
    typeof (part as { toolRequest: { name?: string } }).toolRequest.name ===
      'string'
  );
}

function isToolResponsePart(
  part: Part,
): part is Part & {
  toolResponse: { name: string; ref?: string; output?: unknown };
} {
  return (
    typeof part === 'object' &&
    part !== null &&
    'toolResponse' in part &&
    part.toolResponse !== undefined
  );
}

export function extractToolCalls(messages: MessageData[]): ToolCall[] {
  const calls: ToolCall[] = [];
  for (const message of messages) {
    for (const part of message.content) {
      if (!isToolRequestPart(part)) continue;
      const req = part.toolRequest;
      calls.push({
        tool: req.name,
        input: JSON.stringify(req.input ?? {}),
      });
    }
  }
  return calls;
}

function findQueryForResponse(
  messages: MessageData[],
  toolResponse: { name: string; ref?: string },
): string | null {
  for (const message of messages) {
    for (const part of message.content) {
      if (!isToolRequestPart(part)) continue;
      const req = part.toolRequest;
      if (req.name !== 'runQuery') continue;
      if (req.ref !== toolResponse.ref) continue;
      const input = req.input as { sql?: string } | undefined;
      return input?.sql ?? null;
    }
  }
  return null;
}

export function buildResearchNotes(response: GenerateResponse): string {
  const messages = response.messages;
  const buffer: string[] = [];

  for (const message of messages) {
    if (message.role !== 'tool') continue;
    for (const part of message.content) {
      if (!isToolResponsePart(part)) continue;
      const toolResponse = part.toolResponse;
      if (toolResponse.name !== 'runQuery') continue;
      const output = toolResponse.output;
      if (output == null) continue;

      const sql = findQueryForResponse(messages, toolResponse);
      if (sql != null) buffer.push(`[Query: ${sql}]`);
      buffer.push(typeof output === 'string' ? output : JSON.stringify(output));
      buffer.push('');
    }
  }

  const modelSummary = response.text;
  if (modelSummary) {
    buffer.push('[Agent summary]');
    buffer.push(modelSummary);
  }

  const result = buffer.join('\n').trim();
  if (!result) return 'No query results were produced during research.';
  return result;
}

```

### Research agent — `src/agent/researchAgent.ts`

```typescript
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
  'by querying the music store database. Never use your own knowledge. ' +
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

```

### Composition root (setup) — `src/agent/setup.ts`

```typescript
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

```

### HTTP route handler — `src/routes/research.ts`

```typescript
import { GenkitError } from 'genkit';
import type { IncomingMessage, ServerResponse } from 'node:http';

import type { ResearchResult } from '../schemas/researchResult.js';
import {
  errorResponse,
  handleGenkitError,
  jsonResponse,
} from '../utils/requestHelpers.js';

async function readBody(req: IncomingMessage): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of req) {
    chunks.push(chunk as Buffer);
  }
  return Buffer.concat(chunks).toString('utf8');
}

export async function handleResearchPost(
  req: IncomingMessage,
  res: ServerResponse,
  researchFlow: (question: string) => Promise<ResearchResult>,
): Promise<void> {
  let body: unknown;
  try {
    const text = await readBody(req);
    if (!text.trim()) {
      errorResponse(res, 400, 'Invalid JSON body');
      return;
    }
    body = JSON.parse(text) as unknown;
  } catch {
    errorResponse(res, 400, 'Invalid JSON body');
    return;
  }

  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    errorResponse(res, 400, 'Invalid JSON body');
    return;
  }

  const question = (body as Record<string, unknown>)['question'];
  if (typeof question !== 'string' || question.trim() === '') {
    errorResponse(res, 400, 'question is required');
    return;
  }

  try {
    const result = await researchFlow(question);
    jsonResponse(res, result);
  } catch (e) {
    if (e instanceof GenkitError) {
      handleGenkitError(res, e);
      return;
    }
    console.error('Unexpected error:', e);
    errorResponse(res, 500, 'Agent failed. Check server logs for details.');
  }
}

```

### HTTP server entry — `src/index.ts`

```typescript
import { existsSync } from 'node:fs';
import { createServer } from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import Database from 'better-sqlite3';

import { createResearchFlow } from './agent/setup.js';
import { applyCors, handleCorsPreflight } from './middleware/cors.js';
import { handleResearchPost } from './routes/research.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dbPath = path.resolve(__dirname, '..', '..', 'dart_server', 'data', 'music_store.db');

if (!existsSync(dbPath)) {
  console.error(`Database not found at ${dbPath}.`);
  process.exit(1);
}

const db = new Database(dbPath);
const researchFlow = createResearchFlow(db);

const port = Number(process.env.PORT ?? 8080);
const host = '0.0.0.0';

const server = createServer((req, res) => {
  const url = req.url?.split('?')[0] ?? '';

  if (handleCorsPreflight(req, res)) return;

  if (req.method === 'POST' && url === '/api/research') {
    applyCors(res);
    void handleResearchPost(req, res, researchFlow);
    return;
  }

  applyCors(res);
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(port, host, () => {
  console.log('');
  console.log(`Server running on http://localhost:${port}`);
  console.log('');
  console.log('Try it:');
  console.log(`  curl -s http://localhost:${port}/api/research \\`);
  console.log('    -H "Content-Type: application/json" \\');
  console.log('    -d \'{"question":"Which genre has the most tracks?"}\'');
  console.log('');
});

```

---

## Starter branch / fork

For a **from-scratch** workshop, use a repository **`starter`** branch or fork that only includes the HTTP shell (placeholder `POST /api/research`), then add these files in order and wire `index.ts` last.

---

## Related

- [README.md](./README.md) — run instructions for Dart vs Node  
- [CODELAB.md](./CODELAB.md) — Dart server track  
