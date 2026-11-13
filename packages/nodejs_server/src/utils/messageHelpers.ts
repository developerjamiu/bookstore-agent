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
