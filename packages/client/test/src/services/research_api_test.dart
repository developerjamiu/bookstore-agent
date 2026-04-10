import 'dart:convert';

import 'package:client/src/services/research_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _baseUrl = Uri.parse('http://localhost:8080');

void main() {
  group('ResearchApi', () {
    test('parses a successful response', () async {
      final api = ResearchApi(
        baseUrl: _baseUrl,
        client: MockClient((request) async {
          expect(request.url.path, '/api/research');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['question'], 'test question');

          return http.Response(
            jsonEncode({
              'answer': 'The answer.',
              'sources': ['SELECT 1'],
              'confidence': 'high',
              'toolCalls': [
                {'tool': 'listTables', 'input': '{}'},
              ],
            }),
            200,
          );
        }),
      );

      final result = await api.ask('test question');

      expect(result.answer, 'The answer.');
      expect(result.sources, ['SELECT 1']);
      expect(result.confidence, 'high');
      expect(result.toolCalls, hasLength(1));
      expect(result.toolCalls.first.tool, 'listTables');
    });

    test('throws ResearchApiException on non-200 response', () async {
      final api = ResearchApi(
        baseUrl: _baseUrl,
        client: MockClient(
          (request) async => http.Response('{"error":"bad"}', 500),
        ),
      );

      expect(() => api.ask('fail'), throwsA(isA<ResearchApiException>()));
    });
  });
}
