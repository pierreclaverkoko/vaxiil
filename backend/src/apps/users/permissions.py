from django.conf import settings
from django.utils.translation import gettext_lazy as _
from rest_framework import permissions

from .models import User


class IsEmailVerified(permissions.BasePermission):
    """Require a verified email for authenticated access to business data APIs."""

    message = _('Verify your email to continue.')

    def has_permission(self, request, view):
        if not getattr(settings, 'EMAIL_VERIFICATION_REQUIRED', True):
            return True
        user = request.user
        if not user or not user.is_authenticated:
            return True
        if getattr(view, 'allow_unverified_email', False):
            return True
        return bool(getattr(user, 'email_verified', False))


class IsAdminOrBusinessOwner(permissions.BasePermission):
    def has_permission(self, request, view):
        if not request.user.is_authenticated:
            return False

        return request.user.role in [
            User.UserRole.ADMIN,
            User.UserRole.BUSINESS_OWNER,
        ]


class IsBusinessStaff(permissions.BasePermission):
    def has_permission(self, request, view):
        if not request.user.is_authenticated:
            return False

        return request.user.role in [
            User.UserRole.BUSINESS_OWNER,
            User.UserRole.BUSINESS_STAFF,
        ]


class IsOwnerOrReadOnly(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        
        return obj.user == request.user


class IsVerifiedUser(permissions.BasePermission):
    message = _('Verify your identity to continue. Complete KYC from your profile.')

    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and
            request.user.is_verified
        )


class IsStaffUser(permissions.BasePermission):
    """Platform staff (Django is_staff) for admin review queues."""

    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and request.user.is_staff
        )
