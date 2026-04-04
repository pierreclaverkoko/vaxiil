from django.contrib.auth.models import AbstractUser
from django.db import models
from src.apps.core.models import SoftDeleteModel
from src.apps.organizations.models import Organization


class User(AbstractUser, SoftDeleteModel):
    class UserRole(models.TextChoices):
        ADMIN = 'A', 'Admin'
        BUSINESS_OWNER = 'O', 'Business Owner'
        BUSINESS_STAFF = 'S', 'Business Staff'
        CLIENT = 'C', 'Client'

    class VerificationStatus(models.TextChoices):
        PENDING = 'P', 'Pending Verification'
        VERIFIED = 'V', 'Verified'
        REJECTED = 'R', 'Rejected'

    _LEGACY_ROLE = {
        'ADMIN': UserRole.ADMIN,
        'BUSINESS_OWNER': UserRole.BUSINESS_OWNER,
        'BUSINESS_STAFF': UserRole.BUSINESS_STAFF,
        'CLIENT': UserRole.CLIENT,
    }

    email = models.EmailField(unique=True)
    phone = models.CharField(max_length=20, blank=True)

    role = models.CharField(
        max_length=1,
        choices=UserRole.choices,
        default=UserRole.CLIENT,
    )
    organization = models.ForeignKey(
        Organization,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='users',
    )

    verification_status = models.CharField(
        max_length=1,
        choices=VerificationStatus.choices,
        default=VerificationStatus.PENDING,
    )

    trust_alias = models.CharField(max_length=100, unique=True, null=True, blank=True)
    is_trusted = models.BooleanField(default=False)

    id_document = models.FileField(
        upload_to='kyc_documents/',
        null=True,
        blank=True,
    )
    selfie_document = models.FileField(
        upload_to='kyc_documents/',
        null=True,
        blank=True,
    )

    verified_at = models.DateTimeField(null=True, blank=True)
    verified_by = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='verified_users',
    )
    rejection_reason = models.TextField(blank=True)

    show_real_name = models.BooleanField(default=False)
    show_phone_number = models.BooleanField(default=False)

    avatar = models.ImageField(upload_to='user_avatars/', blank=True, null=True)

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username']

    class Meta:
        db_table = 'users'
        constraints = [
            models.UniqueConstraint(
                fields=['email'],
                condition=models.Q(deleted_at__isnull=True),
                name='unique_user_email',
            ),
            models.UniqueConstraint(
                fields=['trust_alias'],
                condition=models.Q(deleted_at__isnull=True),
                name='unique_trust_alias',
            ),
        ]

    def __str__(self):
        return self.email

    @classmethod
    def coerce_role(cls, value):
        """Accept single-char code or legacy API string."""
        if value is None or value == '':
            return cls.UserRole.CLIENT
        if isinstance(value, cls.UserRole):
            return value
        if isinstance(value, str) and len(value) == 1:
            return cls.UserRole(value)
        return cls._LEGACY_ROLE.get(str(value).upper(), cls.UserRole.CLIENT)

    @property
    def is_verified(self):
        return self.verification_status == self.VerificationStatus.VERIFIED

    _ROLE_CSS = {
        UserRole.ADMIN.value: 'danger',
        UserRole.BUSINESS_OWNER.value: 'primary',
        UserRole.BUSINESS_STAFF.value: 'info',
        UserRole.CLIENT.value: 'secondary',
    }

    _VERIFICATION_CSS = {
        VerificationStatus.PENDING.value: 'warning',
        VerificationStatus.VERIFIED.value: 'success',
        VerificationStatus.REJECTED.value: 'danger',
    }

    def get_role_css(self):
        return self._ROLE_CSS.get(self.role, 'default')

    def get_verification_status_css(self):
        return self._VERIFICATION_CSS.get(self.verification_status, 'default')

    def generate_trust_alias(self):
        import random
        import string

        if not self.trust_alias:
            prefix = ''.join(random.choices(string.ascii_uppercase, k=3))
            suffix = ''.join(random.choices(string.digits, k=4))
            self.trust_alias = f'{prefix}-{suffix}'
            self.save()
        return self.trust_alias
