// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tool_call.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class ToolCall {
  /// Creates a [ToolCall] from a JSON map.
  factory ToolCall.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  ToolCall._(this._json);

  ToolCall({required String tool, required String input}) {
    _json = {'tool': tool, 'input': input};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ToolCall].
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

  /// Serializes this [ToolCall] to a JSON map.
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
    definition: <String, Object?>{
      'type': 'object',
      'description': 'A tool invocation made by the research agent',
      'properties': <String, Object?>{
        'tool': <String, Object?>{
          'type': 'string',
          'description': 'Name of the tool that was called',
        },
        'input': <String, Object?>{
          'type': 'string',
          'description': 'JSON-encoded input passed to the tool',
        },
      },
      'required': ['tool', 'input'],
    },
    dependencies: [],
  );
}
