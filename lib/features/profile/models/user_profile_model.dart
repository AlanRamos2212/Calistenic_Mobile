/// Typed model for the `GET /api/auth/me` and `PATCH /api/auth/me` responses.
///
/// Mirrors `UserProfileResponse.java`:
/// ```
/// { id, name, email, role, createdAt, avatarUrl }
/// ```
class UserProfileModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? createdAt;
  final String? avatarUrl;

  const UserProfileModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.createdAt,
    this.avatarUrl,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: '${json['id'] ?? ''}',
      name: (json['name'] as String? ?? '').trim(),
      email: (json['email'] as String? ?? '').trim(),
      role: (json['role'] as String? ?? 'USER').trim(),
      createdAt: json['createdAt'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        if (createdAt != null) 'createdAt': createdAt,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      };

  UserProfileModel copyWith({
    String? name,
    String? avatarUrl,
  }) =>
      UserProfileModel(
        id: id,
        name: name ?? this.name,
        email: email,
        role: role,
        createdAt: createdAt,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );
}
