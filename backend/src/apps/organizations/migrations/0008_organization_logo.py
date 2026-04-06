from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('organizations', '0007_alter_organizationaddress_country'),
    ]

    operations = [
        migrations.AddField(
            model_name='organization',
            name='logo',
            field=models.ImageField(
                blank=True,
                help_text='Square company logo (1:1). Required when creating a new organization via API.',
                null=True,
                upload_to='organization_logos/',
            ),
        ),
    ]
