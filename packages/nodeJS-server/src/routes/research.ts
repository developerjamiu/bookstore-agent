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
