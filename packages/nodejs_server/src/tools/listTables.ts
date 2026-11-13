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
