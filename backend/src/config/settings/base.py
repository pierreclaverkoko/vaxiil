import os
from datetime import timedelta
from pathlib import Path

from corsheaders.defaults import default_headers
from decouple import config

BASE_DIR = Path(__file__).resolve().parent.parent.parent.parent

SECRET_KEY = config(
    'SECRET_KEY',
    default='django-insecure-change-me-in-production'
)

DEBUG = config('DEBUG', default=True, cast=bool)

ALLOWED_HOSTS = config(
    'ALLOWED_HOSTS',
    default='localhost,127.0.0.1,10.100.3.7,10.120.159.104',
    cast=lambda v: [s.strip() for s in v.split(',')]
)

DJANGO_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django.contrib.gis',
]

THIRD_PARTY_APPS = [
    'rest_framework',
    'rest_framework_simplejwt',
    'rest_framework_simplejwt.token_blacklist',
    'django_filters',
    'corsheaders',
    'django_extensions',
    'channels',
    'django_drf_dynamics',
    'cities',
]

LOCAL_APPS = [
    'src.apps.finances',
    'src.apps.organizations',
    'src.apps.users',
    'src.apps.services',
    'src.apps.bookings',
    'src.apps.payments',
    'src.apps.notifications',
    'src.apps.messaging',
    'src.apps.staff',
    'src.apps.core',
]

INSTALLED_APPS = DJANGO_APPS + THIRD_PARTY_APPS + LOCAL_APPS

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.locale.LocaleMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'src.apps.core.middleware.SoftDeleteMiddleware',
    'src.apps.core.middleware.CountryScopeMiddleware',
]

ROOT_URLCONF = 'src.config.urls'

# Obscure Django admin path (trailing slash required). Override via env.
DJANGO_ADMIN_PATH = config('DJANGO_ADMIN_PATH', default='vx-mgmt/')
if not DJANGO_ADMIN_PATH.endswith('/'):
    DJANGO_ADMIN_PATH = f'{DJANGO_ADMIN_PATH}/'


TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'src.config.wsgi.application'
ASGI_APPLICATION = 'src.config.asgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.contrib.gis.db.backends.postgis',
        'NAME': config('DB_NAME', default='vaxiil'),
        'USER': config('DB_USER', default='postgres'),
        'PASSWORD': config('DB_PASSWORD', default='postgres'),
        'HOST': config('DB_HOST', default='localhost'),
        'PORT': config('DB_PORT', default='5432'),
    }
}

AUTH_USER_MODEL = 'users.User'

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': (
            'django.contrib.auth.password_validation.'
            'UserAttributeSimilarityValidator'
        ),
    },
    {
        'NAME': (
            'django.contrib.auth.password_validation.'
            'MinimumLengthValidator'
        ),
    },
    {
        'NAME': (
            'django.contrib.auth.password_validation.'
            'CommonPasswordValidator'
        ),
    },
    {
        'NAME': (
            'django.contrib.auth.password_validation.'
            'NumericPasswordValidator'
        ),
    },
]

LANGUAGE_CODE = 'en'
LANGUAGES = [
    ('en', 'English'),
    ('fr', 'French'),
]
LOCALE_PATHS = [BASE_DIR / 'locale']
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_DIRS = [BASE_DIR / 'static']

MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

SITE_URL = config('SITE_URL', default='https://vaxiiltropbien.com')
# Absolute logo for HTML emails (defaults to Angular public asset on SITE_URL).
EMAIL_LOGO_URL = config('EMAIL_LOGO_URL', default='')
EMAIL_LOGO_HOST = config('EMAIL_LOGO_HOST', default='https://api.vaxiiltropbien.com')

# settings.py using Resend SMTP

EMAIL_BACKEND = config('EMAIL_BACKEND', default='django.core.mail.backends.smtp.EmailBackend')
EMAIL_HOST = config('EMAIL_HOST', default='smtp.resend.com')
EMAIL_PORT = config('EMAIL_PORT', default=587, cast=int)
EMAIL_USE_TLS = config('EMAIL_USE_TLS', default=True, cast=bool)
EMAIL_HOST_USER = config('EMAIL_HOST_USER', default='')
EMAIL_HOST_PASSWORD = config('EMAIL_HOST_PASSWORD', default='')

DEFAULT_FROM_EMAIL = config('DEFAULT_FROM_EMAIL', default='Vaxiil <send@vaxiiltropbien.com>')

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

AUTH_USER_MODEL = 'users.User'

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
        'src.apps.users.permissions.IsEmailVerified',
    ],
    'DEFAULT_PAGINATION_CLASS': (
        'rest_framework.pagination.PageNumberPagination'
    ),
    'PAGE_SIZE': 20,
    'DEFAULT_FILTER_BACKENDS': [
        'django_filters.rest_framework.DjangoFilterBackend',
        'rest_framework.filters.SearchFilter',
        'rest_framework.filters.OrderingFilter',
    ],
}

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(days=1),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': False,
    'BLACKLIST_AFTER_ROTATION': False,
}

CORS_ALLOWED_ORIGINS = config(
    'CORS_ALLOWED_ORIGINS',
    default=(
        'http://localhost:3000,http://127.0.0.1:3000,'
        'http://localhost:4200,http://127.0.0.1:4200,'
        'http://localhost:8080,http://127.0.0.1:8080,'
        'http://localhost:5000,http://127.0.0.1:5000'
    ),
    cast=lambda v: [s.strip() for s in v.split(',')],
)

CORS_ALLOW_CREDENTIALS = True
CORS_ALLOW_HEADERS = (
    *default_headers,
    'x-country',
    'x-timezone',
)
CORS_EXPOSE_HEADERS = ['X-Resolved-Country']

