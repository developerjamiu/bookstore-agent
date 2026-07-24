import type { IncomingMessage, ServerResponse } from 'node:http';

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type',
} as const;

export function applyCors(res: ServerResponse): void {
  for (const [k, v] of Object.entries(corsHeaders)) {
    res.setHeader(k, v);
  }
}

export function handleCorsPreflight(req: IncomingMessage, res: ServerResponse): boolean {
  if (req.method !== 'OPTIONS') return false;
  applyCors(res);
  res.writeHead(204);
  res.end();
  return true;
}
