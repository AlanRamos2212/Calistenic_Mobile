/// Response model returned by `/api/auth/login` and `/api/auth/register`.
class AuthResponse {
  final String token;
  final String email;
  final String name;
  final String role;

  const AuthResponse({
    required this.token,
    required this.email,
    required this.name,
    required this.role,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: (json['token'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'USER',
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'email': email,
    'name': name,
    'role': role,
  };
}
