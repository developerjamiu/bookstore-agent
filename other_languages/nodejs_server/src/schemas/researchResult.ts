import { z } from 'genkit';

export const ToolCallSchema = z.object({
  tool: z.string().describe('The name of the tool'),
  input: z.string().describe('What the agent sent to the tool, as JSON text'),
});

export const ResearchOutputSchema = z.object({
  answer: z.string().describe('The answer to the question'),
  sources: z.array(z.string()).describe('SQL queries used to produce the answer'),
  confidence: z
    .enum(['low', 'medium', 'high'])
    .describe('How confident the agent is in the answer'),
});

export const ResearchResultSchema = z.object({
  answer: z.string().describe('The answer to the question'),
  sources: z.array(z.string()).describe('SQL queries used to produce the answer'),
  confidence: z
    .enum(['low', 'medium', 'high'])
    .describe('How confident the agent is in the answer'),
  toolCalls: z.array(ToolCallSchema).describe('The tools the agent called, in order'),
});

export type ResearchResult = z.infer<typeof ResearchResultSchema>;
export type ResearchOutput = z.infer<typeof ResearchOutputSchema>;
export type ToolCall = z.infer<typeof ToolCallSchema>;
