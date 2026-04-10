import 'package:client/src/services/research_api.dart';
import 'package:client/src/widgets/answer_card.dart';
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
              answer: 'Rock has the most tracks.',
              sources: const [],
              confidence: 'high',
              toolCalls: const [],
            ),
          ),
        ),
      );

      expect(find.text('Rock has the most tracks.'), findsOneWidget);
      expect(find.text('High confidence'), findsOneWidget);
      expect(find.text('Queries used'), findsNothing);
    });

    testWidgets('shows queries used when sources are present', (tester) async {
      await tester.pumpWidget(
        wrap(
          AnswerCard(
            result: ResearchResult(
              answer: 'Answer.',
              sources: const ['SELECT Name FROM artists'],
              confidence: 'medium',
              toolCalls: const [],
            ),
          ),
        ),
      );

      expect(find.text('Queries used'), findsOneWidget);
      expect(find.text('SELECT Name FROM artists'), findsOneWidget);
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
