import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('messaging', '0002_platform_support'),
        ('notifications', '0003_messaging_initial'),
        ('organizations', '0013_accepted_venues_reschedule_notifications'),
    ]

    operations = [
        migrations.AlterField(
            model_name='notification',
            name='kind',
            field=models.CharField(
                choices=[
                    ('booking_received', 'Booking received'),
                    ('booking_confirmed', 'Booking confirmed'),
                    ('reschedule_proposed', 'Reschedule proposed'),
                    ('reschedule_accepted', 'Reschedule accepted'),
                    ('reschedule_declined', 'Reschedule declined'),
                    ('booking_cancelled', 'Booking cancelled'),
                    ('payment_received', 'Payment received'),
                    ('wallet_topped_up', 'Wallet topped up'),
                    ('team_invite', 'Team invite'),
                    ('message_invite', 'Message invite'),
                    ('message_received', 'Message received'),
                    ('kyc_approved', 'Identity verified'),
                    ('kyc_rejected', 'Identity verification rejected'),
                    ('kyb_approved', 'Business verified'),
                    ('kyb_rejected', 'Business verification rejected'),
                ],
                db_index=True,
                max_length=32,
            ),
        ),
        migrations.AddField(
            model_name='notification',
            name='conversation',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='notifications',
                to='messaging.conversation',
            ),
        ),
        migrations.AddField(
            model_name='notification',
            name='message_invite',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='notifications',
                to='messaging.conversationinvite',
            ),
        ),
        migrations.AddField(
            model_name='notification',
            name='organization',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='notifications',
                to='organizations.organization',
            ),
        ),
    ]
