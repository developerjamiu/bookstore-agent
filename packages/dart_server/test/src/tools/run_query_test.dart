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

      expect(result, contains('Adventure'));
      expect(result, contains('Biography'));
      expect(result, contains("Children's"));
    });

    test('returns correct count from an aggregate query', () async {
      final result = await tool.query(
        SqlQueryInput(sql: 'SELECT COUNT(*) as total FROM authors'),
      );

      expect(result, contains('"total":15'));
    });

    test('handles JOIN queries', () async {
      final result = await tool.query(
        SqlQueryInput(
          sql:
              'SELECT b.Title, a.Name '
              'FROM books b '
              'JOIN authors a ON b.AuthorId = a.AuthorId '
              'WHERE a.Name = \'Jules Verne\'',
        ),
      );

      expect(result, contains('Around the World in Eighty Days'));
      expect(result, contains('The Mysterious Island'));
    });

    test('returns a message when query has no results', () async {
      final result = await tool.query(
        SqlQueryInput(sql: "SELECT * FROM authors WHERE Name = 'Nobody'"),
      );

      expect(result, 'Query returned 0 rows.');
    });

    test('rejects DELETE statements', () async {
      final result = await tool.query(
        SqlQueryInput(sql: 'DELETE FROM authors WHERE AuthorId = 1'),
      );

      expect(result, contains('Only SELECT queries are allowed'));
      expect(result, contains('DELETE'));
    });

    test('rejects INSERT statements', () async {
      final result = await tool.query(
        SqlQueryInput(
          sql: "INSERT INTO authors VALUES (99, 'Hacker', 'Nowhere')",
        ),
      );

      expect(result, contains('Only SELECT queries are allowed'));
    });

    test('rejects DROP statements', () async {
      final result = await tool.query(SqlQueryInput(sql: 'DROP TABLE authors'));

      expect(result, contains('Only SELECT queries are allowed'));
    });

    test('returns a readable error for malformed SQL', () async {
      final result = await tool.query(SqlQueryInput(sql: 'SELECT FROM WHERE'));

      expect(result, contains('SQL error'));
    });
  });
}
