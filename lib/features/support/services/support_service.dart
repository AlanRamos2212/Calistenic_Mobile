import 'dart:io';

import '../../../core/network/api_client.dart';

class SupportReport {
  SupportReport({required this.id, required this.title, required this.status, required this.createdAt});
  final int id;
  final String title;
  final String status;
  final String createdAt;

  factory SupportReport.fromJson(Map<String, dynamic> j) => SupportReport(
        id: (j['id'] as num).toInt(),
        title: j['title'] as String? ?? '',
        status: j['status'] as String? ?? '',
        createdAt: j['createdAt'] as String? ?? '',
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

  Future<List<SupportReport>> mine() async {
    final data = await _api.get('/reports/mine');
    final list = data as List<dynamic>;
    return list.map((e) => SupportReport.fromJson(e as Map<String, dynamic>)).toList();
  }
}
