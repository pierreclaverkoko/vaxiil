import 'package:equatable/equatable.dart';
import 'package:vaxiil_mobile/features/auth/domain/entities/organization_membership_info.dart';
import 'package:vaxiil_mobile/features/auth/domain/entities/user_legal_status.dart';
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
    this.showEmail = false,
    this.dateOfBirth,
    this.sex,
    this.age,
    this.verificationStatus,
    this.verificationRejectionReason,
    this.verifiedAt,
    this.idDocumentUrl,
    this.selfieDocumentUrl,
    this.isStaff = false,
    this.isSuperuser = false,
    this.twoFactorEnabled = true,
    this.emailVerified = true,
    this.needsEmailVerification = false,
    this.defaultCountryId,
    this.defaultCountryName,
    this.legal = const UserLegalStatus(),
  });

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
    final defaultCountry = json['default_country'];
    String? defaultCountryId;
    String? defaultCountryName;
    if (defaultCountry is Map) {
      final map = Map<String, dynamic>.from(defaultCountry);
      defaultCountryId = map['id']?.toString();
      defaultCountryName = map['name'] as String?;
    } else if (defaultCountry != null) {
      defaultCountryId = defaultCountry.toString();
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
      showEmail: json['show_email'] as bool? ?? false,
      dateOfBirth: json['date_of_birth'] as String?,
      sex: ChoiceEnumData.parse(json['sex']),
      age: json['age'] is int
          ? json['age'] as int
          : int.tryParse('${json['age']}'),
      verificationStatus: ChoiceEnumData.parse(json['verification_status']),
      verificationRejectionReason: json['rejection_reason'] as String?,
      verifiedAt: json['verified_at'] as String?,
      idDocumentUrl: json['id_document_url'] as String?,
      selfieDocumentUrl: json['selfie_document_url'] as String?,
      isStaff: json['is_staff'] as bool? ?? false,
      isSuperuser: json['is_superuser'] as bool? ?? false,
      twoFactorEnabled: json['two_factor_enabled'] as bool? ?? true,
      // Missing keys (older cached profiles): treat as verified until refresh.
      emailVerified: json['email_verified'] as bool? ?? true,
      needsEmailVerification:
          json['needs_email_verification'] as bool? ?? false,
      defaultCountryId: defaultCountryId,
      defaultCountryName: defaultCountryName,
      legal: UserLegalStatus.fromJson(
        json['legal'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json['legal'] as Map)
            : null,
      ),
    );
  }

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
  final bool showEmail;
  final String? dateOfBirth;
  final ChoiceEnumData? sex;
  final int? age;
  final ChoiceEnumData? verificationStatus;
  final String? verificationRejectionReason;
  final String? verifiedAt;
  final String? idDocumentUrl;
  final String? selfieDocumentUrl;
  final bool isStaff;
  final bool isSuperuser;
  final bool twoFactorEnabled;
  final bool emailVerified;
  final bool needsEmailVerification;
  final String? defaultCountryId;
  final String? defaultCountryName;
  final UserLegalStatus legal;

  /// KYC verified (`verification_status` code `V`).
  bool get isVerified => verificationStatus?.value == 'V';

  String get displayName {
    final fn = firstName?.trim() ?? '';
    final ln = lastName?.trim() ?? '';
    if (fn.isEmpty && ln.isEmpty) return email;
    return '$fn $ln'.trim();
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
        'show_email': showEmail,
        'date_of_birth': dateOfBirth,
        'sex': sex == null
            ? null
            : {'value': sex!.value, 'title': sex!.title, 'css': sex!.css},
        'age': age,
        'verification_status': verificationStatus == null
            ? null
            : {
                'value': verificationStatus!.value,
                'title': verificationStatus!.title,
                'css': verificationStatus!.css,
              },
        'rejection_reason': verificationRejectionReason,
        'verified_at': verifiedAt,
        'id_document_url': idDocumentUrl,
        'selfie_document_url': selfieDocumentUrl,
        'is_staff': isStaff,
        'is_superuser': isSuperuser,
        'two_factor_enabled': twoFactorEnabled,
        'email_verified': emailVerified,
        'needs_email_verification': needsEmailVerification,
        'default_country': defaultCountryId == null
            ? null
            : {
                'id': defaultCountryId,
                'name': defaultCountryName,
              },
        'legal': legal.toJson(),
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
        showEmail,
        dateOfBirth,
        sex,
        age,
        verificationStatus,
        verificationRejectionReason,
        verifiedAt,
        idDocumentUrl,
        selfieDocumentUrl,
        isStaff,
        isSuperuser,
        twoFactorEnabled,
        emailVerified,
        needsEmailVerification,
        defaultCountryId,
        defaultCountryName,
        legal,
      ];
}
