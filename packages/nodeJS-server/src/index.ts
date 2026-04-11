import { createServer } from 'node:http';

import { applyCors, handleCorsPreflight } from './middleware/cors.js';
import { handleResearchPost } from './routes/research.js';

const port = Number(process.env.PORT ?? 8080);
const host = '0.0.0.0';

const server = createServer((req, res) => {
  const url = req.url?.split('?')[0] ?? '';

  if (handleCorsPreflight(req, res)) return;

  if (req.method === 'POST' && url === '/api/research') {
    applyCors(res);
    void handleResearchPost(req, res);
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
  console.log('Placeholder only — no database or Genkit yet.');
  console.log('');
});
