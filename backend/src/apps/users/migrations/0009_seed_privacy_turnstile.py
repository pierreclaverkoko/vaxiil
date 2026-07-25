from django.db import migrations
from django.utils import timezone


def seed_privacy_turnstile(apps, schema_editor):
    from src.apps.users.legal_content import (
        PRIVACY_EN,
        PRIVACY_FR,
        PRIVACY_SUMMARY_EN,
        PRIVACY_SUMMARY_FR,
    )

    LegalDocumentVersion = apps.get_model('users', 'LegalDocumentVersion')
    version = '2026.07.25'
    if LegalDocumentVersion.objects.filter(
        document_type='P', version=version
    ).exists():
        return

    LegalDocumentVersion.objects.filter(
        document_type='P',
        is_current=True,
    ).update(is_current=False)

    LegalDocumentVersion.objects.create(
        document_type='P',
        version=version,
        effective_at=timezone.now(),
        is_current=True,
        body_en=PRIVACY_EN,
        body_fr=PRIVACY_FR,
        summary_en=PRIVACY_SUMMARY_EN,
        summary_fr=PRIVACY_SUMMARY_FR,
    )


def unseed(apps, schema_editor):
    LegalDocumentVersion = apps.get_model('users', 'LegalDocumentVersion')
    LegalDocumentVersion.objects.filter(
        document_type='P', version='2026.07.25'
    ).delete()
    # Restore prior privacy version as current when present.
    prior = (
        LegalDocumentVersion.objects.filter(
            document_type='P', version='2026.07.19'
        )
        .order_by('-id')
        .first()
    )
    if prior and not LegalDocumentVersion.objects.filter(
        document_type='P', is_current=True
    ).exists():
        prior.is_current = True
        prior.save(update_fields=['is_current'])


class Migration(migrations.Migration):
    dependencies = [
        ('users', '0008_email_otp_and_two_factor'),
    ]

    operations = [
        migrations.RunPython(seed_privacy_turnstile, unseed),
    ]
