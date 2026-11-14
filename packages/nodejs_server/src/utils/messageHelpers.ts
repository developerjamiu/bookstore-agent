import type { MessageData, Part } from 'genkit';

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

/** Lists every tool the model asked for, in order, for the app's trace. */
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
