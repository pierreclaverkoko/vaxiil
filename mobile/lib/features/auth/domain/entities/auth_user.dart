import 'package:equatable/equatable.dart';

class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.email,
    this.username,
    this.firstName,
    this.lastName,
    this.phone,
    this.role,
    this.organization,
    this.trustAlias,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? role;
  final String? organization;
  final String? trustAlias;
  final String? avatarUrl;

  String get displayName {
    final fn = firstName?.trim() ?? '';
    final ln = lastName?.trim() ?? '';
    if (fn.isEmpty && ln.isEmpty) return email;
    return '$fn $ln'.trim();
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      email: json['email'] as String? ?? '',
      username: json['username'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String?,
      organization: json['organization']?.toString(),
      trustAlias: json['trust_alias'] as String?,
      avatarUrl: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'role': role,
        'organization': organization,
        'trust_alias': trustAlias,
        'avatar': avatarUrl,
      };

  @override
  List<Object?> get props => [id, email, avatarUrl];
}
