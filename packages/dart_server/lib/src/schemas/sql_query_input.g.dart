// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sql_query_input.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class SqlQueryInput {
  factory SqlQueryInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  SqlQueryInput._(this._json);

  SqlQueryInput({required String sql}) {
    _json = {'sql': sql};
  }

  late final Map<String, dynamic> _json;

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
    definition: $Schema
        .object(
          properties: {
            'sql': $Schema.string(
              description:
                  'A read-only SQL SELECT statement. No INSERT, UPDATE, DELETE, or DDL statements are allowed.',
            ),
          },
          required: ['sql'],
          description: 'A SQL query to execute against the database',
        )
        .value,
    dependencies: [],
  );
}
