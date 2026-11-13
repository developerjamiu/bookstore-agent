import 'package:schemantic/schemantic.dart';

part 'table_name_input.g.dart';

@Schema(description: 'Which table to look at')
abstract class $TableNameInput {
  @StringField(description: 'The name of the table, as returned by listTables.')
  String get table;
}
