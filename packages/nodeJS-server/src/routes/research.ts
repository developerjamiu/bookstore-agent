import type { IncomingMessage, ServerResponse } from 'node:http';

import { errorResponse, jsonResponse } from '../utils/requestHelpers.js';

async function readBody(req: IncomingMessage): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of req) {
    chunks.push(chunk as Buffer);
  }
  return Buffer.concat(chunks).toString('utf8');
}

/** Placeholder handler — two arguments only (`req`, `res`). Wire the agent later. */
export async function handleResearchPost(
  req: IncomingMessage,
  res: ServerResponse,
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

  jsonResponse(res, {
    answer:
      'This is a placeholder. Complete the codelab to power this with a real AI agent that explores the music store database!',
    sources: [],
    confidence: 'low',
    toolCalls: [],
  });
}
