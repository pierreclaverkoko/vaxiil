from django.test import SimpleTestCase, override_settings
from django.template.loader import render_to_string

from src.apps.notifications.email import email_base_context


@override_settings(SITE_URL='https://vaxiiltropbien.com')
class EmailBrandingTests(SimpleTestCase):
    def test_logo_url_uses_frontend_assets_path(self):
        ctx = email_base_context()
        self.assertEqual(ctx['logo_url'], 'https://vaxiiltropbien.com/assets/logo.png')

    def test_html_base_template_embeds_assets_logo(self):
        ctx = email_base_context(
            subject='Test',
            eyebrow='NOTIFICATION',
            headline='Hello',
            greeting='Hi,',
            body='Body text',
        )
        html = render_to_string('email/notification.html', ctx)
        self.assertIn('https://vaxiiltropbien.com/assets/logo.png', html)
        self.assertNotIn('/static/email/logo.png', html)

    @override_settings(EMAIL_LOGO_URL='https://cdn.example.com/brand.png')
    def test_email_logo_url_setting_override(self):
        ctx = email_base_context()
        self.assertEqual(ctx['logo_url'], 'https://cdn.example.com/brand.png')
