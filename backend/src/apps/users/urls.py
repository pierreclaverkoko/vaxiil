from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView, TokenVerifyView

from . import views

urlpatterns = [
    path('register/', views.register, name='register'),
    path('login/', views.login_view, name='login'),
    path('google/', views.google_auth, name='google_auth'),
    path('avatar/', views.upload_avatar, name='upload_avatar'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('token/verify/', TokenVerifyView.as_view(), name='token_verify'),
    path('logout/', views.logout_view, name='logout'),
    path('profile/', views.profile, name='profile'),
    path('verify/', views.submit_verification, name='submit_verification'),
    path('generate-alias/', views.generate_trust_alias, name='generate_trust_alias'),
]
