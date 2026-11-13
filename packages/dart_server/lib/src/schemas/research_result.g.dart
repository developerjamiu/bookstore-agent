// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'research_result.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class ResearchResult {
  /// Creates a [ResearchResult] from a JSON map.
  factory ResearchResult.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ResearchResult._(this._json);

  ResearchResult({
    required String answer,
    required List<String> sources,
    required String confidence,
    required List<ToolCall> toolCalls,
  }) {
    _json = {
      'answer': answer,
      'sources': sources,
      'confidence': confidence,
      'toolCalls': toolCalls.map((e) => e.toJson()).toList(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ResearchResult].
  static const SchemanticType<ResearchResult> $schema =
      _ResearchResultTypeFactory();

  String get answer {
    return _json['answer'] as String;
  }

  set answer(String value) {
    _json['answer'] = value;
  }

  List<String> get sources {
    return (_json['sources'] as List).cast<String>();
  }

  set sources(List<String> value) {
    _json['sources'] = value;
  }

  String get confidence {
    return _json['confidence'] as String;
  }

  set confidence(String value) {
    _json['confidence'] = value;
  }

  List<ToolCall> get toolCalls {
    return (_json['toolCalls'] as List)
        .map((e) => ToolCall.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set toolCalls(List<ToolCall> value) {
    _json['toolCalls'] = value.map((e) => e.toJson()).toList();
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ResearchResult] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ResearchResultTypeFactory extends SchemanticType<ResearchResult> {
  const _ResearchResultTypeFactory();

  @override
  ResearchResult parse(Object? json) {
    return ResearchResult._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ResearchResult',
    definition: <String, Object?>{
      'type': 'object',
      'description': 'Final result returned by the research agent flow',
      'properties': <String, Object?>{
        'answer': <String, Object?>{
          'type': 'string',
          'description': 'The synthesized answer to the question',
        },
        'sources': <String, Object?>{
          'type': 'array',
          'description': 'SQL queries used to produce the answer',
          'items': <String, Object?>{'type': 'string'},
        },
        'confidence': <String, Object?>{
          'type': 'string',
          'description': 'How confident the agent is in the answer',
          'enum': ['low', 'medium', 'high'],
        },
        'toolCalls': <String, Object?>{
          'type': 'array',
          'description': 'Tools the agent invoked while researching',
          'items': <String, Object?>{r'$ref': r'#/$defs/ToolCall'},
        },
      },
      'required': ['answer', 'sources', 'confidence', 'toolCalls'],
    },
    dependencies: [ToolCall.$schema],
  );
}
