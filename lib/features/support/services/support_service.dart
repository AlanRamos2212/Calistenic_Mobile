import 'dart:io';

import '../../../core/network/api_client.dart';

class SupportReport {
  SupportReport({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    this.userId,
    this.userName,
    this.description,
    this.category,
    this.imageUrl,
    this.updatedAt,
  });
  final int id;
  final String title;
  final String status;
  final String createdAt;
  final int? userId;
  final String? userName;
  final String? description;
  final String? category;
  final String? imageUrl;
  final String? updatedAt;

  factory SupportReport.fromJson(Map<String, dynamic> j) => SupportReport(
        id: (j['id'] as num).toInt(),
        title: j['title'] as String? ?? '',
        status: j['status'] as String? ?? 'OPEN',
        createdAt: j['createdAt'] as String? ?? '',
        userId: j['userId'] is num ? (j['userId'] as num).toInt() : null,
        userName: j['userName'] as String?,
        description: j['description'] as String?,
        category: j['category'] as String?,
        imageUrl: j['imageUrl'] as String?,
        updatedAt: j['updatedAt'] as String?,
      );
}

class SupportService {
  SupportService({ApiClient? api}) : _api = api ?? ApiClient();
  final ApiClient _api;

  Future<SupportReport> create(String title, String description, String category, {File? image}) async {
    final data = image == null
        ? await _api.post('/reports', body: {'title': title, 'description': description, 'category': category})
        : await _api.postMultipart('/reports', image, 'image',
            fields: {'title': title, 'description': description, 'category': category});
    return SupportReport.fromJson(data as Map<String, dynamic>);
  }

  /// My own reports (any authenticated user).
  Future<List<SupportReport>> mine() async {
    final data = await _api.get('/reports/mine');
    final list = data as List<dynamic>;
    return list.map((e) => SupportReport.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// All reports, optionally filtered by ?status=. ADMIN only.
  Future<List<SupportReport>> all({String? status}) async {
    final query = status == null ? '' : '?status=$status';
    final data = await _api.get('/reports$query');
    final list = data as List<dynamic>;
    return list.map((e) => SupportReport.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Change report status (OPEN / IN_PROGRESS / RESOLVED). ADMIN only.
  Future<SupportReport> updateStatus(int id, String status) async {
    final data = await _api.patch('/reports/$id', body: {'status': status});
    return SupportReport.fromJson(data as Map<String, dynamic>);
  }

  /// All registered users. ADMIN only.
  Future<List<AppUser>> users() async {
    final data = await _api.get('/auth/users');
    final list = data as List<dynamic>;
    return list.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Delete a report. ADMIN only; only RESOLVED reports can be removed.
  Future<void> delete(int id) async {
    await _api.delete('/reports/$id');
  }
}

/// Registered user summary (no sensitive fields).
class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.createdAt,
    this.avatarUrl,
  });
  final String id;
  final String name;
  final String email;
  final String role;
  final String? createdAt;
  final String? avatarUrl;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: '${j['id'] ?? ''}',
        name: (j['name'] as String? ?? '').trim(),
        email: (j['email'] as String? ?? '').trim(),
        role: (j['role'] as String? ?? 'USER').trim(),
        createdAt: j['createdAt'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
      );
}
