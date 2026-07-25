from django.db import migrations
from django.utils import timezone


def seed_legal_v1(apps, schema_editor):
    from src.apps.users.legal_content import (
        PRIVACY_2026_07_19_EN,
        PRIVACY_2026_07_19_FR,
        PRIVACY_2026_07_19_SUMMARY_EN,
        PRIVACY_2026_07_19_SUMMARY_FR,
        TERMS_EN,
        TERMS_FR,
        TERMS_SUMMARY_EN,
        TERMS_SUMMARY_FR,
    )

    LegalDocumentVersion = apps.get_model('users', 'LegalDocumentVersion')
    now = timezone.now()
    if not LegalDocumentVersion.objects.filter(
        document_type='T', version='2026.07.19'
    ).exists():
        LegalDocumentVersion.objects.create(
            document_type='T',
            version='2026.07.19',
            effective_at=now,
            is_current=True,
            body_en=TERMS_EN,
            body_fr=TERMS_FR,
            summary_en=TERMS_SUMMARY_EN,
            summary_fr=TERMS_SUMMARY_FR,
        )
    if not LegalDocumentVersion.objects.filter(
        document_type='P', version='2026.07.19'
    ).exists():
        LegalDocumentVersion.objects.create(
            document_type='P',
            version='2026.07.19',
            effective_at=now,
            is_current=True,
            body_en=PRIVACY_2026_07_19_EN,
            body_fr=PRIVACY_2026_07_19_FR,
            summary_en=PRIVACY_2026_07_19_SUMMARY_EN,
            summary_fr=PRIVACY_2026_07_19_SUMMARY_FR,
        )


def unseed(apps, schema_editor):
    LegalDocumentVersion = apps.get_model('users', 'LegalDocumentVersion')
    LegalDocumentVersion.objects.filter(version='2026.07.19').delete()


class Migration(migrations.Migration):
    dependencies = [
        ('users', '0006_legal_documents'),
    ]

    operations = [
        migrations.RunPython(seed_legal_v1, unseed),
    ]
