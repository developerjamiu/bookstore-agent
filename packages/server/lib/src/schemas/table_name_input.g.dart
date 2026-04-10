// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'table_name_input.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class TableNameInput {
  factory TableNameInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  TableNameInput._(this._json);

  TableNameInput({required String table}) {
    _json = {'table': table};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<TableNameInput> $schema =
      _TableNameInputTypeFactory();

  String get table {
    return _json['table'] as String;
  }

  set table(String value) {
    _json['table'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _TableNameInputTypeFactory extends SchemanticType<TableNameInput> {
  const _TableNameInputTypeFactory();

  @override
  TableNameInput parse(Object? json) {
    return TableNameInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'TableNameInput',
    definition: $Schema
        .object(
          properties: {
            'table': $Schema.string(
              description: 'The name of the table, as returned by listTables.',
            ),
          },
          required: ['table'],
          description: 'Input specifying a database table to inspect',
        )
        .value,
    dependencies: [],
  );
}
