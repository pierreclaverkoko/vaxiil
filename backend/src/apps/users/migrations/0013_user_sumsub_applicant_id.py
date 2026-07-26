from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0012_user_default_country'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='sumsub_applicant_id',
            field=models.CharField(
                blank=True,
                default='',
                help_text='Sumsub applicant id when KYC runs via Sumsub.',
                max_length=64,
            ),
        ),
    ]
