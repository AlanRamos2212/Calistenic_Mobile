import 'dart:convert';

import 'package:calistenic_mobile/core/constants/api_constants.dart';
import 'package:calistenic_mobile/core/network/api_client.dart';
import 'package:calistenic_mobile/core/network/api_exception.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:calistenic_mobile/features/achievements/services/achievement_service.dart';
import 'package:calistenic_mobile/features/exercises/services/exercise_service.dart';
import 'package:calistenic_mobile/features/profile/services/profile_service.dart';
import 'package:calistenic_mobile/features/routines/models/routine_detail_model.dart';
import 'package:calistenic_mobile/features/routines/models/routine_summary_model.dart';
import 'package:calistenic_mobile/features/routines/services/routine_service.dart';
import 'package:calistenic_mobile/features/routines/services/workout_service.dart';
import 'package:calistenic_mobile/features/social/models/post_model.dart';
import 'package:calistenic_mobile/features/social/services/social_service.dart';
import 'package:calistenic_mobile/features/stats/services/stats_service.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const String _validToken = 'test-jwt-token';

void main() {
  // Test platform from flutter_secure_storage: keeps the token in memory so
  // ApiClient sees an active session without platform channels.
  setUpAll(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {'auth.access_token': _validToken},
    );
  });

  group('ExerciseService', () {
    test('maps the backend entity collection (muscles as CSV string)',
        () async {
      final httpClient = MockClient((request) async {
        expect(request.url.path.endsWith('/exercises'), isTrue);
        expect(request.headers['Authorization'], 'Bearer $_validToken');
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'name': 'Dominadas',
              'category': 'Fuerza',
              'level': 'Avanzado',
              'durationMin': 15,
              'muscles': 'espalda, biceps',
              'imageUrl': null,
              'gifUrl': null,
              'techniqueDescription': 'Barra pronada',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ExerciseService(client: httpClient);
      final result = await service.list();

      expect(result, hasLength(1));
      expect(result.first.id, 1);
      expect(result.first.name, 'Dominadas');
      expect(result.first.category, 'Fuerza');
      expect(result.first.level, 'Avanzado');
      expect(result.first.durationMin, 15);
      expect(result.first.muscles, ['espalda', 'biceps']);
    });

    test('propagates backend error messages with status code', () async {
      final httpClient = MockClient(
        (_) async => http.Response('{"message":"Servicio no disponible"}', 503),
      );

      final service = ExerciseService(client: httpClient);

      await expectLater(
        service.list(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            503,
          ),
        ),
      );
    });
    test('returns cached exercises when the backend is unreachable', () async {
      final onlineClient = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'name': 'Dominadas',
              'category': 'Fuerza',
              'level': 'Avanzado',
              'durationMin': 15,
              'muscles': 'espalda',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ExerciseService(client: onlineClient);
      await service.fetchAndCache();

      final offlineClient = MockClient((request) async {
        throw http.ClientException('Network down');
      });

      final offlineService = ExerciseService(client: offlineClient);
      final fallbackResults = await offlineService.list();

      expect(fallbackResults, hasLength(1));
      expect(fallbackResults.first.name, 'Dominadas');
    });
  });

  group('StatsService', () {
    test('parses UserStatsResponse with chart series', () async {
      final httpClient = MockClient((request) async {
        expect(request.url.path.endsWith('/stats/user'), isTrue);
        return http.Response(
          jsonEncode({
            'totalWorkouts': 12,
            'totalMinutes': 340,
            'avgBpm': 142,
            'weeklySeries': [
              {'label': 'S1', 'value': 3.0},
              {'label': 'S2', 'value': 5.5},
            ],
            'bpmSeries': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = StatsService(client: httpClient);
      final stats = await service.fetch();

      expect(stats.totalWorkouts, 12);
      expect(stats.totalMinutes, 340);
      expect(stats.avgBpm, 142);
      expect(stats.weeklySeries, hasLength(2));
      expect(stats.weeklySeries.last.value, 5.5);
      expect(stats.bpmSeries, isEmpty);
    });

    test('returns cached user stats when network is unavailable', () async {
      final onlineClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'totalWorkouts': 25,
            'totalMinutes': 500,
            'avgBpm': 135,
            'weeklySeries': [],
            'bpmSeries': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = StatsService(client: onlineClient);
      await service.fetchAndCache();

      final offlineClient = MockClient((request) async {
        throw http.ClientException('Network down');
      });

      final offlineService = StatsService(client: offlineClient);
      final stats = await offlineService.fetch();

      expect(stats.totalWorkouts, 25);
      expect(stats.totalMinutes, 500);
    });
  });

  group('AchievementService', () {
    test('parses unlocked AchievementResponse entries', () async {
      final httpClient = MockClient((request) async {
        expect(request.url.path.endsWith('/achievements'), isTrue);
        return http.Response(
          jsonEncode([
            {
              'id': 7,
              'code': 'FIRST_WORKOUT',
              'title': 'Primer entrenamiento',
              'description': 'Completaste tu primera sesión.',
              'unlockedAt': '2026-11-04T10:15:30+00:00',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = AchievementService(client: httpClient);
      final result = await service.list();

      expect(result, hasLength(1));
      expect(result.first.code, 'FIRST_WORKOUT');
      expect(result.first.title, 'Primer entrenamiento');
    });
  });

  group('SocialService', () {
    test('feed unwraps the Page<PostResponse> content array', () async {
      final httpClient = MockClient((request) async {
        expect(request.url.queryParameters['page'], '0');
        expect(request.url.queryParameters['size'], '20');
        return http.Response(
          jsonEncode({
            'content': [
              {
                'id': 42,
                'userId': 3,
                'userName': 'Sofía M.',
                'content': 'Nueva rutina completada.',
                'likesCount': 14,
                'commentsCount': 3,
                'likedByCurrentUser': true,
              },
            ],
            'totalElements': 1,
            'number': 0,
            'size': 20,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = SocialService(client: httpClient);
      final posts = await service.feed();

      expect(posts, hasLength(1));
      expect(posts.first, isA<PostModel>());
      expect(posts.first.id, '42');
      expect(posts.first.authorName, 'Sofía M.');
      expect(posts.first.likes, 14);
      expect(posts.first.comments, 3);
      expect(posts.first.likedByCurrentUser, isTrue);
    });

    test('toggleLike returns the new liked state', () async {
      final httpClient = MockClient((request) async {
        expect(request.url.path.endsWith('/posts/42/like'), isTrue);
        return http.Response(
          jsonEncode({'postId': 42, 'liked': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = SocialService(client: httpClient);
      final liked = await service.toggleLike('42');

      expect(liked, isTrue);
    });

    test('create sends content and builds a PostModel', () async {
      late http.Request captured;
      final httpClient = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'id': 100,
            'userId': 3,
            'userName': 'Alex',
            'content': 'Hola comunidad',
            'likesCount': 0,
            'commentsCount': 0,
            'likedByCurrentUser': false,
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = SocialService(client: httpClient);
      final post = await service.create('Hola comunidad');

      expect(jsonDecode(captured.body)['content'], 'Hola comunidad');
      expect(post.id, '100');
    });
  });

  group('401 session handling', () {
    test('raises ApiException(401) when the token expired', () async {
      final httpClient = MockClient(
        (_) async => http.Response('{"message":"No autorizado"}', 401),
      );

      final service = StatsService(client: httpClient);

      await expectLater(
        service.fetch(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });
  });

  // ── ProfileService ──────────────────────────────────────────────────────

  group('ProfileService', () {
    test('fetchAndCache returns a UserProfileModel from /auth/me', () async {
      final httpClient = MockClient((request) async {
        expect(request.url.path.endsWith('/auth/me'), isTrue);
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer $_validToken');
        return http.Response(
          jsonEncode({
            'id': 42,
            'name': 'Alan Atleta',
            'email': 'alan@ejemplo.com',
            'role': 'USER',
            'createdAt': '2025-01-15T10:00:00',
            'avatarUrl': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ProfileService(client: httpClient);
      final profile = await service.fetchAndCache();

      expect(profile.id, '42');
      expect(profile.name, 'Alan Atleta');
      expect(profile.email, 'alan@ejemplo.com');
      expect(profile.role, 'USER');
      expect(profile.avatarUrl, isNull);
    });

    test('updateName sends PATCH with correct body and returns updated model',
        () async {
      http.BaseRequest? captured;
      final httpClient = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'id': 42,
            'name': 'Nuevo Nombre',
            'email': 'alan@ejemplo.com',
            'role': 'USER',
            'createdAt': '2025-01-15T10:00:00',
            'avatarUrl': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ProfileService(client: httpClient);
      final updated = await service.updateName('Nuevo Nombre');

      expect(captured?.method, 'PATCH');
      expect(captured?.url.path.endsWith('/auth/me'), isTrue);
      expect(jsonDecode((captured as http.Request).body)['name'], 'Nuevo Nombre');
      expect(updated.name, 'Nuevo Nombre');
    });

    test('fetchAndCache falls back to cache on network error', () async {
      // Pre-seed the cache via a successful call first
      int callCount = 0;
      final httpClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          // First call succeeds → populates cache
          return http.Response(
            jsonEncode({
              'id': 1,
              'name': 'Cached User',
              'email': 'x@x.com',
              'role': 'USER',
              'createdAt': null,
              'avatarUrl': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        // Second call: network failure
        throw http.ClientException('Sin conexión');
      });

      final service = ProfileService(client: httpClient);
      await service.fetchAndCache(); // populates cache
      final fallback = await service.fetchAndCache(); // should use cache

      expect(fallback.name, 'Cached User');
    });

    test('fetchAndCache propagates HTTP 401 without falling back', () async {
      final httpClient = MockClient(
        (_) async => http.Response('{"message":"No autorizado"}', 401),
      );

      final service = ProfileService(client: httpClient);

      await expectLater(
        service.fetchAndCache(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });
  });

  // ── RoutineService (GET /api/routines) ─────────────────────────────────

  group('RoutineService', () {
    const routineJson = [
      {
        'id': 2,
        'title': 'Fuerza Superior',
        'subtitle': 'Espalda y empuje',
        'category': 'upper_body',
        'level': 'intermedio',
        'durationMin': 40,
        'estimatedCalories': 450,
        'coverImageUrl': null,
        'exerciseCount': 2,
      },
    ];

    test('list parses RoutineResponse cards with meta text', () async {
      final httpClient = MockClient((request) async {
        expect(request.url.path.endsWith('/routines'), isTrue);
        return http.Response(jsonEncode(routineJson), 200,
            headers: {'content-type': 'application/json'});
      });

      final service = RoutineService(client: httpClient);
      final routines = await service.list();

      expect(routines, hasLength(1));
      expect(routines.first, isA<RoutineSummaryModel>());
      expect(routines.first.id, '2');
      expect(routines.first.title, 'Fuerza Superior');
      expect(routines.first.exerciseCount, 2);
      expect(routines.first.meta, '40 min · 450 kcal · 2 ejercicios');
    });

    test('detail parses ordered exercises with prescriptions', () async {
      final httpClient = MockClient((request) async {
        expect(request.url.path.endsWith('/routines/2'), isTrue);
        return http.Response(
          jsonEncode({
            'id': 2,
            'title': 'Fuerza Superior',
            'subtitle': 'Espalda y empuje',
            'category': 'upper_body',
            'level': 'intermedio',
            'durationMin': 40,
            'estimatedCalories': 450,
            'exercises': [
              {
                'id': 2,
                'name': 'Pull-ups',
                'category': 'upper_body',
                'level': 'intermedio',
                'muscles': 'Espalda,Bíceps',
                'estimatedCalories': 150,
                'position': 1,
                'sets': 4,
                'reps': 8,
                'restSeconds': 90,
              },
              {
                'id': 4,
                'name': 'Plank Isométrico',
                'category': 'core',
                'level': 'principiante',
                'position': 2,
                'sets': 3,
                'reps': null,
                'restSeconds': 45,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = RoutineService(client: httpClient);
      final detail = await service.detail('2');

      expect(detail, isA<RoutineDetailModel>());
      expect(detail.exercises, hasLength(2));
      expect(detail.exercises[0].prescriptionLabel, '4 × 8');
      expect(detail.exercises[0].restLabel, '90 s');
      expect(detail.exercises[0].estimatedCalories, 150);
      // Time-based exercise keeps reps nullable.
      expect(detail.exercises[1].reps, isNull);
      expect(detail.exercises[1].prescriptionLabel, '3 series');
    });

    test('list falls back to cache when the backend is unreachable', () async {
      final online = MockClient((_) async => http.Response(
          jsonEncode(routineJson), 200,
          headers: {'content-type': 'application/json'}));
      await RoutineService(client: online).fetchAndCache();

      final offline = RoutineService(
        client: MockClient((_) async => throw http.ClientException('down')),
      );
      expect((await offline.list()).first.title, 'Fuerza Superior');
    });

    test('list throws when backend is down and cache is empty', () async {
      final storage = FlutterSecureStorage();
      await storage.delete(key: ApiConstants.cacheRoutines);
      final offline = RoutineService(
        client: MockClient((_) async => throw http.ClientException('down')),
        storage: storage,
      );
      await expectLater(
        offline.list(),
        throwsA(isA<Exception>()),
      );
    });

    test('list rethrows 401 without falling back to cache', () async {
      final httpClient = MockClient((_) async => http.Response(
        '{"message":"No autorizado"}', 401,
        headers: {'content-type': 'application/json'},
      ));
      final service = RoutineService(client: httpClient);
      await expectLater(
        service.list(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('list throws when backend returns invalid JSON', () async {
      final storage = FlutterSecureStorage();
      await storage.delete(key: ApiConstants.cacheRoutines);
      final httpClient = MockClient((_) async => http.Response(
        '{invalid json', 200,
        headers: {'content-type': 'application/json'},
      ));
      final service = RoutineService(client: httpClient, storage: storage);
      await expectLater(
        service.list(),
        throwsA(isA<Exception>()),
      );
    });  });

  // ── WorkoutService (wearable-sessions start/stop) ──────────────────────

  group('WorkoutService', () {
    test('startSession posts only the exerciseId and returns the session id',
        () async {
      late http.Request captured;
      final httpClient = MockClient((request) async {
        expect(request.url.path.endsWith('/wearable-sessions/start'), isTrue);
        expect(request.method, 'POST');
        captured = request;
        return http.Response(jsonEncode({
          'id': 77,
          'exerciseId': 2,
          'status': 'STARTED',
        }), 200, headers: {'content-type': 'application/json'});
      });

      final service = WorkoutService(client: ApiClient(client: httpClient));
      final id = await service.startSession(2);

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['exerciseId'], 2);
      // Sessions from the phone are logged without a wrist device.
      expect(body.containsKey('wearableId'), isFalse);
      expect(body.containsKey('userId'), isFalse);
      expect(id, 77);
    });

    test('stopSession sends honest metrics: duration + calories, no HR data',
        () async {
      late http.Request captured;
      final httpClient = MockClient((request) async {
        expect(request.url.path.endsWith('/wearable-sessions/77/stop'),
            isTrue);
        captured = request;
        return http.Response(jsonEncode({'status': 'COMPLETED'}), 200,
            headers: {'content-type': 'application/json'});
      });

      final service = WorkoutService(client: ApiClient(client: httpClient));
      await service.stopSession(77, durationSec: 612, caloriesBurned: 96.5);

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['durationSec'], 612);
      expect(body['caloriesBurned'], 96.5);
      expect(DateTime.tryParse('${body['endedAt']}'), isNotNull);
      // There is no heart-rate measured on the phone: those fields stay out.
      expect(body.containsKey('avgHr'), isFalse);
      expect(body.containsKey('maxHr'), isFalse);
      expect(body.containsKey('minHr'), isFalse);
    });

    test('startSession converts numeric string id from server', () async {
      final httpClient = MockClient((request) async {
        expect(request.url.path.endsWith('/wearable-sessions/start'), isTrue);
        expect(request.method, 'POST');
        return http.Response(jsonEncode({'id': '77'}), 200,
            headers: {'content-type': 'application/json'});
      });

      final service = WorkoutService(client: ApiClient(client: httpClient));
      final id = await service.startSession(2);

      expect(id, 77);
    });

    test('startSession throws when response has no id', () async {
      final httpClient = MockClient((_) async => http.Response(
        jsonEncode({'exerciseId': 2}), 200,
        headers: {'content-type': 'application/json'},
      ));
      final service = WorkoutService(client: ApiClient(client: httpClient));
      await expectLater(
        service.startSession(2),
        throwsA(isA<ApiException>()),
      );
    });

    test('startSession throws when response structure is invalid', () async {
      final httpClient = MockClient((_) async => http.Response(
        '[]', 200,
        headers: {'content-type': 'application/json'},
      ));
      final service = WorkoutService(client: ApiClient(client: httpClient));
      await expectLater(
        service.startSession(2),
        throwsA(isA<ApiException>()),
      );
    });

    test('startSession propagates network error', () async {
      final httpClient = MockClient((_) async => throw http.ClientException('down'));
      final service = WorkoutService(client: ApiClient(client: httpClient));
      await expectLater(
        service.startSession(2),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
