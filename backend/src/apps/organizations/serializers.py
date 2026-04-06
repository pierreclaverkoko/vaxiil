from django.db import transaction
from django.utils import timezone
from django_drf_dynamics.serializers.fields import ChoiceEnumField
from rest_framework import serializers

from src.apps.organizations.models import (
    Country,
    CountryAcceptedCurrency,
    Organization,
    OrganizationAddress,
    OrganizationMembership,
    OrganizationSettings,
    OrganizationTypeModel,
)
from src.apps.organizations.serializers_geo import (
    CountryAcceptedCurrencySerializer,
    CountryBriefSerializer,
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


class OrganizationAddressSerializer(serializers.ModelSerializer):
    country = CountryBriefSerializer(read_only=True)

    class Meta:
        model = OrganizationAddress
        fields = [
            'id',
            'label',
            'is_primary',
            'address',
            'city',
            'postal_code',
            'country_text',
            'country',
            'latitude',
            'longitude',
        ]
        read_only_fields = fields


class OrganizationSerializer(serializers.ModelSerializer):
    type_display_name = serializers.CharField(source='type.display_name', read_only=True)
    verification_status = ChoiceEnumField()
    country = CountryBriefSerializer(read_only=True)
    default_currency = CountryAcceptedCurrencySerializer(read_only=True)
    addresses = OrganizationAddressSerializer(many=True, read_only=True)
    address = serializers.SerializerMethodField()
    city = serializers.SerializerMethodField()
    postal_code = serializers.SerializerMethodField()
    country_legacy = serializers.SerializerMethodField()
    latitude = serializers.SerializerMethodField()
    longitude = serializers.SerializerMethodField()
    logo = serializers.SerializerMethodField()

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
            'logo',
            'country',
            'default_currency',
            'addresses',
            'address',
            'city',
            'postal_code',
            'country_legacy',
            'latitude',
            'longitude',
            'verification_status',
            'rejection_reason',
            'kyb_submitted_at',
            'business_license_number',
            'tax_id',
            'is_active',
            'accepts_bookings',
            'requires_prepayment',
            'created_at',
            'updated_at',
        ]
        read_only_fields = fields

    def _pa(self, obj):
        return obj.primary_address()

    def get_address(self, obj):
        a = self._pa(obj)
        return a.address if a else ''

    def get_city(self, obj):
        a = self._pa(obj)
        return a.city if a else ''

    def get_postal_code(self, obj):
        a = self._pa(obj)
        return a.postal_code if a else ''

    def get_country_legacy(self, obj):
        a = self._pa(obj)
        return a.country_text if a else ''

    def get_latitude(self, obj):
        a = self._pa(obj)
        return a.latitude if a else None

    def get_longitude(self, obj):
        a = self._pa(obj)
        return a.longitude if a else None

    def get_logo(self, obj):
        if not obj.logo:
            return None
        request = self.context.get('request')
        url = obj.logo.url
        if request:
            return request.build_absolute_uri(url)
        return url


class OrganizationDiscoverySerializer(serializers.ModelSerializer):
    """Verified organizations for client home / discovery (no membership required)."""

    city = serializers.SerializerMethodField()
    logo = serializers.SerializerMethodField()
    description = serializers.SerializerMethodField()

    class Meta:
        model = Organization
        fields = ['id', 'name', 'description', 'city', 'logo']

    def get_description(self, obj):
        text = (obj.description or '').strip()
        if len(text) <= 200:
            return text
        return f'{text[:197]}...'

    def _primary_address(self, obj):
        return obj.primary_address()

    def get_city(self, obj):
        a = self._primary_address(obj)
        return a.city if a else ''

    def get_logo(self, obj):
        if not obj.logo:
            return None
        request = self.context.get('request')
        url = obj.logo.url
        if request:
            return request.build_absolute_uri(url)
        return url


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
        instance.kyb_submitted_at = timezone.now()
        return super().update(instance, validated_data)


class OrganizationCreateSerializer(serializers.ModelSerializer):
    type = serializers.PrimaryKeyRelatedField(
        queryset=OrganizationTypeModel.objects.filter(is_active=True)
    )
    country = serializers.PrimaryKeyRelatedField(
        queryset=Country.objects.filter(is_active=True),
    )
    default_currency = serializers.PrimaryKeyRelatedField(
        queryset=CountryAcceptedCurrency.objects.filter(
            is_active=True,
            deleted_at__isnull=True,
        ),
        required=False,
        allow_null=True,
    )
    address = serializers.CharField(write_only=True, max_length=255)
    city = serializers.CharField(write_only=True, max_length=100)
    postal_code = serializers.CharField(write_only=True, max_length=20)
    country_text = serializers.CharField(
        write_only=True,
        max_length=100,
        required=False,
        allow_blank=True,
        default='',
    )
    logo = serializers.ImageField(required=True)

    class Meta:
        model = Organization
        fields = [
            'type',
            'name',
            'email',
            'phone',
            'description',
            'website',
            'logo',
            'country',
            'default_currency',
            'address',
            'city',
            'postal_code',
            'country_text',
        ]

    def validate(self, attrs):
        cac = attrs.get('default_currency')
        country = attrs.get('country')
        if cac and country and cac.country_id != country.id:
            raise serializers.ValidationError(
                {'default_currency': 'Must be an accepted currency for the country.'}
            )
        return attrs

    def to_representation(self, instance):
        return OrganizationSerializer(instance, context=self.context).data

    def create(self, validated_data):
        request = self.context['request']
        user = request.user
        address = validated_data.pop('address')
        city = validated_data.pop('city')
        postal_code = validated_data.pop('postal_code')
        country_text = validated_data.pop('country_text', '')
        default_currency = validated_data.pop('default_currency', None)
        country = validated_data['country']
        if default_currency is None:
            default_currency = (
                CountryAcceptedCurrency.objects.filter(
                    country=country,
                    is_default=True,
                    is_active=True,
                    deleted_at__isnull=True,
                )
                .first()
            )
        with transaction.atomic():
            org = Organization.objects.create(
                default_currency=default_currency,
                **validated_data,
            )
            OrganizationAddress.objects.create(
                organization=org,
                address=address,
                city=city,
                postal_code=postal_code,
                country_text=country_text,
                country=country,
                is_primary=True,
            )
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
    country = serializers.PrimaryKeyRelatedField(
        queryset=Country.objects.filter(is_active=True),
        required=False,
    )
    default_currency = serializers.PrimaryKeyRelatedField(
        queryset=CountryAcceptedCurrency.objects.filter(
            is_active=True,
            deleted_at__isnull=True,
        ),
        required=False,
        allow_null=True,
    )
    logo = serializers.ImageField(required=False, allow_null=True)

    class Meta:
        model = Organization
        fields = [
            'name',
            'description',
            'phone',
            'email',
            'website',
            'logo',
            'country',
            'default_currency',
            'is_active',
            'accepts_bookings',
            'requires_prepayment',
        ]

    def validate(self, attrs):
        country = attrs.get('country', self.instance.country if self.instance else None)
        cac = attrs.get('default_currency', getattr(self.instance, 'default_currency', None))
        if 'default_currency' in attrs:
            cac = attrs['default_currency']
        if cac and country and cac.country_id != country.id:
            raise serializers.ValidationError(
                {'default_currency': 'Must be an accepted currency for the organization country.'}
            )
        return attrs

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
