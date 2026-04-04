# Generated manually for OrganizationMembership

import uuid

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


def migrate_user_org_to_memberships(apps, schema_editor):
    User = apps.get_model('users', 'User')
    OrganizationMembership = apps.get_model('organizations', 'OrganizationMembership')

    role_map = {
        'BUSINESS_OWNER': 'OWNER',
        'BUSINESS_STAFF': 'STAFF',
        'ADMIN': 'ADMIN',
        'CLIENT': 'STAFF',
    }
    for user in User.objects.exclude(organization_id__isnull=True).iterator():
        role = role_map.get(user.role, 'STAFF')
        OrganizationMembership.objects.get_or_create(
            user_id=user.id,
            organization_id=user.organization_id,
            defaults={'role': role},
        )


def noop_reverse(apps, schema_editor):
    OrganizationMembership = apps.get_model('organizations', 'OrganizationMembership')
    OrganizationMembership.objects.all().delete()


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('organizations', '0002_organization_verified_by'),
    ]

    operations = [
        migrations.CreateModel(
            name='OrganizationMembership',
            fields=[
                (
                    'created_at',
                    models.DateTimeField(auto_now_add=True),
                ),
                (
                    'updated_at',
                    models.DateTimeField(auto_now=True),
                ),
                (
                    'id',
                    models.UUIDField(
                        default=uuid.uuid4,
                        editable=False,
                        primary_key=True,
                        serialize=False,
                    ),
                ),
                (
                    'role',
                    models.CharField(
                        choices=[
                            ('OWNER', 'Owner'),
                            ('ADMIN', 'Admin'),
                            ('MANAGER', 'Manager'),
                            ('STAFF', 'Staff'),
                            ('CASHIER', 'Cashier'),
                            ('DELIVERY', 'Delivery'),
                        ],
                        default='STAFF',
                        max_length=20,
                    ),
                ),
                (
                    'organization',
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name='memberships',
                        to='organizations.organization',
                    ),
                ),
                (
                    'user',
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name='organization_memberships',
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                'db_table': 'organization_memberships',
            },
        ),
        migrations.AddConstraint(
            model_name='organizationmembership',
            constraint=models.UniqueConstraint(
                fields=('user', 'organization'),
                name='unique_user_organization_membership',
            ),
        ),
        migrations.AddIndex(
            model_name='organizationmembership',
            index=models.Index(fields=['user'], name='organization_membe_user_id_6f8b2e_idx'),
        ),
        migrations.AddIndex(
            model_name='organizationmembership',
            index=models.Index(
                fields=['organization'],
                name='organization_membe_organiz_0a1b2c_idx',
            ),
        ),
        migrations.AddIndex(
            model_name='organizationmembership',
            index=models.Index(fields=['role'], name='organization_membe_role_3d4e5f_idx'),
        ),
        migrations.RunPython(migrate_user_org_to_memberships, noop_reverse),
    ]
