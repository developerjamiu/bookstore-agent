import type { Database } from 'better-sqlite3';
import type { Genkit } from 'genkit';
import { z } from 'genkit';

const MAX_ROWS = 50;

export function createRunQueryTool(ai: Genkit, db: Database) {
  return ai.defineTool(
    {
      name: 'runQuery',
      description:
        'Execute a read-only SQL SELECT query and return the results ' +
        'as a formatted table. Returns up to ' +
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
