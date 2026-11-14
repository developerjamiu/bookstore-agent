import 'package:flutter_app/src/services/research_api.dart';
import 'package:flutter_app/src/widgets/answer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('AnswerCard', () {
    testWidgets('shows answer text and confidence badge', (tester) async {
      await tester.pumpWidget(
        wrap(
          AnswerCard(
            result: ResearchResult(
              answer: 'Classics has the most books.',
              sources: const [],
              confidence: 'high',
              toolCalls: const [],
            ),
          ),
        ),
      );

      expect(find.text('Classics has the most books.'), findsOneWidget);
      expect(find.text('High confidence'), findsOneWidget);
      expect(find.text('Queries used'), findsNothing);
    });

    testWidgets('shows queries used when sources are present', (tester) async {
      await tester.pumpWidget(
        wrap(
          AnswerCard(
            result: ResearchResult(
              answer: 'Answer.',
              sources: const ['SELECT Name FROM authors'],
              confidence: 'medium',
              toolCalls: const [],
            ),
          ),
        ),
      );

      expect(find.text('Queries used'), findsOneWidget);
      expect(find.text('SELECT Name FROM authors'), findsOneWidget);
      expect(find.text('Medium confidence'), findsOneWidget);
    });

    testWidgets('shows low confidence with error styling', (tester) async {
      await tester.pumpWidget(
        wrap(
          AnswerCard(
            result: ResearchResult(
              answer: 'No data found.',
              sources: const [],
              confidence: 'low',
              toolCalls: const [],
            ),
          ),
        ),
      );

      expect(find.text('Low confidence'), findsOneWidget);
    });
  });
}
