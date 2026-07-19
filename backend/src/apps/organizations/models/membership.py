import uuid

from django.db import models
from django.utils.translation import gettext_lazy as _

from src.apps.core.models import TimeStampedModel


class OrganizationMembership(TimeStampedModel):
    """Links users to organizations with a role on that link (many-to-many)."""

    class OrganizationMemberRole(models.TextChoices):
        OWNER = "O", _("Owner")
        ADMIN = "A", _("Admin")
        MANAGER = "M", _("Manager")
        STAFF = "T", _("Staff")
        CASHIER = "C", _("Cashier")
        DELIVERY = "D", _("Delivery")

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        "users.User",
        on_delete=models.CASCADE,
        related_name="organization_memberships",
    )
    organization = models.ForeignKey(
        "organizations.Organization",
        on_delete=models.CASCADE,
        related_name="memberships",
    )
    role = models.CharField(
        max_length=1,
        choices=OrganizationMemberRole.choices,
        default=OrganizationMemberRole.STAFF,
    )

    class Meta:
        db_table = "organization_memberships"
        constraints = [
            models.UniqueConstraint(
                fields=["user", "organization"],
                name="unique_user_organization_membership",
            ),
        ]
        indexes = [
            models.Index(fields=["user"]),
            models.Index(fields=["organization"]),
            models.Index(fields=["role"]),
        ]

    _MEMBERSHIP_ROLE_CSS = {
        OrganizationMemberRole.OWNER.value: "primary",
        OrganizationMemberRole.ADMIN.value: "danger",
        OrganizationMemberRole.MANAGER.value: "info",
        OrganizationMemberRole.STAFF.value: "secondary",
        OrganizationMemberRole.CASHIER.value: "warning",
        OrganizationMemberRole.DELIVERY.value: "default",
    }

    @property
    def user_role(self):
        """Mirrors linked user's global role (for ChoiceEnumField on team payloads)."""
        return self.user.role

    def get_user_role_display(self):
        return self.user.get_role_display()

    def get_user_role_css(self):
        return self.user.get_role_css()

    def get_role_css(self):
        return self._MEMBERSHIP_ROLE_CSS.get(self.role, "default")

    def __str__(self):
        return f"{self.user_id} @ {self.organization_id} ({self.role})"


class OrganizationTeamInvite(TimeStampedModel):
    """Pending invitation for a person who has not registered yet."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    organization = models.ForeignKey(
        "organizations.Organization",
        on_delete=models.CASCADE,
        related_name="team_invites",
    )
    email = models.EmailField()
    role = models.CharField(
        max_length=1,
        choices=OrganizationMembership.OrganizationMemberRole.choices,
        default=OrganizationMembership.OrganizationMemberRole.STAFF,
    )
    token = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    created_by = models.ForeignKey(
        "users.User",
        on_delete=models.SET_NULL,
        null=True,
        related_name="organization_team_invites_created",
    )
    accepted_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "organization_team_invites"
        constraints = [
            models.UniqueConstraint(
                fields=["organization", "email"],
                condition=models.Q(accepted_at__isnull=True),
                name="unique_pending_organization_team_invite",
            ),
        ]
        indexes = [
            models.Index(fields=["organization"]),
            models.Index(fields=["email"]),
            models.Index(fields=["token"]),
        ]

    def __str__(self):
        return f"{self.email} invited to {self.organization_id}"
