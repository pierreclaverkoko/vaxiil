"""Locale catalogs translate choice labels and user-facing API errors."""

from django.test import SimpleTestCase
from django.utils import translation
from django.utils.translation import gettext as _

from src.apps.users.models import User


class ChoiceLabelI18nTests(SimpleTestCase):
    def test_verification_status_title_french(self):
        with translation.override('fr'):
            self.assertEqual(
                str(User.VerificationStatus.PENDING.label),
                'Vérification en attente',
            )

    def test_verification_status_title_english(self):
        with translation.override('en'):
            self.assertEqual(
                str(User.VerificationStatus.PENDING.label),
                'Pending Verification',
            )

    def test_role_title_french(self):
        with translation.override('fr'):
            self.assertEqual(str(User.UserRole.CLIENT.label), 'Client')

    def test_sex_title_french(self):
        with translation.override('fr'):
            self.assertEqual(str(User.Sex.UNDISCLOSED.label), 'Préfère ne pas répondre')


class ApiErrorI18nTests(SimpleTestCase):
    def test_invalid_credentials_french(self):
        with translation.override('fr'):
            self.assertEqual(_('Invalid credentials'), 'Identifiants invalides')

    def test_booking_access_denied_french(self):
        with translation.override('fr'):
            self.assertEqual(
                _('You cannot access this booking.'),
                'Vous ne pouvez pas accéder à cette réservation.',
            )

    def test_future_date_of_birth_french(self):
        with translation.override('fr'):
            self.assertEqual(
                _('Date of birth cannot be in the future.'),
                'La date de naissance ne peut pas être dans le futur.',
            )

    def test_booking_name_sharing_french(self):
        with translation.override('fr'):
            self.assertEqual(
                _('Share your name to book with this organization.'),
                'Partagez votre nom pour réserver auprès de cette organisation.',
            )

    def test_staff_status_gate_french(self):
        with translation.override('fr'):
            self.assertEqual(
                _('This action is not allowed for the current verification status.'),
                "Cette action n'est pas autorisée pour le statut de vérification actuel.",
            )
