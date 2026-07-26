# Generated manually for notification audience scoping

from django.db import migrations, models


def backfill_audience(apps, schema_editor):
    Notification = apps.get_model('notifications', 'Notification')
    Conversation = apps.get_model('messaging', 'Conversation')

    Notification.objects.filter(organization_id__isnull=False).update(
        audience='organization'
    )

    org_kinds = (
        'booking_received',
        'team_invite',
        'kyb_approved',
        'kyb_rejected',
    )
    Notification.objects.filter(kind__in=org_kinds).update(audience='organization')

    for n in Notification.objects.filter(
        conversation_id__isnull=False, audience='personal'
    ).iterator():
        try:
            conv = Conversation.objects.get(pk=n.conversation_id)
        except Conversation.DoesNotExist:
            continue
        if conv.kind in ('booking', 'support') and conv.organization_id:
            # Client notifications on booking/support stay personal;
            # staff-side ones should have organization set by callers going forward.
            # If organization FK already set, handled above.
            if n.organization_id:
                Notification.objects.filter(pk=n.pk).update(audience='organization')
        elif conv.kind == 'platform':
            # Platform CS: staff recipients → staff; client → personal.
            # Without membership context, leave personal unless user is_staff was
            # the only participant — safest default stays personal for backfill.
            pass


class Migration(migrations.Migration):

    dependencies = [
        ('notifications', '0004_kyc_deep_links'),
    ]

    operations = [
        migrations.AddField(
            model_name='notification',
            name='audience',
            field=models.CharField(
                choices=[
                    ('personal', 'Personal'),
                    ('organization', 'Organization'),
                    ('staff', 'Platform staff'),
                ],
                db_index=True,
                default='personal',
                max_length=16,
            ),
        ),
        migrations.AddIndex(
            model_name='notification',
            index=models.Index(
                fields=['user', 'audience', '-created_at'],
                name='notificatio_user_id_aud_idx',
            ),
        ),
        migrations.RunPython(backfill_audience, migrations.RunPython.noop),
    ]
