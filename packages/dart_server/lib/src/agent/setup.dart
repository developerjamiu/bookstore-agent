import 'package:genkit/genkit.dart';
import 'package:sqlite3/sqlite3.dart';

import '../tools/describe_table.dart';
import '../tools/list_tables.dart';
import '../tools/run_query.dart';
import 'research_agent.dart';

ResearchFlow createResearchFlow({required Genkit ai, required Database db}) {
  return ResearchAgent(
    ai: ai,
    listTablesTool: ListTablesTool(ai: ai, db: db).define(),
    describeTableTool: DescribeTableTool(ai: ai, db: db).define(),
    runQueryTool: RunQueryTool(ai: ai, db: db).define(),
  ).define();
}
