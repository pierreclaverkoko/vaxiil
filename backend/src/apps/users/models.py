from django.contrib.auth.models import AbstractUser
from django.db import models
from src.apps.core.models import SoftDeleteModel
from src.apps.organizations.models import Organization


class UserRole(models.TextChoices):
    ADMIN = 'ADMIN', 'Admin'
    BUSINESS_OWNER = 'BUSINESS_OWNER', 'Business Owner'
    BUSINESS_STAFF = 'BUSINESS_STAFF', 'Business Staff'
    CLIENT = 'CLIENT', 'Client'


class VerificationStatus(models.TextChoices):
    PENDING = 'PENDING', 'Pending Verification'
    VERIFIED = 'VERIFIED', 'Verified'
    REJECTED = 'REJECTED', 'Rejected'


class User(AbstractUser, SoftDeleteModel):
    email = models.EmailField(unique=True)
    phone = models.CharField(max_length=20, blank=True)
    
    # Role and organization
    role = models.CharField(max_length=20, choices=UserRole.choices)
    organization = models.ForeignKey(
        Organization,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='users'
    )
    
    # KYC Fields
    verification_status = models.CharField(
        max_length=20,
        choices=VerificationStatus.choices,
        default=VerificationStatus.PENDING
    )
    
    # Trust alias system
    trust_alias = models.CharField(max_length=100, unique=True, null=True, blank=True)
    is_trusted = models.BooleanField(default=False)
    
    # KYC documents
    id_document = models.FileField(
        upload_to='kyc_documents/',
        null=True,
        blank=True
    )
    selfie_document = models.FileField(
        upload_to='kyc_documents/',
        null=True,
        blank=True
    )
    
    # Verification metadata
    verified_at = models.DateTimeField(null=True, blank=True)
    verified_by = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='verified_users'
    )
    rejection_reason = models.TextField(blank=True)
    
    # Privacy settings
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
                name='unique_user_email'
            ),
            models.UniqueConstraint(
                fields=['trust_alias'],
                condition=models.Q(deleted_at__isnull=True),
                name='unique_trust_alias'
            ),
        ]

    def __str__(self):
        return self.email

    @property
    def is_verified(self):
        return self.verification_status == VerificationStatus.VERIFIED

    def generate_trust_alias(self):
        import random
        import string
        
        if not self.trust_alias:
            prefix = ''.join(random.choices(string.ascii_uppercase, k=3))
            suffix = ''.join(random.choices(string.digits, k=4))
            self.trust_alias = f"{prefix}-{suffix}"
            self.save()
        return self.trust_alias
