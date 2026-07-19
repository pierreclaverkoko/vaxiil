from src.apps.organizations.models import OrganizationMembership

ORG_BOOKING_ROLES = frozenset({
    OrganizationMembership.OrganizationMemberRole.OWNER,
    OrganizationMembership.OrganizationMemberRole.ADMIN,
    OrganizationMembership.OrganizationMemberRole.MANAGER,
    OrganizationMembership.OrganizationMemberRole.STAFF,
})


def user_is_org_booking_staff(user, organization_id) -> bool:
    m = OrganizationMembership.objects.filter(
        user=user,
        organization_id=organization_id,
    ).first()
    return bool(m and m.role in ORG_BOOKING_ROLES)
