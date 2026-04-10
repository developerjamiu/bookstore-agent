import 'package:genkit/genkit.dart';
import 'package:sqlite3/sqlite3.dart';

import '../schemas/research_result.dart';
import '../tools/describe_table.dart';
import '../tools/list_tables.dart';
import '../tools/run_query.dart';
import 'research_agent.dart';

class AISetup {
  final Genkit _ai;
  final Database _db;

  AISetup({required Genkit ai, required Database db}) : _ai = ai, _db = db;

  Flow<String, ResearchResult, Never, Never> call() {
    final listTablesTool = ListTablesTool(ai: _ai, db: _db);
    final describeTableTool = DescribeTableTool(ai: _ai, db: _db);
    final runQueryTool = RunQueryTool(ai: _ai, db: _db);

    return ResearchAgent(
      ai: _ai,
      listTablesTool: listTablesTool(),
      describeTableTool: describeTableTool(),
      runQueryTool: runQueryTool(),
    )();
  }
}
