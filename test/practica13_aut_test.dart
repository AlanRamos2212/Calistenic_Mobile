// ===========================================================================
// PRACTICAS 13-14: Automatizacion de pruebas y validacion continua
// Fase 1 - Componentes criticos seleccionados:
//
//   1. FUNCION CRITICA DEL MOVIL: calculo de la racha de entrenamiento
//      (StreakService.computeStreak / parseSessionDates).
//      Defecto a prevenir: rachas incorrectas cuando el backend devuelve
//      datos corruptos, fechas futuras o tipos inesperados. En el release
//      v1.1.0 un valor de tipo equivocado hizo crash al proceso completo
//      (ClassCastException Integer vs String en el provider nativo).
//
//   2. SERVICIO/ENDPOINT: GET /api/wearable-sessions via ApiClient
//      (Bearer JWT). Defecto a prevenir: una caida o 401 del backend
//      borraba la racha del widget en lugar de conservar el ultimo valor.
//
//   3. PERSISTENCIA: HomeWidget.saveWidgetData/getWidgetData (SharedPreferences
//      que consume StreakWidgetProvider nativo en Kotlin). Defecto a
//      prevenir: persistir el valor con un tipo distinto al acordado con el
//      provider (defecto real corregido en v1.1.2).
//
// Cada prueba esta etiquetada con su fila de la matriz (AUT-01..AUT-06).
// ===========================================================================
import 'dart:convert';

import 'package:calistenic_mobile/core/constants/api_constants.dart';
import 'package:calistenic_mobile/core/network/api_client.dart';
import 'package:calistenic_mobile/core/network/api_exception.dart';
import 'package:calistenic_mobile/features/auth/services/auth_service.dart';
import 'package:calistenic_mobile/features/home/services/streak_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const String _validToken = 'p13-jwt-token';

/// Duplica el contrato del SharedPreferences que recibe StreakWidgetProvider:
/// guarda lo que HomeWidget.saveWidgetData persiste, tal cual (sin cambios
/// de tipo), para poder detectar el defecto ClassCastException de v1.1.0.
final Map<String, Object?> widgetStore = <String, Object?>{};
int widgetUpdateCalls = 0;

Future<Object?>? _homeWidgetMock(MethodCall call) async {
  switch (call.method) {
    case 'saveWidgetData':
      final args = call.arguments as Map<Object?, Object?>;
      widgetStore[args['id'] as String] = args['data'];
      return true;
    case 'getWidgetData':
      final args = call.arguments as Map<Object?, Object?>;
      final id = args['id'] as String;
      if (widgetStore.containsKey(id)) return widgetStore[id];
      return args['defaultValue'];
    case 'updateWidget':
      widgetUpdateCalls++;
      return true;
  }
  return null;
}

