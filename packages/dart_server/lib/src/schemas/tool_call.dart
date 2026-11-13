import 'package:schemantic/schemantic.dart';

part 'tool_call.g.dart';

@Schema(description: 'A tool the agent called')
abstract class $ToolCall {
  @StringField(description: 'The name of the tool')
  String get tool;

  @StringField(description: 'What the agent sent to the tool, as JSON text')
  String get input;
}
