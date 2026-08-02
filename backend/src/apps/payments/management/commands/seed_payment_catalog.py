from django.core.management.base import BaseCommand

from src.apps.payments.catalog_seed import ensure_default_payment_catalog


class Command(BaseCommand):
    help = 'Seed default PaymentConnector / PaymentMethod catalog and mm_aggregator provider.'

    def handle(self, *args, **options):
        ensure_default_payment_catalog()
        self.stdout.write(self.style.SUCCESS('Payment catalog seed complete.'))
