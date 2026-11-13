// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sql_query_input.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class SqlQueryInput {
  /// Creates a [SqlQueryInput] from a JSON map.
  factory SqlQueryInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  SqlQueryInput._(this._json);

  SqlQueryInput({required String sql}) {
    _json = {'sql': sql};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [SqlQueryInput].
  static const SchemanticType<SqlQueryInput> $schema =
      _SqlQueryInputTypeFactory();

  String get sql {
    return _json['sql'] as String;
  }

  set sql(String value) {
    _json['sql'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [SqlQueryInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _SqlQueryInputTypeFactory extends SchemanticType<SqlQueryInput> {
  const _SqlQueryInputTypeFactory();

  @override
  SqlQueryInput parse(Object? json) {
    return SqlQueryInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'SqlQueryInput',
    definition: <String, Object?>{
      'type': 'object',
      'description': 'The SQL query to run',
      'properties': <String, Object?>{
        'sql': <String, Object?>{
          'type': 'string',
          'description':
              'A read-only SQL SELECT statement. No INSERT, UPDATE, DELETE, or DDL statements are allowed.',
        },
      },
      'required': ['sql'],
    },
    dependencies: [],
  );
}