# Optional MaxMind GeoLite2 directory (Country.mmdb). Empty = skip IP geo.
GEOIP_PATH = config('GEOIP_PATH', default='')
# Optional override for IANA zone.tab (timezone → ISO2). Empty = system/tzdata paths.
TZ_ZONE_TAB_PATH = config('TZ_ZONE_TAB_PATH', default='')

CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels_redis.core.RedisChannelLayer',
        'CONFIG': {
            'hosts': [
                (
                    config('REDIS_HOST', default='localhost'),
                    config('REDIS_PORT', default=6379, cast=int)
                )
            ],
        },
    },
}

CELERY_BROKER_URL = config(
    'CELERY_BROKER_URL',
    default='redis://localhost:6379/1'
)
CELERY_RESULT_BACKEND = config(
    'CELERY_RESULT_BACKEND',
    default='redis://localhost:6379/1'
)
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_TIMEZONE = TIME_ZONE

STRIPE_PUBLISHABLE_KEY = config('STRIPE_PUBLISHABLE_KEY', default='')
STRIPE_SECRET_KEY = config('STRIPE_SECRET_KEY', default='')
STRIPE_WEBHOOK_SECRET = config('STRIPE_WEBHOOK_SECRET', default='')

# Cloudflare Turnstile (guest auth siteverify). Set TURNSTILE_SECRET in the environment.
TURNSTILE_SECRET = config('TURNSTILE_SECRET', default='')

# Mainmoney hosted payment links (legacy; prefer MM Aggregator collect)
MAINMONEY_API_BASE = config(
    'MAINMONEY_API_BASE',
    default='https://api.mainmoney.net/api/v2',
)
MAINMONEY_CLIENT_ID = config('MAINMONEY_CLIENT_ID', default='')
MAINMONEY_CLIENT_SECRET = config('MAINMONEY_CLIENT_SECRET', default='')
MAINMONEY_WEBHOOK_SIGNING_SECRET = config(
    'MAINMONEY_WEBHOOK_SIGNING_SECRET',
    default='',
)
# MM Aggregator merchant API (default collection gateway)
MM_AGGREGATOR_API_BASE = config('MM_AGGREGATOR_API_BASE', default='')
MM_AGGREGATOR_CLIENT_ID = config('MM_AGGREGATOR_CLIENT_ID', default='')
MM_AGGREGATOR_CLIENT_SECRET = config('MM_AGGREGATOR_CLIENT_SECRET', default='')
MM_AGGREGATOR_WEBHOOK_SIGNING_SECRET = config(
    'MM_AGGREGATOR_WEBHOOK_SIGNING_SECRET',
    default='',
)
# Frontend origin for payer return after checkout (no trailing slash).
PAYMENT_REDIRECT_BASE_URL = config(
    'PAYMENT_REDIRECT_BASE_URL',
    default='http://localhost:3000',
)

# Sumsub KYC (see docs/integrations/sumsub.json + docs/integrations/sumsub.md)
SUMSUB_APP_TOKEN = config('SUMSUB_APP_TOKEN', default='')
SUMSUB_SECRET_KEY = config('SUMSUB_SECRET_KEY', default='')
SUMSUB_BASE_URL = config('SUMSUB_BASE_URL', default='https://api.sumsub.com')
SUMSUB_LEVEL_NAME = config('SUMSUB_LEVEL_NAME', default='basic-kyc-level')
SUMSUB_WEBHOOK_SECRET = config('SUMSUB_WEBHOOK_SECRET', default='')
# WebSDK permalink UI customization name (query param on websdkLink).
SUMSUB_CUSTOMIZATION_NAME = config('SUMSUB_CUSTOMIZATION_NAME', default='vaxiil-web')
# When True, include user email/phone as Sumsub applicantIdentifiers on WebSDK links.
SUMSUB_SEND_PERSONAL_DATA = config(
    'SUMSUB_SEND_PERSONAL_DATA',
    default=False,
    cast=bool,
)
# HMAC key for WebSDK redirect JWT (`redirect.signKey` + verify on return).
SUMSUB_REDIRECT_SIGN_KEY = config('SUMSUB_REDIRECT_SIGN_KEY', default='')
# Angular return URLs after WebSDK (no trailing slash on origin).
SUMSUB_WEB_SUCCESS_URL = config(
    'SUMSUB_WEB_SUCCESS_URL',
    default='http://localhost:4200/profile/verify/return?status=ok',
)
SUMSUB_WEB_REJECT_URL = config(
    'SUMSUB_WEB_REJECT_URL',
    default='http://localhost:4200/profile/verify/return?status=reject',
)

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {process:d} {thread:d} {message}',
            'style': '{',
        },
    },
    'handlers': {
        # 'file': {
        #     'level': 'INFO',
        #     'class': 'logging.FileHandler',
        #     'filename': BASE_DIR / 'logs' / 'django.log',
        #     'formatter': 'verbose',
        # },
        'console': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
    },
    'root': {
        'handlers': ['console'],
        'level': 'INFO',
    },
    'loggers': {
        'django.request': {
            'handlers': ['console'],
            'level': 'INFO',
            'propagate': False,
        },
        'src': {
            'handlers': ['console'],
            'level': 'INFO',
            'propagate': False,
        }
    },
}

# django-cities (GeoNames). Ops: after migrate, import countries/cities
# (e.g. `uv run python manage.py cities --import=country,city` with CITIES_FILES below).
# Prefer minimal seed helpers in tests — do not require a full GeoNames dump for CI.
CITIES_FILES = {
    'city': {
        'filenames': ['cities15000.zip', 'cities15000.zip'],
        'urls': [
            'http://download.geonames.org/export/dump/' + '{filename}',
        ],
    },
}
CITIES_LOCALES = ['en', 'und', 'L']
CITIES_POSTAL_CODES = []

