from django.db.models.signals import post_migrate
from django.dispatch import receiver
from django.contrib.contenttypes.models import ContentType


@receiver(post_migrate)
def create_default_content_types(sender, **kwargs):
    pass
