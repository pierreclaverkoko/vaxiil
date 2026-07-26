from django.urls import include, path
from rest_framework.routers import DefaultRouter

from src.apps.messaging.views import ConversationViewSet, InviteViewSet

router = DefaultRouter()
router.register('invites', InviteViewSet, basename='messaging-invite')
router.register('conversations', ConversationViewSet, basename='messaging-conversation')

urlpatterns = [
    path('', include(router.urls)),
]
