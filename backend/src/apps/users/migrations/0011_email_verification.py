# Generated manually for email verification + welcome mail tracking

from django.db import migrations, models
from django.utils import timezone


def grandfather_email_verified(apps, schema_editor):
    User = apps.get_model('users', 'User')
    now = timezone.now()
    User.objects.filter(email_verified_at__isnull=True).update(email_verified_at=now)


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0010_audit_event_mixin'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='email_verified_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='user',
            name='welcome_email_sent_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.RunPython(grandfather_email_verified, migrations.RunPython.noop),
        migrations.AlterField(
            model_name='emailotp',
            name='purpose',
            field=models.CharField(
                choices=[
                    ('L', 'Login'),
                    ('C', 'Password change'),
                    ('R', 'Password reset'),
                    ('E', 'Email verification'),
                ],
                max_length=1,
            ),
        ),
    ]
