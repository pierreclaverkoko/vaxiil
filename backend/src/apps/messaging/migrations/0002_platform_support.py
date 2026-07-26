from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('messaging', '0001_messaging_initial'),
    ]

    operations = [
        migrations.AlterField(
            model_name='conversation',
            name='kind',
            field=models.CharField(
                choices=[
                    ('direct', 'Direct'),
                    ('booking', 'Booking'),
                    ('support', 'Support'),
                    ('platform', 'Platform support'),
                ],
                db_index=True,
                max_length=16,
            ),
        ),
    ]
