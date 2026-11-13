import 'package:genkit/genkit.dart';
import '../helpers/test_database.dart';
import 'package:dart_server/src/tools/list_tables.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Genkit ai;
  late Database db;
  late ListTablesTool tool;

  setUp(() {
    ai = Genkit();
    db = createSeedDatabase();
    tool = ListTablesTool(ai: ai, db: db);
  });

  tearDown(() async {
    db.close();
    await ai.shutdown();
  });

  group('ListTablesTool', () {
    test('returns all seeded table names', () async {
      final result = await tool.list();

      expect(result, contains('- albums'));
      expect(result, contains('- artists'));
      expect(result, contains('- tracks'));
      expect(result, contains('- genres'));
      expect(result, contains('- customers'));
      expect(result, contains('- invoices'));
      expect(result, contains('- invoice_lines'));
      expect(result, contains('- playlists'));
      expect(result, contains('- playlist_tracks'));
    });

    test('returns a message for an empty database', () async {
      final emptyDb = sqlite3.openInMemory();
      final emptyTool = ListTablesTool(ai: ai, db: emptyDb);

      final result = await emptyTool.list();

      expect(result, 'The database has no tables.');
      emptyDb.close();
    });

    test('starts with a descriptive header', () async {
      final result = await tool.list();

      expect(result, startsWith('Tables in the database:'));
    });
  });
}
