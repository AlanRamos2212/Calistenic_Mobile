// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:calistenic_mobile/main.dart';

void main() {
  testWidgets('shows login and registration forms', (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    expect(find.text('Vuelve a entrenar'), findsOneWidget);
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    expect(find.text('Nombre'), findsNothing);

    await tester.tap(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Crea tu cuenta'), findsOneWidget);
    expect(find.text('CREAR CUENTA'), findsOneWidget);
    expect(find.text('Nombre'), findsOneWidget);
  });
}
