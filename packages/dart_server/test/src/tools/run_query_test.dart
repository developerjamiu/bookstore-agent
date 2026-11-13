import 'package:genkit/genkit.dart';
import '../helpers/test_database.dart';
import 'package:dart_server/src/schemas/sql_query_input.dart';
import 'package:dart_server/src/tools/run_query.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Genkit ai;
  late Database db;
  late RunQueryTool tool;

  setUp(() {
    ai = Genkit();
    db = createSeedDatabase();
    tool = RunQueryTool(ai: ai, db: db);
  });

  tearDown(() async {
    db.close();
    await ai.shutdown();
  });

  group('RunQueryTool', () {
    test('returns JSON rows for a valid SELECT', () async {
      final result = await tool.query(
        SqlQueryInput(sql: 'SELECT Name FROM genres ORDER BY Name LIMIT 3'),
      );

      expect(result, contains('Blues'));
      expect(result, contains('Electronic'));
      expect(result, contains('Jazz'));
    });

    test('returns correct count from an aggregate query', () async {
      final result = await tool.query(
        SqlQueryInput(sql: 'SELECT COUNT(*) as total FROM artists'),
      );

      expect(result, contains('"total":15'));
    });

    test('handles JOIN queries', () async {
      final result = await tool.query(
        SqlQueryInput(
          sql:
              'SELECT a.Title, ar.Name '
              'FROM albums a '
              'JOIN artists ar ON a.ArtistId = ar.ArtistId '
              'WHERE ar.Name = \'Queen\'',
        ),
      );

      expect(result, contains('A Night at the Opera'));
      expect(result, contains('News of the World'));
    });

    test('returns a message when query has no results', () async {
      final result = await tool.query(
        SqlQueryInput(sql: "SELECT * FROM artists WHERE Name = 'Nobody'"),
      );

      expect(result, 'Query returned 0 rows.');
    });

    test('rejects DELETE statements', () async {
      final result = await tool.query(
        SqlQueryInput(sql: 'DELETE FROM artists WHERE ArtistId = 1'),
      );

      expect(result, contains('Only SELECT queries are allowed'));
      expect(result, contains('DELETE'));
    });

    test('rejects INSERT statements', () async {
      final result = await tool.query(
        SqlQueryInput(sql: "INSERT INTO artists VALUES (99, 'Hacker')"),
      );

      expect(result, contains('Only SELECT queries are allowed'));
    });

    test('rejects DROP statements', () async {
      final result = await tool.query(SqlQueryInput(sql: 'DROP TABLE artists'));

      expect(result, contains('Only SELECT queries are allowed'));
    });

    test('returns a readable error for malformed SQL', () async {
      final result = await tool.query(SqlQueryInput(sql: 'SELECT FROM WHERE'));

      expect(result, contains('SQL error'));
    });
  });

  group('RunQueryTool.isResult', () {
    test('is true for rows, truncated rows and an empty result', () async {
      final rows = await tool.query(
        SqlQueryInput(sql: 'SELECT Name FROM genres LIMIT 1'),
      );
      final truncated = await tool.query(
        SqlQueryInput(sql: 'SELECT * FROM invoice_lines'),
      );
      final empty = await tool.query(
        SqlQueryInput(sql: "SELECT * FROM artists WHERE Name = 'Nobody'"),
      );

      expect(truncated, contains('(showing 50 of'));
      expect(
        [rows, truncated, empty].map(RunQueryTool.isResult),
        everyElement(isTrue),
      );
    });

    test('is false for a SQL error, a rejected statement or no '
        'output', () async {
      final sqlError = await tool.query(
        SqlQueryInput(sql: 'SELECT * FROM weather'),
      );
      final rejected = await tool.query(
        SqlQueryInput(sql: 'DROP TABLE artists'),
      );

      expect(RunQueryTool.isResult(sqlError), isFalse);
      expect(RunQueryTool.isResult(rejected), isFalse);
      expect(RunQueryTool.isResult(null), isFalse);
    });
  });
}
