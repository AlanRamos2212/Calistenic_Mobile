import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/post_model.dart';

/// Social feed client for the Spring Boot PostController endpoints:
/// - `GET /api/posts?page=0&size=20` (respuesta Page paginada)
/// - `POST /api/posts` (CreatePostRequest)
/// - `POST /api/posts/{id}/like` (toggle like)
/// - `GET /api/posts/{id}/comments` y `POST /api/posts/{id}/comments`
class SocialService {
  SocialService({http.Client? client, FlutterSecureStorage? storage})
    : _api = ApiClient(client: client, storage: storage);

  final ApiClient _api;

  /// Reads one page of the feed. Defaults to the backend page size (20).
  Future<List<PostModel>> feed({int page = 0, int size = 20}) async {
    final data = await _api.get('${ApiConstants.posts}?page=$page&size=$size');
    if (data is List) {
      // Tolerates a plain list response in case pagination is removed later.
      return data
          .whereType<Map<String, dynamic>>()
          .map(PostModel.fromJson)
          .toList();
    }
    if (data is Map<String, dynamic>) {
      final content = data['content'];
      if (content is! List) {
        throw const ApiException('El servidor devolvió una respuesta inválida.');
      }
      return content
          .whereType<Map<String, dynamic>>()
          .map(PostModel.fromJson)
          .toList();
    }
    throw const ApiException('El servidor devolvió una respuesta inválida.');
  }

  /// Publishes a new post. Returns the created PostResponse.
  Future<PostModel> create(String content) async {
    final data = await _api.post(ApiConstants.posts, body: {'content': content});
    if (data is! Map<String, dynamic>) {
      throw const ApiException('El servidor devolvió una respuesta inválida.');
    }
    return PostModel.fromJson(data);
  }

  /// Toggles the like of a post. Returns the new liked state.
  Future<bool> toggleLike(String postId) async {
    final data = await _api.post(ApiConstants.postLike(postId), body: {});
    if (data is! Map<String, dynamic>) {
      throw const ApiException('El servidor devolvió una respuesta inválida.');
    }
    return data['liked'] == true;
  }

  /// Adds a comment to a post.
  Future<void> comment(String postId, String content) async {
    await _api.post(ApiConstants.postComments(postId), body: {'content': content});
  }
}
