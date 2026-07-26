from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView, TokenVerifyView

from . import views

urlpatterns = [
    path(
        'metadata/',
        views.UserAuthViewSet.as_view({'get': 'metadata'}),
        name='auth_metadata',
    ),
    path(
        'accept-legal/',
        views.UserAuthViewSet.as_view({'post': 'accept_legal'}),
        name='accept_legal',
    ),
    path(
        'email/verify/send/',
        views.UserAuthViewSet.as_view({'post': 'email_verify_send'}),
        name='email_verify_send',
    ),
    path(
        'email/verify/',
        views.UserAuthViewSet.as_view({'post': 'email_verify'}),
        name='email_verify',
    ),
    path(
        'register/',
        views.UserAuthViewSet.as_view({'post': 'register'}),
        name='register',
    ),
    path(
        'login/',
        views.UserAuthViewSet.as_view({'post': 'login'}),
        name='login',
    ),
    path(
        'login/verify-otp/',
        views.UserAuthViewSet.as_view({'post': 'login_verify_otp'}),
        name='login_verify_otp',
    ),
    path(
        'otp/send/',
        views.UserAuthViewSet.as_view({'post': 'otp_send'}),
        name='otp_send',
    ),
    path(
        'password/change/',
        views.UserAuthViewSet.as_view({'post': 'password_change'}),
        name='password_change',
    ),
    path(
        'password/reset/request/',
        views.UserAuthViewSet.as_view({'post': 'password_reset_request'}),
        name='password_reset_request',
    ),
    path(
        'password/reset/confirm/',
        views.UserAuthViewSet.as_view({'post': 'password_reset_confirm'}),
        name='password_reset_confirm',
    ),
    path(
        'google/',
        views.UserAuthViewSet.as_view({'post': 'google_auth'}),
        name='google_auth',
    ),
    path(
        'avatar/',
        views.CurrentUserViewSet.as_view({'post': 'upload_avatar'}),
        name='upload_avatar',
    ),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('token/verify/', TokenVerifyView.as_view(), name='token_verify'),
    path(
        'logout/',
        views.UserAuthViewSet.as_view({'post': 'logout'}),
        name='logout',
    ),
    path(
        'profile/',
        views.CurrentUserViewSet.as_view({'get': 'profile', 'put': 'profile'}),
        name='profile',
    ),
    path(
        'verify/',
        views.CurrentUserViewSet.as_view({'post': 'submit_verification'}),
        name='submit_verification',
    ),
    path(
        'generate-alias/',
        views.CurrentUserViewSet.as_view({'get': 'generate_trust_alias'}),
        name='generate_trust_alias',
    ),
    path(
        'regenerate-alias/',
        views.CurrentUserViewSet.as_view({'post': 'regenerate_trust_alias'}),
        name='regenerate_trust_alias',
    ),
]
