import uuid

from django.conf import settings
from django.db import models
from django.utils.translation import gettext_lazy as _

from src.apps.core.models import AuditedModelMixin


class LegalDocumentVersion(models.Model):
    """Immutable versioned Terms or Privacy Policy (en + fr bodies)."""

    class DocumentType(models.TextChoices):
        TERMS = 'T', _('Terms of Service')
        PRIVACY = 'P', _('Privacy Policy')

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    document_type = models.CharField(max_length=1, choices=DocumentType.choices)
    version = models.CharField(max_length=32)
    effective_at = models.DateTimeField()
    is_current = models.BooleanField(default=False)
    body_en = models.TextField()
    body_fr = models.TextField()
    summary_en = models.CharField(max_length=500, blank=True)
    summary_fr = models.CharField(max_length=500, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'legal_document_versions'
        ordering = ['-effective_at']
        constraints = [
            models.UniqueConstraint(
                fields=['document_type', 'version'],
                name='unique_legal_doc_type_version',
            ),
        ]
        indexes = [
            models.Index(fields=['document_type', 'is_current']),
        ]

    def __str__(self):
        return f'{self.get_document_type_display()} {self.version}'


class UserLegalAcceptance(AuditedModelMixin, models.Model):
    """Audit trail of a user's acceptance of a legal document version."""

    class Source(models.TextChoices):
        SIGNUP = 'S', _('Signup')
        REACCEPT = 'R', _('Re-accept')
        GOOGLE_SIGNUP = 'G', _('Google signup')

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='legal_acceptances',
    )
    document = models.ForeignKey(
        LegalDocumentVersion,
        on_delete=models.PROTECT,
        related_name='acceptances',
    )
    accepted_at = models.DateTimeField(auto_now_add=True)
    source = models.CharField(
        max_length=1,
        choices=Source.choices,
        default=Source.SIGNUP,
    )

    class Meta:
        db_table = 'user_legal_acceptances'
        ordering = ['-accepted_at']
        indexes = [
            models.Index(fields=['user', 'document']),
            models.Index(fields=['accepted_at']),
        ]

    def __str__(self):
        return f'{self.user_id} accepted {self.document_id}'
