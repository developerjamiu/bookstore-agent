// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'research_result.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class ResearchResult {
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
    _json['toolCalls'] = value.toList();
  }

  @override
  String toString() {
    return _json.toString();
  }

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
    definition: $Schema
        .object(
          properties: {
            'answer': $Schema.string(
              description: 'The synthesized answer to the question',
            ),
            'sources': $Schema.list(
              description: 'SQL queries used to produce the answer',
              items: $Schema.string(),
            ),
            'confidence': $Schema.string(
              description: 'How confident the agent is in the answer',
              enumValues: ['low', 'medium', 'high'],
            ),
            'toolCalls': $Schema.list(
              description: 'Tools the agent invoked while researching',
              items: $Schema.fromMap({'\$ref': r'#/$defs/ToolCall'}),
            ),
          },
          required: ['answer', 'sources', 'confidence', 'toolCalls'],
          description: 'Final result returned by the research agent flow',
        )
        .value,
    dependencies: [ToolCall.$schema],
  );
}
