from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('organizations', '0004_rename_organization_membe_user_id_6f8b2e_idx_organizatio_user_id_db5190_idx_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='organization',
            name='kyb_submitted_at',
            field=models.DateTimeField(
                blank=True,
                help_text='Set when KYB documents are submitted for staff review.',
                null=True,
            ),
        ),
    ]
