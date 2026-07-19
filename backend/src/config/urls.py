from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

from src.apps.users.views import LegalDocumentView

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/v1/auth/', include('src.apps.users.urls')),
    path(
        'api/v1/legal/<str:document_type>/',
        LegalDocumentView.as_view(),
        name='legal_document',
    ),
    path('api/v1/finances/', include('src.apps.finances.urls')),
    path('api/v1/organizations/', include('src.apps.organizations.urls')),
    path('api/v1/services/', include('src.apps.services.urls')),
    path('api/v1/bookings/', include('src.apps.bookings.urls')),
    path('api/v1/payments/', include('src.apps.payments.urls')),
    path('api/v1/staff/', include('src.apps.staff.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
