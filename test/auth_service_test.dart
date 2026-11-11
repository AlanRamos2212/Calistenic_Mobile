import 'dart:convert';

import 'package:calistenic_mobile/services/auth_service.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUpAll(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
  });

  test('login accepts a valid response and stores the session data', () async {
    final service = AuthService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/auth/login');
        return http.Response(
          jsonEncode({
            'token': 'jwt-test',
            'email': 'user@example.com',
            'name': 'Test User',
            'role': 'USER',
          }),
          200,
        );
      }),
    );

    final response = await service.login(
      email: 'user@example.com',
      password: 'safe-password',
    );

    expect(response.token, 'jwt-test');
    expect(await service.isAuthenticated(), isTrue);
  });

  test('rejects a successful HTTP response with invalid JSON', () async {
    final service = AuthService(
      client: MockClient((_) async => http.Response('{invalid', 200)),
    );

    await expectLater(
      service.login(email: 'user@example.com', password: 'safe-password'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          contains('respuesta inválida'),
        ),
      ),
    );
  });

  test('rejects a successful response without an access token', () async {
    final service = AuthService(
      client: MockClient((_) async => http.Response(
            jsonEncode({'email': 'user@example.com'}),
            200,
          )),
    );

    await expectLater(
      service.login(email: 'user@example.com', password: 'safe-password'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          contains('token de acceso'),
        ),
      ),
    );
  });

  test('shows the backend validation message when registration fails', () async {
    final service = AuthService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/auth/register');
        return http.Response(
          jsonEncode({
            'message':
                'Revisa el registro: nombre de 2 a 80 caracteres y contraseña de 8 a 72 caracteres.',
          }),
          400,
        );
      }),
    );

    await expectLater(
      service.register(name: 'A', email: 'bad-email', password: 'short'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          contains('nombre de 2 a 80 caracteres'),
        ),
      ),
    );
  });

  test(
    'shows a useful fallback when the server omits an error message',
    () async {
      final service = AuthService(
        client: MockClient((_) async => http.Response('', 503)),
      );

      await expectLater(
        service.login(email: 'user@example.com', password: 'password'),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'message',
            contains('HTTP 503'),
          ),
        ),
      );
    },
  );
}
