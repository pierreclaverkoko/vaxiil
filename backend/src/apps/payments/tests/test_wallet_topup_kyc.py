from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from src.apps.finances.models import Currency
from src.apps.payments.catalog import PaymentConnector, PaymentMethod
from src.apps.payments.models import PaymentProvider
from src.apps.test_helpers.geo import seed_us_country_and_currency

User = get_user_model()


@override_settings(EMAIL_VERIFICATION_REQUIRED=False)
class WalletTopUpKycTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        seed_us_country_and_currency()
        cls.currency, _ = Currency.objects.get_or_create(
            code='USD',
            defaults={'name': 'US Dollar', 'symbol': '$', 'is_active': True},
        )
        cls.currency.is_active = True
        cls.currency.save(update_fields=['is_active'])
        cls.provider, _ = PaymentProvider.objects.get_or_create(
            code='mm_aggregator',
            defaults={
                'provider_type': PaymentProvider.ProviderType.OTHER,
                'display_name': 'Secure payment',
                'is_active': True,
                'config': {},
            },
        )
        cls.provider.is_active = True
        cls.provider.save(update_fields=['is_active'])
        connector, _ = PaymentConnector.objects.get_or_create(
            code='mm_aggregator',
            defaults={
                'name': 'MM Aggregator',
                'connector_type': PaymentConnector.ConnectorType.AGGREGATOR,
                'adapter_key': 'mm_aggregator',
                'is_active': True,
            },
        )
        cls.method = PaymentMethod.objects.create(
            code='MOMO_KYC_TEST',
            name='Test MoMo',
            connector=connector,
            method_type=PaymentMethod.MethodType.MOBILE_MONEY,
            account_regex=r'^\+?[0-9]{8,15}$',
            config={
                'destination_fields': ['phone_number'],
                'provider_code': 'MPESA_KE',
            },
            is_active=True,
            supported_operations=[
                PaymentMethod.Operation.WALLET_FUND,
            ],
        )

    def setUp(self):
        self.api = APIClient()
        self.user = User.objects.create_user(
            email='wallet@example.com',
            username='wallet',
            password='secret123',
            verification_status=User.VerificationStatus.PENDING,
        )
        self.user.email_verified_at = timezone.now()
        self.user.save(update_fields=['email_verified_at'])

    def _auth(self, user):
        token = RefreshToken.for_user(user)
        self.api.credentials(HTTP_AUTHORIZATION=f'Bearer {token.access_token}')

    def test_unverified_user_cannot_top_up(self):
        self._auth(self.user)
        res = self.api.post(
            '/api/v1/payments/wallet/top-up/',
            {
                'amount': '10.00',
                'currency_code': 'USD',
                'payment_method_id': str(self.method.id),
                'account_identifier': '243900000000',
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    @patch('src.apps.payments.services.payment_links.get_adapter_for_provider')
    def test_verified_user_can_start_top_up(self, mock_adapter):
        self.user.verification_status = User.VerificationStatus.VERIFIED
        self.user.save(update_fields=['verification_status'])
        self._auth(self.user)

        class _Result:
            success = True
            status = 'pending'
            message = 'ok'
            response_body = {}
            transaction_id = 'tx1'
            status_code = None
            provider_reference = 'pref-1'
            internal_reference = 'iref-1'

        mock_adapter.return_value.collect.return_value = _Result()
        res = self.api.post(
            '/api/v1/payments/wallet/top-up/',
            {
                'amount': '10.00',
                'currency_code': 'USD',
                'payment_method_id': str(self.method.id),
                'account_identifier': '243900000000',
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
