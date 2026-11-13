import 'package:schemantic/schemantic.dart';

part 'tool_call.g.dart';

@Schema(description: 'A tool invocation made by the research agent')
abstract class $ToolCall {
  @StringField(description: 'Name of the tool that was called')
  String get tool;

  @StringField(description: 'JSON-encoded input passed to the tool')
  String get input;
}
