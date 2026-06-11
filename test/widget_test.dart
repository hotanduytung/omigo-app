import 'package:flutter_test/flutter_test.dart';
import 'package:omigo_app/main.dart';
import 'package:provider/provider.dart';
import 'package:omigo_app/services/app_state.dart';

void main() {
  testWidgets('Omigo app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const OmigoApp(),
      ),
    );
  });
}
