// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tool_call.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class ToolCall {
  factory ToolCall.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  ToolCall._(this._json);

  ToolCall({required String tool, required String input}) {
    _json = {'tool': tool, 'input': input};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ToolCall> $schema = _ToolCallTypeFactory();

  String get tool {
    return _json['tool'] as String;
  }

  set tool(String value) {
    _json['tool'] = value;
  }

  String get input {
    return _json['input'] as String;
  }

  set input(String value) {
    _json['input'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ToolCallTypeFactory extends SchemanticType<ToolCall> {
  const _ToolCallTypeFactory();

  @override
  ToolCall parse(Object? json) {
    return ToolCall._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ToolCall',
    definition: $Schema
        .object(
          properties: {
            'tool': $Schema.string(
              description: 'Name of the tool that was called',
            ),
            'input': $Schema.string(
              description: 'JSON-encoded input passed to the tool',
            ),
          },
          required: ['tool', 'input'],
          description: 'A tool invocation made by the research agent',
        )
        .value,
    dependencies: [],
  );
}
