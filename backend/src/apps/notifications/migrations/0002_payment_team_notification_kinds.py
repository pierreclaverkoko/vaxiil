# Generated manually for payment / wallet / team invite notification kinds

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('notifications', '0001_accepted_venues_reschedule_notifications'),
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
                ],
                db_index=True,
                max_length=32,
            ),
        ),
    ]
