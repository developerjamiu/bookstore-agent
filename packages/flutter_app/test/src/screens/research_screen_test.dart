import 'dart:convert';

import 'package:flutter_app/src/app.dart';
import 'package:flutter_app/src/services/research_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late ResearchApi api;

  setUp(() {
    api = ResearchApi(
      baseUrl: Uri.parse('http://localhost:8080'),
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final question = body['question'] as String;

        if (question.contains('fail')) {
          return http.Response('{"error":"Server error"}', 500);
        }

        return http.Response(
          jsonEncode({
            'answer': 'Classics has the most books.',
            'sources': ['SELECT g.Name FROM genres g'],
            'confidence': 'high',
            'toolCalls': [
              {'tool': 'listTables', 'input': '{}'},
              {'tool': 'runQuery', 'input': '{"sql":"SELECT 1"}'},
            ],
          }),
          200,
        );
      }),
    );
  });

  group('ResearchScreen', () {
    testWidgets('shows the heading and input field', (tester) async {
      await tester.pumpWidget(ResearchApp(api: api));

      expect(find.text('Bookstore Agent'), findsOneWidget);
      expect(find.text('Which genre has the most books?'), findsOneWidget);
    });

    testWidgets('submits a question and displays the answer', (tester) async {
      await tester.pumpWidget(ResearchApp(api: api));

      await tester.enterText(find.byType(TextField), 'test question');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('Classics has the most books.'), findsOneWidget);
      expect(find.text('High confidence'), findsOneWidget);
      expect(find.text('Agent trace'), findsOneWidget);
      expect(find.text('New question'), findsOneWidget);
    });

    testWidgets('clears the input after a successful response', (tester) async {
      await tester.pumpWidget(ResearchApp(api: api));

      await tester.enterText(find.byType(TextField), 'test question');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('"New question" resets the screen', (tester) async {
      await tester.pumpWidget(ResearchApp(api: api));

      await tester.enterText(find.byType(TextField), 'test question');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('Classics has the most books.'), findsOneWidget);

      await tester.tap(find.text('New question'));
      await tester.pumpAndSettle();

      expect(find.text('Classics has the most books.'), findsNothing);
      expect(find.text('New question'), findsNothing);
    });

    testWidgets('shows error message on API failure', (tester) async {
      await tester.pumpWidget(ResearchApp(api: api));

      await tester.enterText(find.byType(TextField), 'fail');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('Server error'), findsOneWidget);
      expect(find.textContaining('ResearchApiException'), findsNothing);
    });

    testWidgets('does not submit an empty question', (tester) async {
      await tester.pumpWidget(ResearchApp(api: api));

      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('Classics has the most books.'), findsNothing);
    });
  });
}
