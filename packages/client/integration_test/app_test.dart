import 'dart:convert';

import 'package:client/src/app.dart';
import 'package:client/src/services/research_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ResearchApi api;

  setUp(() {
    api = ResearchApi(
      baseUrl: Uri.parse('http://localhost:8080'),
      client: MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));

        return http.Response(
          jsonEncode({
            'answer': 'Classics has 12 books, the most of any genre.',
            'sources': [
              'SELECT g.Name, COUNT(*) as cnt FROM genres g '
                  'JOIN books b ON g.GenreId = b.GenreId '
                  'GROUP BY g.Name ORDER BY cnt DESC LIMIT 1',
            ],
            'confidence': 'high',
            'toolCalls': [
              {'tool': 'listTables', 'input': '{}'},
              {
                'tool': 'describeTable',
                'input': jsonEncode({'table': 'genres'}),
              },
              {
                'tool': 'describeTable',
                'input': jsonEncode({'table': 'books'}),
              },
              {
                'tool': 'runQuery',
                'input': jsonEncode({'sql': 'SELECT g.Name, COUNT(*) ...'}),
              },
            ],
          }),
          200,
        );
      }),
    );
  });

  group('end-to-end', () {
    testWidgets('ask a question, see answer, expand trace, reset', (
      tester,
    ) async {
      await tester.pumpWidget(ResearchApp(api: api));
      await tester.pumpAndSettle();

      // -- Initial state --
      expect(find.text('Bookstore Agent'), findsOneWidget);
      expect(find.text('New question'), findsNothing);

      // -- Type and submit --
      await tester.enterText(
        find.byType(TextField),
        'Which genre has the most books?',
      );
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // -- Loading state --
      expect(
        find.text('Researching "Which genre has the most books?"…'),
        findsOneWidget,
      );

      await tester.pumpAndSettle();

      // -- Result state --
      expect(
        find.text('Classics has 12 books, the most of any genre.'),
        findsOneWidget,
      );
      expect(find.text('High confidence'), findsOneWidget);
      expect(find.text('Queries used'), findsOneWidget);
      expect(find.text('Agent trace'), findsOneWidget);
      expect(find.text('4 calls'), findsOneWidget);

      // Input was cleared
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);

      // -- Expand agent trace --
      await tester.tap(find.text('Agent trace'));
      await tester.pumpAndSettle();

      expect(find.text('listTables'), findsOneWidget);
      expect(find.text('runQuery'), findsOneWidget);

      // -- Reset --
      await tester.tap(find.text('New question'));
      await tester.pumpAndSettle();

      expect(
        find.text('Classics has 12 books, the most of any genre.'),
        findsNothing,
      );
      expect(find.text('New question'), findsNothing);
      expect(find.text('Bookstore Agent'), findsOneWidget);
    });
  });
}
