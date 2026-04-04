import 'package:equatable/equatable.dart';
import 'package:vaxiil_mobile/features/auth/domain/entities/organization_membership_info.dart';
import 'package:vaxiil_mobile/shared/models/choice_enum_data.dart';

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
    this.organizationName,
    this.organizationMemberships = const [],
    this.trustAlias,
    this.avatarUrl,
    this.showRealName = false,
    this.showPhoneNumber = false,
    this.verificationStatus,
    this.verificationRejectionReason,
    this.verifiedAt,
  });

  final String id;
  final String email;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final ChoiceEnumData? role;
  final String? organization;
  final String? organizationName;
  final List<OrganizationMembershipInfo> organizationMemberships;
  final String? trustAlias;
  final String? avatarUrl;
  final bool showRealName;
  final bool showPhoneNumber;
  final ChoiceEnumData? verificationStatus;
  final String? verificationRejectionReason;
  final String? verifiedAt;

  String get displayName {
    final fn = firstName?.trim() ?? '';
    final ln = lastName?.trim() ?? '';
    if (fn.isEmpty && ln.isEmpty) return email;
    return '$fn $ln'.trim();
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final rawMemberships = json['organization_memberships'];
    final memberships = <OrganizationMembershipInfo>[];
    if (rawMemberships is List) {
      for (final e in rawMemberships) {
        if (e is Map) {
          memberships.add(
            OrganizationMembershipInfo.fromJson(
              Map<String, dynamic>.from(e),
            ),
          );
        }
      }
    }
    return AuthUser(
      id: json['id']?.toString() ?? '',
      email: json['email'] as String? ?? '',
      username: json['username'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      phone: json['phone'] as String?,
      role: ChoiceEnumData.parse(json['role']),
      organization: json['organization']?.toString(),
      organizationName: json['organization_name'] as String?,
      organizationMemberships: memberships,
      trustAlias: json['trust_alias'] as String?,
      avatarUrl: json['avatar'] as String?,
      showRealName: json['show_real_name'] as bool? ?? false,
      showPhoneNumber: json['show_phone_number'] as bool? ?? false,
      verificationStatus: ChoiceEnumData.parse(json['verification_status']),
      verificationRejectionReason: json['rejection_reason'] as String?,
      verifiedAt: json['verified_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'role': role == null
            ? null
            : {'value': role!.value, 'title': role!.title, 'css': role!.css},
        'organization': organization,
        'organization_name': organizationName,
        'organization_memberships':
            organizationMemberships.map((m) => m.toJson()).toList(),
        'trust_alias': trustAlias,
        'avatar': avatarUrl,
        'show_real_name': showRealName,
        'show_phone_number': showPhoneNumber,
        'verification_status': verificationStatus == null
            ? null
            : {
                'value': verificationStatus!.value,
                'title': verificationStatus!.title,
                'css': verificationStatus!.css,
              },
        'rejection_reason': verificationRejectionReason,
        'verified_at': verifiedAt,
      };

  @override
  List<Object?> get props => [
        id,
        email,
        avatarUrl,
        organization,
        organizationMemberships,
        showRealName,
        showPhoneNumber,
        verificationStatus,
        verificationRejectionReason,
        verifiedAt,
      ];
}
