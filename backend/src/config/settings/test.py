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

CELERY_TASK_ALWAYS_EAGER = True
CELERY_TASK_EAGER_PROPAGATES = True

STRIPE_PUBLISHABLE_KEY = 'pk_test_placeholder'
STRIPE_SECRET_KEY = 'sk_test_placeholder'
STRIPE_WEBHOOK_SECRET = 'whsec_test_placeholder'

MAINMONEY_API_BASE = 'https://api.mainmoney.net/api/v2'
MAINMONEY_CLIENT_ID = 'mm_test_placeholder'
MAINMONEY_CLIENT_SECRET = 'mm_test_secret_placeholder'
MAINMONEY_WEBHOOK_SIGNING_SECRET = 'whsec_mainmoney_test'
PAYMENT_REDIRECT_BASE_URL = 'http://localhost:3000'
