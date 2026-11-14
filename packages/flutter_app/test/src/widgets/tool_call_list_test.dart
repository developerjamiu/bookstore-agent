import 'package:flutter_app/src/services/research_api.dart';
import 'package:flutter_app/src/widgets/tool_call_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('ToolCallList', () {
    testWidgets('renders nothing when tool calls are empty', (tester) async {
      await tester.pumpWidget(wrap(const ToolCallList(toolCalls: [])));

      expect(find.text('Agent trace'), findsNothing);
    });

    testWidgets('shows call count and tool names when expanded', (
      tester,
    ) async {
      final calls = [
        ToolCall(tool: 'listTables', input: '{}'),
        ToolCall(tool: 'runQuery', input: '{"sql":"SELECT 1"}'),
      ];

      await tester.pumpWidget(wrap(ToolCallList(toolCalls: calls)));

      expect(find.text('Agent trace'), findsOneWidget);
      expect(find.text('2 calls'), findsOneWidget);

      await tester.tap(find.text('Agent trace'));
      await tester.pumpAndSettle();

      expect(find.text('listTables'), findsOneWidget);
      expect(find.text('runQuery'), findsOneWidget);
    });
  });
}
