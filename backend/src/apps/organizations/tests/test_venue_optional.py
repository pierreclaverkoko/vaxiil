from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from src.apps.bookings.location_types import has_usable_venue_address
from src.apps.organizations.models import Organization, OrganizationMembership, OrganizationTypeModel
from src.apps.test_helpers.geo import create_org_address, seed_us_country_and_currency

User = get_user_model()


@override_settings(EMAIL_VERIFICATION_REQUIRED=False)
class OptionalVenueAddressTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.user = User.objects.create_user(
            email='owner@example.com',
            username='owner',
            password='secret123',
            role=User.UserRole.BUSINESS_OWNER,
        )
        cls.user.email_verified_at = timezone.now()
        cls.user.save(update_fields=['email_verified_at'])
        cls.org_type = OrganizationTypeModel.objects.create(name='spa', display_name='Spa')
        cls.country, cls.cac = seed_us_country_and_currency()

    def setUp(self):
        self.api = APIClient()
        token = RefreshToken.for_user(self.user)
        self.api.credentials(HTTP_AUTHORIZATION=f'Bearer {token.access_token}')

    def test_has_usable_venue_requires_street_and_city(self):
        org = Organization.objects.create(
            name='No Venue',
            type=self.org_type,
            email='novenue@example.com',
            country=self.country,
            default_currency=self.cac,
        )
        self.assertFalse(has_usable_venue_address(org))
        create_org_address(org, self.country)
        self.assertTrue(has_usable_venue_address(org))

    def test_delete_last_address_strips_office_location_type(self):
        org = Organization.objects.create(
            name='Venue Co',
            type=self.org_type,
            email='venueco@example.com',
            country=self.country,
            default_currency=self.cac,
            accepted_location_types=['O', 'H', 'V'],
            verification_status=Organization.VerificationStatus.VERIFIED,
        )
        addr = create_org_address(org, self.country)
        OrganizationMembership.objects.create(
            user=self.user,
            organization=org,
            role=OrganizationMembership.OrganizationMemberRole.OWNER,
        )
        res = self.api.delete(f'/api/v1/organizations/{org.id}/addresses/{addr.id}/')
        self.assertEqual(res.status_code, status.HTTP_204_NO_CONTENT)
        org.refresh_from_db()
        self.assertFalse(has_usable_venue_address(org))
        self.assertNotIn('O', org.accepted_location_types)
        self.assertIn('H', org.accepted_location_types)

    def test_reject_office_location_type_without_venue(self):
        org = Organization.objects.create(
            name='Remote Co',
            type=self.org_type,
            email='remote@example.com',
            country=self.country,
            default_currency=self.cac,
            accepted_location_types=['H', 'V'],
            verification_status=Organization.VerificationStatus.VERIFIED,
        )
        OrganizationMembership.objects.create(
            user=self.user,
            organization=org,
            role=OrganizationMembership.OrganizationMemberRole.OWNER,
        )
        res = self.api.patch(
            f'/api/v1/organizations/{org.id}/',
            {'accepted_location_types': ['O', 'H']},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('accepted_location_types', res.data)

    def test_org_serializer_exposes_has_venue_address(self):
        org = Organization.objects.create(
            name='Flag Co',
            type=self.org_type,
            email='flag@example.com',
            country=self.country,
            default_currency=self.cac,
            verification_status=Organization.VerificationStatus.VERIFIED,
        )
        OrganizationMembership.objects.create(
            user=self.user,
            organization=org,
            role=OrganizationMembership.OrganizationMemberRole.OWNER,
        )
        res = self.api.get(f'/api/v1/organizations/{org.id}/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertFalse(res.data['has_venue_address'])
        create_org_address(org, self.country)
        res = self.api.get(f'/api/v1/organizations/{org.id}/')
        self.assertTrue(res.data['has_venue_address'])
