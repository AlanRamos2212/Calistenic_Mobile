import 'package:calistenic_mobile/features/auth/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<TextFormField>> mountFields(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    return tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
  }

  group('LoginScreen - validación White Box', () {
    testWidgets('en login rechaza contraseña vacía pero admite cuentas antiguas',
        (tester) async {
      final fields = await mountFields(tester);
      final passwordValidator = fields[1].validator!;

      expect(passwordValidator(''), contains('Escribe tu contraseña'));
      expect(passwordValidator('1234567'), isNull);
      expect(passwordValidator('a' * 73), isNull);
    });

    testWidgets('en login acepta contraseñas de 8 y 72 caracteres',
        (tester) async {
      final fields = await mountFields(tester);
      final passwordValidator = fields[1].validator!;

      expect(passwordValidator('12345678'), isNull);
      expect(passwordValidator('a' * 72), isNull);
    });

    testWidgets('en registro mantiene la regla de 8 a 72 caracteres',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.tap(find.text('Crear una cuenta'));
      await tester.pump();
      final fields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
      final passwordValidator = fields[2].validator!;

      expect(passwordValidator(''), contains('8 y 72'));
      expect(passwordValidator('1234567'), contains('8 y 72'));
      expect(passwordValidator('a' * 73), contains('8 y 72'));
      expect(passwordValidator('12345678'), isNull);
    });

    testWidgets('rechaza correos vacíos, sin arroba y sin dominio',
        (tester) async {
      final fields = await mountFields(tester);
      final emailValidator = fields[0].validator!;

      expect(emailValidator(''), contains('correo'));
      expect(emailValidator('usuario.ejemplo.com'), contains('correo'));
      expect(emailValidator('usuario@ejemplo'), contains('correo'));
    });

    testWidgets('acepta correo válido y rechaza uno mayor de 120 caracteres',
        (tester) async {
      final fields = await mountFields(tester);
      final emailValidator = fields[0].validator!;

      expect(emailValidator('usuario@ejemplo.com'), isNull);
      expect(emailValidator('${'a' * 112}@example.com'), contains('correo'));
    });
  });
}
