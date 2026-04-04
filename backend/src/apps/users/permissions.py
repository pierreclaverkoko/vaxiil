from rest_framework import permissions

from .models import User


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
    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and
            request.user.is_verified
        )
