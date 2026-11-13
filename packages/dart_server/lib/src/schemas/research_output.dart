import 'package:schemantic/schemantic.dart';

part 'research_output.g.dart';

@Schema(description: 'Synthesized answer produced by the research agent')
abstract class $ResearchOutput {
  @StringField(description: 'The synthesized answer to the question')
  String get answer;

  @Field(description: 'SQL queries used to produce the answer')
  List<String> get sources;

  @StringField(
    description: 'How confident the agent is in the answer',
    enumValues: ['low', 'medium', 'high'],
  )
  String get confidence;
}
