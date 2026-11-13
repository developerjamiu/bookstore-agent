import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';
import 'package:sqlite3/sqlite3.dart';

/// Genkit tool that lists all tables in the database.
///
/// Typically the first tool the agent calls to discover what data is available.
class ListTablesTool {
  final Genkit _ai;
  final Database _db;

  ListTablesTool({required Genkit ai, required Database db})
    : _ai = ai,
      _db = db;

  Tool<void, String> call() {
    return _ai.defineTool(
      name: 'listTables',
      description:
          'List all tables in the database. Call this first to discover '
          'what data is available before writing any queries.',
      inputSchema: SchemanticType.voidSchema(),
      outputSchema: SchemanticType.string(),
      fn: (_, _) async => .response(await list()),
    );
  }

  /// Queries `sqlite_master` and returns a formatted list of table names.
  ///
  /// ```
  /// Tables in the database:
  /// - albums
  /// - artists
  /// - tracks
  /// ```
  Future<String> list() async {
    final result = _db.select(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
    );

    if (result.isEmpty) return 'The database has no tables.';

    final tables = result.map((row) => row['name'] as String).toList();
    return 'Tables in the database:\n${tables.map((t) => '- $t').join('\n')}';
  }
}
