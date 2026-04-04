import 'package:equatable/equatable.dart';
import 'package:vaxiil_mobile/shared/models/choice_enum_data.dart';

/// One row from profile `organization_memberships` (DRF).
class OrganizationMembershipInfo extends Equatable {
  const OrganizationMembershipInfo({
    required this.id,
    required this.organizationId,
    this.organizationName,
    required this.role,
  });

  final String id;
  final String organizationId;
  final String? organizationName;
  final ChoiceEnumData role;

  factory OrganizationMembershipInfo.fromJson(Map<String, dynamic> json) {
    final rawRole = json['role'];
    final role = ChoiceEnumData.parse(rawRole) ??
        ChoiceEnumData(value: '', title: '', css: null);
    return OrganizationMembershipInfo(
      id: json['id']?.toString() ?? '',
      organizationId: json['organization']?.toString() ?? '',
      organizationName: json['organization_name'] as String?,
      role: role,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'organization': organizationId,
        'organization_name': organizationName,
        'role': {'value': role.value, 'title': role.title, 'css': role.css},
      };

  @override
  List<Object?> get props => [id, organizationId, role];
}
