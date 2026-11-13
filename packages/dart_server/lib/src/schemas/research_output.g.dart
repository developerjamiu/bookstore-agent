// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'research_output.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class ResearchOutput {
  /// Creates a [ResearchOutput] from a JSON map.
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

  /// The JSON schema and type descriptor for [ResearchOutput].
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

  /// Serializes this [ResearchOutput] to a JSON map.
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
    definition: <String, Object?>{
      'type': 'object',
      'description': 'The answer Gemini writes from the query results',
      'properties': <String, Object?>{
        'answer': <String, Object?>{
          'type': 'string',
          'description': 'The answer to the question',
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
      },
      'required': ['answer', 'sources', 'confidence'],
    },
    dependencies: [],
  );
}
