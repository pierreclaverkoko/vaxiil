from .base import *

DEBUG = True

DATABASES = {
    'default': {
        'ENGINE': 'django.contrib.gis.db.backends.postgis',
        'NAME': config('TEST_DB_NAME', default='test_vaxiil'),
        'USER': config('TEST_DB_USER', default='postgres'),
        'PASSWORD': config('TEST_DB_PASSWORD', default='postgres'),
        'HOST': config('TEST_DB_HOST', default='localhost'),
        'PORT': config('TEST_DB_PORT', default='5432'),
    }
}

SECRET_KEY = 'test-secret-key-for-testing-only'

EMAIL_BACKEND = 'django.core.mail.backends.locmem.EmailBackend'

# Existing suite creates users without email_verified_at; gate is covered in
# dedicated email-verification tests with EMAIL_VERIFICATION_REQUIRED=True.
EMAIL_VERIFICATION_REQUIRED = False

CELERY_TASK_ALWAYS_EAGER = True
CELERY_TASK_EAGER_PROPAGATES = True

STRIPE_PUBLISHABLE_KEY = 'pk_test_placeholder'
STRIPE_SECRET_KEY = 'sk_test_placeholder'
STRIPE_WEBHOOK_SECRET = 'whsec_test_placeholder'

TURNSTILE_SECRET = 'test-turnstile-secret'

MAINMONEY_API_BASE = 'https://api.mainmoney.net/api/v2'
MAINMONEY_CLIENT_ID = 'mm_test_placeholder'
MAINMONEY_CLIENT_SECRET = 'mm_test_secret_placeholder'
MAINMONEY_WEBHOOK_SIGNING_SECRET = 'whsec_mainmoney_test'
PAYMENT_REDIRECT_BASE_URL = 'http://localhost:3000'

SUMSUB_APP_TOKEN = 'sumsub_app_token_test'
SUMSUB_SECRET_KEY = 'sumsub_secret_key_test'
SUMSUB_BASE_URL = 'https://api.sumsub.com'
SUMSUB_LEVEL_NAME = 'basic-kyc-level'
SUMSUB_WEBHOOK_SECRET = 'whsec_sumsub_test'
SUMSUB_CUSTOMIZATION_NAME = 'vaxiil-web'
SUMSUB_SEND_PERSONAL_DATA = False
SUMSUB_REDIRECT_SIGN_KEY = 'sumsub_redirect_sign_key_test_32b'
SUMSUB_WEB_SUCCESS_URL = 'http://localhost:4200/profile/verify/return?status=ok'
SUMSUB_WEB_REJECT_URL = 'http://localhost:4200/profile/verify/return?status=reject'
