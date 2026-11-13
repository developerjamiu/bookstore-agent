import 'package:schemantic/schemantic.dart';

import 'tool_call.dart';

part 'research_result.g.dart';

@Schema(description: 'Final result returned by the research agent flow')
abstract class $ResearchResult {
  @StringField(description: 'The synthesized answer to the question')
  String get answer;

  @Field(description: 'SQL queries used to produce the answer')
  List<String> get sources;

  @StringField(
    description: 'How confident the agent is in the answer',
    enumValues: ['low', 'medium', 'high'],
  )
  String get confidence;

  @Field(description: 'Tools the agent invoked while researching')
  List<$ToolCall> get toolCalls;
}
