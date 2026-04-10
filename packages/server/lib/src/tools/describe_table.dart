import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';
import 'package:sqlite3/sqlite3.dart';

import '../schemas/table_name_input.dart';

/// Genkit tool that describes the columns and foreign keys of a table.
///
/// The agent calls this after [ListTablesTool] to understand a table's
/// schema before writing SQL queries.
///
/// The table name is validated against `sqlite_master` before being used
/// in PRAGMA statements to prevent SQL injection.
class DescribeTableTool {
  final Genkit _ai;
  final Database _db;

  DescribeTableTool({required Genkit ai, required Database db})
    : _ai = ai,
      _db = db;

  Tool<TableNameInput, String> call() {
    return _ai.defineTool(
      name: 'describeTable',
      description:
          'Show the columns, types, and constraints of a table. Call this '
          'to understand the schema before writing a query.',
      inputSchema: TableNameInput.$schema,
      outputSchema: SchemanticType.string(),
      fn: (input, _) => describe(input),
    );
  }

  /// Returns column info and foreign keys, or a not-found message.
  ///
  /// ```
  /// Columns in "tracks":
  /// - TrackId INTEGER NOT NULL PRIMARY KEY
  /// - Name TEXT NOT NULL
  /// - AlbumId INTEGER
  /// Foreign keys:
  /// - AlbumId -> albums(AlbumId)
  /// ```
  Future<String> describe(TableNameInput input) async {
    final tableName = input.table;

    final exists = _db.select(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    if (exists.isEmpty) {
      return 'Table "$tableName" does not exist.';
    }

    final columns = _db.select('PRAGMA table_info("$tableName")');

    final buffer = StringBuffer('Columns in "$tableName":')..writeln();
    for (final col in columns) {
      final name = col['name'] as String;
      final type = col['type'] as String;
      final notNull = col['notnull'] == 1 ? ' NOT NULL' : '';
      final pk = col['pk'] == 1 ? ' PRIMARY KEY' : '';
      buffer.writeln('- $name $type$notNull$pk');
    }

    final fks = _db.select('PRAGMA foreign_key_list("$tableName")');
    if (fks.isNotEmpty) {
      buffer.writeln('Foreign keys:');
      for (final fk in fks) {
        buffer.writeln('- ${fk['from']} -> ${fk['table']}(${fk['to']})');
      }
    }

    return buffer.toString().trim();
  }
}
