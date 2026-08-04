from django.db import migrations
from django.utils import timezone


def seed_legal_cancel_refunds(apps, schema_editor):
    from src.apps.users.legal_content import (
        TERMS_EN,
        TERMS_FR,
        TERMS_SUMMARY_EN,
        TERMS_SUMMARY_FR,
    )

    LegalDocumentVersion = apps.get_model('users', 'LegalDocumentVersion')
    version = '2026.08.05'
    now = timezone.now()

    if LegalDocumentVersion.objects.filter(document_type='T', version=version).exists():
        return
    LegalDocumentVersion.objects.filter(document_type='T', is_current=True).update(
        is_current=False
    )
    LegalDocumentVersion.objects.create(
        document_type='T',
        version=version,
        effective_at=now,
        is_current=True,
        body_en=TERMS_EN,
        body_fr=TERMS_FR,
        summary_en=TERMS_SUMMARY_EN,
        summary_fr=TERMS_SUMMARY_FR,
    )


def unseed(apps, schema_editor):
    LegalDocumentVersion = apps.get_model('users', 'LegalDocumentVersion')
    LegalDocumentVersion.objects.filter(document_type='T', version='2026.08.05').delete()
    prev = (
        LegalDocumentVersion.objects.filter(document_type='T', version='2026.08.04')
        .order_by('-effective_at')
        .first()
    )
    if prev:
        LegalDocumentVersion.objects.filter(document_type='T', is_current=True).update(
            is_current=False
        )
        prev.is_current = True
        prev.save(update_fields=['is_current'])


class Migration(migrations.Migration):
    dependencies = [
        ('users', '0017_seed_legal_bap_imagine'),
    ]

    operations = [
        migrations.RunPython(seed_legal_cancel_refunds, unseed),
    ]
