from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, UserRole, VerificationStatus


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = [
        'email', 'username', 'first_name', 'last_name',
        'role', 'verification_status', 'trust_alias',
        'is_trusted', 'is_active', 'created_at'
    ]
    
    list_filter = [
        'role', 'verification_status', 'is_trusted',
        'is_active', 'created_at'
    ]
    
    search_fields = ['email', 'username', 'first_name', 'last_name', 'trust_alias']
    
    ordering = ['-created_at']
    
    fieldsets = (
        (None, {
            'fields': ('email', 'username', 'password')
        }),
        ('Personal info', {
            'fields': ('first_name', 'last_name', 'phone')
        }),
        ('Role & Organization', {
            'fields': ('role', 'organization')
        }),
        ('Verification', {
            'fields': (
                'verification_status', 'trust_alias', 'is_trusted',
                'id_document', 'selfie_document',
                'verified_at', 'verified_by', 'rejection_reason'
            )
        }),
        ('Privacy Settings', {
            'fields': ('show_real_name', 'show_phone_number')
        }),
        ('Permissions', {
            'fields': (
                'is_active', 'is_staff', 'is_superuser',
                'groups', 'user_permissions'
            )
        }),
    )
    
    readonly_fields = [
        'trust_alias', 'verified_at', 'verified_by',
        'created_at', 'updated_at'
    ]
    
    actions = ['approve_verification', 'reject_verification']
    
    def approve_verification(self, request, queryset):
        queryset.update(
            verification_status=VerificationStatus.VERIFIED,
            is_trusted=True,
            verified_by=request.user
        )
    approve_verification.short_description = 'Approve selected users'
    
    def reject_verification(self, request, queryset):
        queryset.update(
            verification_status=VerificationStatus.REJECTED,
            is_trusted=False
        )
    reject_verification.short_description = 'Reject selected users'
