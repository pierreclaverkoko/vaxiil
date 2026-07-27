from django.db import migrations
from django.utils import timezone


def seed_legal_fees_settlement(apps, schema_editor):
    from src.apps.users.legal_content import (
        PRIVACY_EN,
        PRIVACY_FR,
        PRIVACY_SUMMARY_EN,
        PRIVACY_SUMMARY_FR,
        TERMS_EN,
        TERMS_FR,
        TERMS_SUMMARY_EN,
        TERMS_SUMMARY_FR,
    )

    LegalDocumentVersion = apps.get_model('users', 'LegalDocumentVersion')
    version = '2026.07.26'
    now = timezone.now()

    for doc_type, body_en, body_fr, summary_en, summary_fr in (
        ('T', TERMS_EN, TERMS_FR, TERMS_SUMMARY_EN, TERMS_SUMMARY_FR),
        ('P', PRIVACY_EN, PRIVACY_FR, PRIVACY_SUMMARY_EN, PRIVACY_SUMMARY_FR),
    ):
        if LegalDocumentVersion.objects.filter(
            document_type=doc_type, version=version
        ).exists():
            continue
        LegalDocumentVersion.objects.filter(
            document_type=doc_type,
            is_current=True,
        ).update(is_current=False)
        LegalDocumentVersion.objects.create(
            document_type=doc_type,
            version=version,
            effective_at=now,
            is_current=True,
            body_en=body_en,
            body_fr=body_fr,
            summary_en=summary_en,
            summary_fr=summary_fr,
        )


def unseed(apps, schema_editor):
    LegalDocumentVersion = apps.get_model('users', 'LegalDocumentVersion')
    LegalDocumentVersion.objects.filter(version='2026.07.26').delete()
    # Restore previous current flags best-effort
    for doc_type, prev in (('T', '2026.07.19'), ('P', '2026.07.25')):
        prev_doc = (
            LegalDocumentVersion.objects.filter(document_type=doc_type, version=prev)
            .order_by('-effective_at')
            .first()
        )
        if prev_doc:
            LegalDocumentVersion.objects.filter(
                document_type=doc_type, is_current=True
            ).update(is_current=False)
            prev_doc.is_current = True
            prev_doc.save(update_fields=['is_current'])


class Migration(migrations.Migration):
    dependencies = [
        ('users', '0015_fees_settlement'),
    ]

    operations = [
        migrations.RunPython(seed_legal_fees_settlement, unseed),
    ]
