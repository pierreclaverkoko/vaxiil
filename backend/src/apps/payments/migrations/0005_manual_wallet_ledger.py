from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('payments', '0004_audit_event_mixin'),
    ]

    operations = [
        migrations.AlterField(
            model_name='refundwalletledger',
            name='kind',
            field=models.CharField(
                choices=[
                    ('C', 'Cancellation credit'),
                    ('A', 'Applied to booking'),
                    ('T', 'Store credit top-up'),
                    ('M', 'Manual adjustment'),
                ],
                max_length=1,
            ),
        ),
    ]
