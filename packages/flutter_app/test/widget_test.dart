import 'package:flutter_app/src/app.dart';
import 'package:flutter_app/src/services/research_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  testWidgets('app renders without crashing', (tester) async {
    await tester.pumpWidget(
      ResearchApp(
        api: ResearchApi(
          baseUrl: Uri.parse('http://localhost:8080'),
          client: http.Client(),
        ),
      ),
    );

    expect(find.text('Bookstore Agent'), findsOneWidget);
  });
}
