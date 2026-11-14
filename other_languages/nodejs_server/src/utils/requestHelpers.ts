import { GenkitError } from 'genkit';
import type { ServerResponse } from 'node:http';

export function jsonResponse(res: ServerResponse, body: unknown, statusCode = 200): void {
  res.writeHead(statusCode, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

export function errorResponse(res: ServerResponse, statusCode: number, message: string): void {
  jsonResponse(res, { error: message }, statusCode);
}

/** Used once you wire Genkit in the research route (see CODELAB-NODEJS.md). */
export function handleGenkitError(res: ServerResponse, e: GenkitError): void {
  console.error('Genkit error:', e);
  switch (e.status) {
    case 'RESOURCE_EXHAUSTED':
      errorResponse(res, 429, 'API quota exceeded. Please try again later.');
      return;
    case 'UNAVAILABLE':
      errorResponse(res, 503, 'Model is temporarily unavailable. Please retry.');
      return;
    default:
      errorResponse(res, 500, 'Agent failed. Check server logs for details.');
  }
}
