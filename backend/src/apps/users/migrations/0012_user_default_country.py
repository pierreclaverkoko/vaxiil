# Generated manually for User.default_country

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('organizations', '0014_cities_country_and_city_fk'),
        ('users', '0011_email_verification'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='default_country',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='users_with_default',
                to='organizations.country',
            ),
        ),
    ]
