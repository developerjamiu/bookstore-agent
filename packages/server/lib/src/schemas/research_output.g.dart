// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'research_output.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class ResearchOutput {
  factory ResearchOutput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ResearchOutput._(this._json);

  ResearchOutput({
    required String answer,
    required List<String> sources,
    required String confidence,
  }) {
    _json = {'answer': answer, 'sources': sources, 'confidence': confidence};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ResearchOutput> $schema =
      _ResearchOutputTypeFactory();

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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ResearchOutputTypeFactory extends SchemanticType<ResearchOutput> {
  const _ResearchOutputTypeFactory();

  @override
  ResearchOutput parse(Object? json) {
    return ResearchOutput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ResearchOutput',
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
          },
          required: ['answer', 'sources', 'confidence'],
          description: 'Synthesized answer produced by the research agent',
        )
        .value,
    dependencies: [],
  );
}
