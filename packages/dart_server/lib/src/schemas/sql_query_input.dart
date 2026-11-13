import 'package:schemantic/schemantic.dart';

part 'sql_query_input.g.dart';

@Schema(description: 'A SQL query to execute against the database')
abstract class $SqlQueryInput {
  @StringField(
    description:
        'A read-only SQL SELECT statement. No INSERT, UPDATE, DELETE, '
        'or DDL statements are allowed.',
  )
  String get sql;
}
