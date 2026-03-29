from django.urls import path
from rest_framework.routers import DefaultRouter
from . import views

urlpatterns = [
    path('register/', views.register, name='register'),
    path('login/', views.login_view, name='login'),
    path('logout/', views.logout_view, name='logout'),
    path('profile/', views.profile, name='profile'),
    path('verify/', views.submit_verification, name='submit_verification'),
    path('generate-alias/', views.generate_trust_alias, name='generate_trust_alias'),
]
