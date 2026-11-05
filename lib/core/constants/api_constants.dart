/// API configuration and endpoint constants.
class ApiConstants {
  ApiConstants._();

  /// Default API base URL.
  /// 10.0.2.2 reaches the host machine from an Android emulator.
  /// On physical devices, override with `--dart-define=API_BASE_URL=http://<PC-LAN-IP>:8082/api`.
  static final String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8082/api',
  ).replaceFirst(RegExp(r'/+$'), '');

  // Auth endpoints (matching Spring Boot AuthController)
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
  static const String updateMe = '/auth/me'; // PATCH
  static const String uploadAvatar = '/auth/avatar'; // POST multipart
  static const String deviceToken = '/auth/device-token';

  // Feature endpoints (matching Spring Boot controllers)
  static const String exercises = '/exercises';
  static String exerciseDetail(String id) => '/exercises/$id';
  static const String statsUser = '/stats/user';
  static const String achievements = '/achievements';
  static const String posts = '/posts';

  // Routines (Fase B contract)
  static const String routines = '/routines';
  static String routineDetail(String id) => '/routines/$id';

  // Wearable sessions (per-exercise workout logging)
  static const String sessionStart = '/wearable-sessions/start';
  static String sessionMetrics(String sessionId) => '/wearable-sessions/$sessionId/metrics';
  static String sessionStop(String sessionId) => '/wearable-sessions/$sessionId/stop';

  static String postLike(String postId) => '/posts/$postId/like';
  static String post(String postId) => '/posts/$postId';
  static String postComments(String postId) => '/posts/$postId/comments';
  static String postComment(String postId, String commentId) =>
      '/posts/$postId/comments/$commentId';

  // Secure storage keys
  static const String tokenKey = 'auth.access_token';
  static const String userNameKey = 'auth.user_name';
  static const String userEmailKey = 'auth.user_email';
  static const String userRoleKey = 'auth.user_role';

  // Offline cache keys
  static const String cacheExercises = 'cache.exercises';
  static const String cacheUserStats = 'cache.user_stats';
  static const String cacheAchievements = 'cache.achievements';
  static const String cachePosts = 'cache.posts';
  static const String cacheUserProfile = 'cache.user_profile';
  static const String cacheRoutines = 'cache.routines';
  static String cacheRoutineDetail(String id) => 'cache.routine.$id';

  // Request timeout
  static const Duration requestTimeout = Duration(seconds: 12);
}
