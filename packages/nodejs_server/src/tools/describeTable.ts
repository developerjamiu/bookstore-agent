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
