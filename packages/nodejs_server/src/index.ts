import { existsSync } from 'node:fs';
import { createServer } from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import Database from 'better-sqlite3';

import { createResearchFlow } from './agent/setup.js';
import { applyCors, handleCorsPreflight } from './middleware/cors.js';
import { handleResearchPost } from './routes/research.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dbPath = path.resolve(__dirname, '..', '..', 'dart_server', 'data', 'bookstore.db');

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
  console.log('    -d \'{"question":"Which genre has the most books?"}\'');
  console.log('');
});