http.Response _json(Object body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {ApiConstants.tokenKey: _validToken},
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      _homeWidgetMock,
    );
  });

  setUp(() {
    widgetStore.clear();
    widgetUpdateCalls = 0;
    // Storage aislado por prueba: evita que el token guardado en una prueba
    // contamine la siguiente (isAuthenticated debe partir limpio).
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {ApiConstants.tokenKey: _validToken},
    );
  });

  // -------------------------------------------------------------------
  // FASE 2 - PRUEBAS UNITARIAS (AUT-01, AUT-02, AUT-03)
  // -------------------------------------------------------------------
  group('P13 Fase 2 | Unitarias | Racha (logica de negocio)', () {
    test('AUT-01 Entrada valida: semana completa de sesiones consecutivas',
        () {
      final now = DateTime(2026, 11, 16);
      final sessions = List.generate(
        7,
        (i) => DateTime(2026, 11, 16 - i, 8, 0),
      );

      expect(StreakService.computeStreak(sessions, now: now), 7);
    });

    test('AUT-01 Resultado esperado: sesiones del mismo dia cuentan una vez',
        () {
      final now = DateTime(2026, 11, 16);
      final sessions = [
        DateTime(2026, 11, 16, 7, 30),
        DateTime(2026, 11, 16, 12, 0),
        DateTime(2026, 11, 16, 19, 45),
        DateTime(2026, 11, 15, 8, 0),
      ];

      expect(StreakService.computeStreak(sessions, now: now), 2);
    });

    test('AUT-02 Entrada vacia: sin sesiones y sin fechas', () {
      expect(StreakService.computeStreak(const [], now: DateTime(2026, 11, 16)),
          0);
      expect(StreakService.parseSessionDates(const <dynamic>[]), isEmpty);
      expect(
        StreakService.parseSessionDates(<dynamic>[
          <String, dynamic>{'id': 1, 'startedAt': null},
        ]),
        isEmpty,
      );
    });

    test('AUT-02 Entrada nula/descartable: elementos que no son objetos', () {
      final dates = StreakService.parseSessionDates(<dynamic>[
        'no-es-objeto',
        42,
        null,
        <String, dynamic>{'startedAt': '2026-11-15T10:00:00Z'},
      ]);

      expect(dates, hasLength(1));
    });

    test('AUT-03 Fuera de rango: fechas futuras no inflan la racha', () {
      final now = DateTime(2026, 11, 16);
      final sessions = [
        DateTime(2026, 12, 20),
        DateTime(2026, 12, 21),
      ];

      expect(StreakService.computeStreak(sessions, now: now), 0);
    });

    test(
        'AUT-03 Fuera de rango: startedAt de tipo int (defecto del crash '
        'v1.1.0) se ignora sin lanzar excepcion', () {
      // El backend correcto envia String ISO-8601; un int tipo-mixto no debe
      // romper el calculo (mismo esquema de error que crasheo el widget).
      final dates = StreakService.parseSessionDates(<dynamic>[
        <String, dynamic>{'id': 1, 'startedAt': 1731600000},
        <String, dynamic>{'id': 2, 'startedAt': '2026-11-16T10:00:00Z'},
      ]);

      expect(dates, hasLength(1));
    });

    test(
        'AUT-03 Manejo de excepciones: cadenas vacias/malformadas se '
        'descartan sin lanzar excepcion', () {
      final dates = StreakService.parseSessionDates(<dynamic>[
        <String, dynamic>{'startedAt': ''},
        <String, dynamic>{'startedAt': '::::'},
        <String, dynamic>{'startedAt': 'no-una-fecha'},
        <String, dynamic>{'startedAt': '2026-11-16T07:15:00Z'},
      ]);

      expect(dates, hasLength(1));
    });

    test(
        'AUT-03 Hallazgo documentado: DateTime.tryParse NORMALIZA timestamps '
        'desbordados (no los rechaza); computeStreak los neutraliza', () {
      // Hallazgo de la Fase 5: '2026-13-45T99:00:00Z' NO devuelve null,
      // Dart lo normaliza a 2027-02-18. La defensa real contra estos datos
      // absurdos es computeStreak, que descarta fechas futuras -> racha 0.
      final dates = StreakService.parseSessionDates(<dynamic>[
        <String, dynamic>{'startedAt': '2026-13-45T99:00:00Z'},
        <String, dynamic>{'startedAt': '99999-99-99T99:99:99Z'},
      ]);

      expect(dates, hasLength(2), reason: 'tryParse los normaliza, no los rechaza');
      expect(
        StreakService.computeStreak(dates, now: DateTime(2026, 11, 16)),
        0,
        reason: 'fechas futuras normalizadas no inflan la racha',
      );
    });
  });

  // -------------------------------------------------------------------
  // FASE 3 - PRUEBAS DE INTEGRACION (AUT-04, AUT-05)
  // -------------------------------------------------------------------
  group('P13 Fase 3 | Integracion | app <-> servicio wearable-sessions', () {
    test('AUT-04 GET wearable-sessions 200 -> racha calculada y persistida',
        () async {
      // Fechas RELATIVAS a hoy: refreshFromBackend computa con
      // DateTime.now() y parseSessionDates hace toLocal(), asi que fechas
      // fijas en el mock se rompen cuando cambia el dia o la zona horaria
      // (defecto detectado por el CI en el runner UTC de GitHub Actions).
      final now = DateTime.now();
      String isoDaysAgo(int daysAgo) =>
          DateTime(now.year, now.month, now.day - daysAgo, 12, 0)
              .toUtc()
              .toIso8601String();

      final httpClient = MockClient((request) async {
        expect(request.url.path.endsWith('/api/wearable-sessions'), isTrue);
        expect(request.headers['Authorization'], 'Bearer $_validToken');
        return _json([
          {'id': 1, 'startedAt': isoDaysAgo(0)},
          {'id': 2, 'startedAt': isoDaysAgo(1)},
          {'id': 3, 'startedAt': isoDaysAgo(2)},
        ], 200);
      });

      final service = StreakService(
        apiClient: ApiClient(client: httpClient),
      );

      final streak = await service.refreshFromBackend();

      expect(streak, 3);
      // La persistencia al widget se disparo como parte de la integracion.
      expect(widgetStore[StreakService.streakKey], 3);
      expect(widgetUpdateCalls, 1);
    });

    test(
        'AUT-05 API devuelve 401 -> ApiException y la racha previa se '
        'conserva (el widget nunca regresa a 0 por un error HTTP)', () async {
      widgetStore[StreakService.streakKey] = 4;

      final httpClient = MockClient((request) async {
        return _json(
          {'message': 'Sesion no valida.'},
          401,
        );
      });

      final service = StreakService(
        apiClient: ApiClient(client: httpClient),
      );

      final streak = await service.refreshFromBackend();

      expect(streak, 4);
      expect(
        widgetStore[StreakService.streakKey],
        4,
        reason: 'la persistencia no debe sobreescribirse con un fallo HTTP',
      );
      expect(widgetUpdateCalls, 0);
    });

    test(
        'AUT-05 Servidor no responde -> mensaje de red claro y racha '
        'conservada', () async {
      widgetStore[StreakService.streakKey] = 8;

      final httpClient = MockClient(
        (request) async => throw http.ClientException('red caida'),
      );

      final service = StreakService(
        apiClient: ApiClient(client: httpClient),
      );

      final streak = await service.refreshFromBackend();

      expect(streak, 8);
      expect(widgetStore[StreakService.streakKey], 8);
    });
  });

  group('P13 Fase 3 | Integracion | app <-> servicio auth', () {
    test('AUT-05 POST /api/auth/register 200 -> token y sesion almacenados',
        () async {
      final httpClient = MockClient((request) async {
        expect(request.url.path.endsWith('/api/auth/register'), isTrue);
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'qa_p13@test.com');
        expect(body['password'].length >= 8, isTrue);
        return _json({
          'token': 'jwt-registrado',
          'email': 'qa_p13@test.com',
          'name': 'QA P13',
          'role': 'USER',
        }, 200);
      });

      final service = AuthService(client: httpClient);
      final auth = await service.register(
        name: 'QA P13',
        email: 'qa_p13@test.com',
        password: 'QaPractica13x',
      );

      expect(auth.token, 'jwt-registrado');
      expect(auth.role, 'USER');
      // La informacion se persistio correctamente (secuencia register->storage).
      expect(await service.isAuthenticated(), isTrue);
      expect(await service.readToken(), 'jwt-registrado');
    });

    test(
        'AUT-05 POST /api/auth/register 409 (correo duplicado) -> ApiException '
        'con mensaje del backend, sin token', () async {
      final httpClient = MockClient((request) async {
        return _json(
          {'message': 'Ese correo ya esta registrado.'},
          409,
        );
      });

      final service = AuthService(client: httpClient);
      // Parte sin sesion previa: el setUp siembra un token para las demas
      // pruebas; aqui lo eliminamos para validar el caso de usuario nuevo.
      await service.logout();

      await expectLater(
        service.register(
          name: 'QA Dup',
          email: 'dup@test.com',
          password: 'QaPractica13x',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('ya esta registrado'),
          ),
        ),
      );
      expect(await service.isAuthenticated(), isFalse);
    });
  });

  // -------------------------------------------------------------------
  // PERSISTENCIA (AUT-06)
  // -------------------------------------------------------------------
  group('P13 | Persistencia | HomeWidget (SharedPreferences del widget)', () {
    test('AUT-06 Guardar y leer la racha conserva el tipo int acordado',
        () async {
      final service = StreakService();

      await service.saveStreak(7);

      expect(widgetStore[StreakService.streakKey], isA<int>());
      expect(widgetStore[StreakService.streakKey], 7);
      expect(widgetStore[StreakService.updatedAtKey], isA<String>());
      expect(await service.readStreak(), 7);
      // El guardado dispara el refresco del widget nativo.
      expect(widgetUpdateCalls, 1);
    });

    test('AUT-06 Valor fuera de rango (negativo) se limita a 0', () async {
      final service = StreakService();

      await service.saveStreak(-9);

      expect(widgetStore[StreakService.streakKey], 0);
      expect(await service.readStreak(), 0);
    });
  });
}
