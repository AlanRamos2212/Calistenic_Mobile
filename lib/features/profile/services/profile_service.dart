import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/local_cache.dart';
import '../models/user_profile_model.dart';

/// Service for profile read + write operations.
///
/// Endpoints:
/// - `GET  /api/auth/me`     → fetch current user profile
/// - `PATCH /api/auth/me`    → update display name
/// - `POST /api/auth/avatar` → upload avatar photo (multipart)
class ProfileService {
  ProfileService({http.Client? client, FlutterSecureStorage? storage})
      : _api = ApiClient(client: client, storage: storage),
        _cache = LocalCache(storage: storage ?? const FlutterSecureStorage());

  final ApiClient _api;
  final LocalCache _cache;

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns the cached profile instantly (may be null on first run).
  Future<UserProfileModel?> getCached() async {
    final raw = await _cache.getJson(ApiConstants.cacheUserProfile);
    if (raw is Map<String, dynamic>) {
      return UserProfileModel.fromJson(raw);
    }
    return null;
  }

  /// Fetches fresh profile from `/api/auth/me`, persists to cache, returns model.
  ///
  /// Throws [ApiException] on HTTP errors (including 401).
  /// Falls back to cached data only on network errors (statusCode == null).
  Future<UserProfileModel> fetchAndCache() async {
    try {
      final data = await _api.get(ApiConstants.me) as Map<String, dynamic>;
      final model = UserProfileModel.fromJson(data);
      await _cache.saveJson(ApiConstants.cacheUserProfile, model.toJson());
      return model;
    } on ApiException catch (e) {
      if (e.statusCode != null) rethrow; // HTTP error → propagate
      // Network error → fall back to cache
      final cached = await getCached();
      if (cached != null) return cached;
      rethrow;
    }
  }

  // ── Update name ───────────────────────────────────────────────────────────

  /// Sends `PATCH /api/auth/me` with the new name.
  ///
  /// Returns the updated [UserProfileModel] and refreshes the cache.
  Future<UserProfileModel> updateName(String name) async {
    final data =
        await _api.patch(ApiConstants.updateMe, body: {'name': name.trim()})
            as Map<String, dynamic>;
    final model = UserProfileModel.fromJson(data);
    await _cache.saveJson(ApiConstants.cacheUserProfile, model.toJson());
    return model;
  }

  // ── Upload avatar ─────────────────────────────────────────────────────────

  /// Uploads the given image [file] to `POST /api/auth/avatar`.
  ///
  /// Returns the `avatarUrl` path returned by the backend
  /// (e.g. `/api/media/abc123.jpg`).
  Future<String> uploadAvatar(File file) async {
    final data =
        await _api.postMultipart(ApiConstants.uploadAvatar, file, 'avatar')
            as Map<String, dynamic>;
    final avatarUrl = data['avatarUrl'] as String? ?? '';

    // Refresh cached profile with new avatarUrl
    final cached = await getCached();
    if (cached != null) {
      final updated = cached.copyWith(avatarUrl: avatarUrl);
      await _cache.saveJson(
          ApiConstants.cacheUserProfile, updated.toJson());
    }

    return avatarUrl;
  }
}
