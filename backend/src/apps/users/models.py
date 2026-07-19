from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone
from django.utils.translation import gettext_lazy as _

from src.apps.core.models import SoftDeleteModel
from src.apps.organizations.models import Organization
from .legal_models import LegalDocumentVersion, UserLegalAcceptance
from .otp_models import EmailOtp

__all__ = ['User', 'LegalDocumentVersion', 'UserLegalAcceptance', 'EmailOtp']


class User(AbstractUser, SoftDeleteModel):
    class UserRole(models.TextChoices):
        ADMIN = 'A', _('Admin')
        BUSINESS_OWNER = 'O', _('Business Owner')
        BUSINESS_STAFF = 'S', _('Business Staff')
        CLIENT = 'C', _('Client')

    class VerificationStatus(models.TextChoices):
        PENDING = 'P', _('Pending Verification')
        VERIFIED = 'V', _('Verified')
        REJECTED = 'R', _('Rejected')

    class Sex(models.TextChoices):
        FEMALE = 'F', _('Female')
        MALE = 'M', _('Male')
        OTHER = 'X', _('Other')
        UNDISCLOSED = 'U', _('Prefer not to say')

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
    show_email = models.BooleanField(default=False)
    two_factor_enabled = models.BooleanField(
        default=True,
        help_text='When enabled, password login requires an email verification code.',
    )
    date_of_birth = models.DateField(null=True, blank=True)
    sex = models.CharField(
        max_length=1,
        choices=Sex.choices,
        null=True,
        blank=True,
    )

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

    @property
    def age(self):
        if not self.date_of_birth:
            return None
        today = timezone.localdate()
        return today.year - self.date_of_birth.year - (
            (today.month, today.day) < (self.date_of_birth.month, self.date_of_birth.day)
        )

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

    _SEX_CSS = {
        Sex.FEMALE.value: 'danger',
        Sex.MALE.value: 'primary',
        Sex.OTHER.value: 'info',
        Sex.UNDISCLOSED.value: 'secondary',
    }

    def get_role_css(self):
        return self._ROLE_CSS.get(self.role, 'default')

    def get_verification_status_css(self):
        return self._VERIFICATION_CSS.get(self.verification_status, 'default')

    def get_sex_css(self):
        return self._SEX_CSS.get(self.sex, 'default')

    def _new_trust_alias_value(self):
        import random
        import string

        return (
            f'{"".join(random.choices(string.ascii_uppercase, k=3))}-'
            f'{"".join(random.choices(string.digits, k=4))}'
        )

    def generate_trust_alias(self):
        if not self.trust_alias:
            self.trust_alias = self._new_trust_alias_value()
            self.save(update_fields=['trust_alias'])
        return self.trust_alias

    def regenerate_trust_alias(self):
        """Always issue a fresh unique alias (e.g. when the current one is compromised)."""
        for _attempt in range(20):
            candidate = self._new_trust_alias_value()
            if candidate == self.trust_alias:
                continue
            if not User.objects.filter(trust_alias=candidate).exists():
                self.trust_alias = candidate
                self.save(update_fields=['trust_alias'])
                return self.trust_alias
        raise RuntimeError('Could not allocate a unique trust alias')
