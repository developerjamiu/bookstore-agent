import 'package:schemantic/schemantic.dart';

part 'table_name_input.g.dart';

@Schema(description: 'Input specifying a database table to inspect')
abstract class $TableNameInput {
  @StringField(description: 'The name of the table, as returned by listTables.')
  String get table;
}
