// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'table_name_input.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class TableNameInput {
  /// Creates a [TableNameInput] from a JSON map.
  factory TableNameInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  TableNameInput._(this._json);

  TableNameInput({required String table}) {
    _json = {'table': table};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [TableNameInput].
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

  /// Serializes this [TableNameInput] to a JSON map.
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
    definition: <String, Object?>{
      'type': 'object',
      'description': 'Input specifying a database table to inspect',
      'properties': <String, Object?>{
        'table': <String, Object?>{
          'type': 'string',
          'description': 'The name of the table, as returned by listTables.',
        },
      },
      'required': ['table'],
    },
    dependencies: [],
  );
}
