from django.db import transaction
from django_drf_dynamics.serializers.fields import ChoiceEnumField
from rest_framework import serializers

from src.apps.organizations.models import (
    Organization,
    OrganizationMembership,
    OrganizationSettings,
    OrganizationTypeModel,
)
from src.apps.users.models import User


class OrganizationTypeSerializer(serializers.ModelSerializer):
    """Active organization types for registration dropdowns."""

    class Meta:
        model = OrganizationTypeModel
        fields = ['id', 'name', 'display_name', 'description', 'icon']


class OrganizationMembershipBriefSerializer(serializers.ModelSerializer):
    """User's memberships (profile / org switching)."""

    organization_name = serializers.CharField(
        source='organization.name', read_only=True
    )
    role = ChoiceEnumField()

    class Meta:
        model = OrganizationMembership
        fields = [
            'id',
            'organization',
            'organization_name',
            'role',
        ]
        read_only_fields = fields


class OrganizationSerializer(serializers.ModelSerializer):
    type_display_name = serializers.CharField(source='type.display_name', read_only=True)
    verification_status = ChoiceEnumField()

    class Meta:
        model = Organization
        fields = [
            'id',
            'name',
            'type',
            'type_display_name',
            'description',
            'phone',
            'email',
            'website',
            'address',
            'city',
            'postal_code',
            'country',
            'latitude',
            'longitude',
            'verification_status',
            'rejection_reason',
            'business_license_number',
            'tax_id',
            'is_active',
            'accepts_bookings',
            'requires_prepayment',
            'created_at',
            'updated_at',
        ]
        read_only_fields = fields


class OrganizationSubmitVerificationSerializer(serializers.ModelSerializer):
    """Multipart KYB submission for business documents (sets status to PENDING)."""

    class Meta:
        model = Organization
        fields = [
            'business_license_document',
            'id_document',
            'business_license_number',
            'tax_id',
        ]

    def validate(self, attrs):
        doc = attrs.get('business_license_document')
        id_doc = attrs.get('id_document')
        if not doc:
            raise serializers.ValidationError(
                {'business_license_document': 'This file is required.'}
            )
        if not id_doc:
            raise serializers.ValidationError(
                {'id_document': 'This file is required.'}
            )
        return attrs

    def update(self, instance, validated_data):
        instance.verification_status = Organization.VerificationStatus.PENDING
        instance.rejection_reason = ''
        return super().update(instance, validated_data)


class OrganizationCreateSerializer(serializers.ModelSerializer):
    type = serializers.PrimaryKeyRelatedField(
        queryset=OrganizationTypeModel.objects.filter(is_active=True)
    )

    class Meta:
        model = Organization
        fields = [
            'type',
            'name',
            'email',
            'phone',
            'description',
            'website',
            'address',
            'city',
            'postal_code',
            'country',
        ]

    def to_representation(self, instance):
        return OrganizationSerializer(instance, context=self.context).data

    def create(self, validated_data):
        request = self.context['request']
        user = request.user
        with transaction.atomic():
            org = Organization.objects.create(**validated_data)
            OrganizationSettings.objects.create(organization=org)
            OrganizationMembership.objects.create(
                user=user,
                organization=org,
                role=OrganizationMembership.OrganizationMemberRole.OWNER,
            )
            user.organization = org
            update_fields = ['organization', 'updated_at']
            if user.role == User.UserRole.CLIENT:
                user.role = User.UserRole.BUSINESS_OWNER
                update_fields.append('role')
            user.save(update_fields=update_fields)
        return org


class OrganizationUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Organization
        fields = [
            'name',
            'description',
            'phone',
            'email',
            'website',
            'address',
            'city',
            'postal_code',
            'country',
            'latitude',
            'longitude',
            'is_active',
            'accepts_bookings',
            'requires_prepayment',
        ]

    def validate_email(self, value):
        org = self.instance
        if org and Organization.objects.filter(email=value).exclude(pk=org.pk).exists():
            raise serializers.ValidationError('An organization with this email already exists.')
        return value


class OrganizationTeamMemberSerializer(serializers.ModelSerializer):
    """Team list: one row per membership (role is per-organization)."""

    id = serializers.UUIDField(source='user.id', read_only=True)
    email = serializers.EmailField(source='user.email', read_only=True)
    first_name = serializers.CharField(source='user.first_name', read_only=True)
    last_name = serializers.CharField(source='user.last_name', read_only=True)
    phone = serializers.CharField(source='user.phone', read_only=True)
    role = ChoiceEnumField(choice_field_name='user_role')
    membership_role = ChoiceEnumField(choice_field_name='role')

    class Meta:
        model = OrganizationMembership
        fields = [
            'id',
            'email',
            'first_name',
            'last_name',
            'role',
            'phone',
            'membership_role',
        ]
