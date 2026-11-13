import 'package:genkit/genkit.dart';
import '../helpers/test_database.dart';
import 'package:dart_server/src/schemas/table_name_input.dart';
import 'package:dart_server/src/tools/describe_table.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Genkit ai;
  late Database db;
  late DescribeTableTool tool;

  setUp(() {
    ai = Genkit();
    db = createSeedDatabase();
    tool = DescribeTableTool(ai: ai, db: db);
  });

  tearDown(() async {
    db.close();
    await ai.shutdown();
  });

  group('DescribeTableTool', () {
    test('returns columns with types and constraints', () async {
      final result = await tool.describe(TableNameInput(table: 'tracks'));

      expect(result, contains('TrackId INTEGER'));
      expect(result, contains('PRIMARY KEY'));
      expect(result, contains('Name TEXT NOT NULL'));
      expect(result, contains('AlbumId INTEGER'));
      expect(result, contains('Milliseconds INTEGER NOT NULL'));
      expect(result, contains('UnitPrice REAL NOT NULL'));
    });

    test('includes foreign key relationships', () async {
      final result = await tool.describe(TableNameInput(table: 'tracks'));

      expect(result, contains('Foreign keys:'));
      expect(result, contains('AlbumId -> albums(AlbumId)'));
      expect(result, contains('GenreId -> genres(GenreId)'));
    });

    test('omits foreign keys section when table has none', () async {
      final result = await tool.describe(TableNameInput(table: 'artists'));

      expect(result, contains('ArtistId'));
      expect(result, contains('Name'));
      expect(result, isNot(contains('Foreign keys:')));
    });

    test('returns a not-found message for a missing table', () async {
      final result = await tool.describe(TableNameInput(table: 'nonexistent'));

      expect(result, contains('does not exist'));
    });

    test('rejects SQL injection attempts', () async {
      final result = await tool.describe(
        TableNameInput(table: '"; DROP TABLE artists; --'),
      );

      expect(result, contains('does not exist'));

      final artists = db.select('SELECT COUNT(*) as n FROM artists');
      expect(artists.first['n'] as int, greaterThan(0));
    });
  });
}
