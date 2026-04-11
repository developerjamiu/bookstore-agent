import { z } from 'genkit';

export const ToolCallSchema = z.object({
  tool: z.string().describe('Name of the tool that was called'),
  input: z.string().describe('JSON-encoded input passed to the tool'),
});

export const ResearchOutputSchema = z.object({
  answer: z.string().describe('The synthesized answer to the question'),
  sources: z.array(z.string()).describe('SQL queries used to produce the answer'),
  confidence: z
    .enum(['low', 'medium', 'high'])
    .describe('How confident the agent is in the answer'),
});

export const ResearchResultSchema = z.object({
  answer: z.string().describe('The synthesized answer to the question'),
  sources: z.array(z.string()).describe('SQL queries used to produce the answer'),
  confidence: z
    .enum(['low', 'medium', 'high'])
    .describe('How confident the agent is in the answer'),
  toolCalls: z.array(ToolCallSchema).describe('Tools the agent invoked while researching'),
});

export type ResearchResult = z.infer<typeof ResearchResultSchema>;
export type ResearchOutput = z.infer<typeof ResearchOutputSchema>;
export type ToolCall = z.infer<typeof ToolCallSchema>;
