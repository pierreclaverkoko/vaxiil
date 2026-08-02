from decimal import Decimal

from django.core.validators import MaxValueValidator, MinValueValidator
from django.utils.translation import gettext as _
from django_drf_dynamics.serializers.fields import ChoiceEnumField
from rest_framework import serializers

from src.apps.core.fields import ChoiceValueField, choice_enum_dict
from src.apps.finances.models import (
    CategoryPlatformFee,
    CurrencyFxRate,
    PlatformFeeEntry,
    PlatformSettings,
    SettlementRequest,
)
from src.apps.organizations.models import Organization, OrganizationSettings
from src.apps.payments.models import PaymentTransaction
from src.apps.services.models import ServiceCategory, ServiceFeature, ServiceSubCategory
from src.apps.users.models import User


def _file_url(file_field, request):
    if not file_field:
        return None
    url = file_field.url
    if request is not None:
        return request.build_absolute_uri(url)
    return url


class StaffRejectSerializer(serializers.Serializer):
    reason = serializers.CharField(required=False, allow_blank=True, default='')


class StaffUserVerificationSerializer(serializers.ModelSerializer):
    verification_status = ChoiceEnumField()
    role = ChoiceEnumField()
    id_document_url = serializers.SerializerMethodField()
    selfie_document_url = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id',
            'email',
            'username',
            'first_name',
            'last_name',
            'phone',
            'role',
            'verification_status',
            'is_trusted',
            'rejection_reason',
            'verified_at',
            'id_document_url',
            'selfie_document_url',
            'created_at',
            'updated_at',
        ]

    def get_id_document_url(self, obj):
        return _file_url(obj.id_document, self.context.get('request'))

    def get_selfie_document_url(self, obj):
        return _file_url(obj.selfie_document, self.context.get('request'))


class StaffOrganizationVerificationSerializer(serializers.ModelSerializer):
    verification_status = ChoiceEnumField()
    type_name = serializers.CharField(source='type.display_name', read_only=True)
    business_license_document_url = serializers.SerializerMethodField()
    id_document_url = serializers.SerializerMethodField()
    logo_url = serializers.SerializerMethodField()

    class Meta:
        model = Organization
        fields = [
            'id',
            'name',
            'email',
            'phone',
            'type_name',
            'verification_status',
            'business_license_number',
            'tax_id',
            'rejection_reason',
            'verified_at',
            'kyb_submitted_at',
            'business_license_document_url',
            'id_document_url',
            'logo_url',
            'created_at',
            'updated_at',
        ]

    def get_business_license_document_url(self, obj):
        return _file_url(obj.business_license_document, self.context.get('request'))

    def get_id_document_url(self, obj):
        return _file_url(obj.id_document, self.context.get('request'))

    def get_logo_url(self, obj):
        return _file_url(obj.logo, self.context.get('request'))


class StaffServiceCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = ServiceCategory
        fields = [
            'id',
            'name',
            'description',
            'icon',
            'is_active',
            'sort_order',
        ]


class StaffServiceSubCategorySerializer(serializers.ModelSerializer):
    category = serializers.PrimaryKeyRelatedField(
        queryset=ServiceCategory.objects.all(),
    )
    category_name = serializers.CharField(source='category.name', read_only=True)

    class Meta:
        model = ServiceSubCategory
        fields = [
            'id',
            'name',
            'category',
            'category_name',
            'description',
            'is_active',
            'sort_order',
        ]


class StaffServiceFeatureSerializer(serializers.ModelSerializer):
    feature_type = ChoiceValueField(
        choices=ServiceFeature.ServiceFeatureType.choices,
    )

    class Meta:
        model = ServiceFeature
        fields = [
            'id',
            'name',
            'feature_type',
            'description',
            'icon',
        ]

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['feature_type'] = choice_enum_dict(instance, 'feature_type')
        return data


class StaffPaymentTransactionSerializer(serializers.ModelSerializer):
    status = ChoiceEnumField()
    kind = ChoiceEnumField()
    provider_code = serializers.CharField(
        source='payment_provider.code',
        read_only=True,
    )
    currency_code = serializers.CharField(source='currency.code', read_only=True)
    booking = serializers.UUIDField(source='booking_id', read_only=True)
    user_email = serializers.SerializerMethodField()

    class Meta:
        model = PaymentTransaction
        fields = [
            'id',
            'booking',
            'user_email',
            'provider_code',
            'amount',
            'currency_code',
            'kind',
            'status',
            'client_reference',
            'provider_reference',
            'created_at',
            'updated_at',
        ]

    def get_user_email(self, obj):
        if obj.user_id and obj.user:
            return obj.user.email
        return None


def require_rejection_reason(reason: str) -> str:
    text = (reason or '').strip()
    if not text:
        raise serializers.ValidationError(
            {'reason': _('A rejection reason is required.')}
        )
    return text


class StaffPlatformSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlatformSettings
        fields = [
            'platform_fee_rate',
            'user_inscription_fee_usd',
            'business_annual_fee_usd',
            'settlement_minimum_usd',
            'updated_at',
        ]
        read_only_fields = ['updated_at']

    def validate_platform_fee_rate(self, value):
        if value is None:
            raise serializers.ValidationError(_('Rate is required.'))
        return Decimal(value).quantize(Decimal('0.01'))

    def _usd(self, value):
        return Decimal(value).quantize(Decimal('0.01'))

    def validate_user_inscription_fee_usd(self, value):
        return self._usd(value)

    def validate_business_annual_fee_usd(self, value):
        return self._usd(value)

    def validate_settlement_minimum_usd(self, value):
        v = self._usd(value)
        if v <= 0:
            raise serializers.ValidationError(_('Settlement minimum must be positive.'))
        return v


class StaffCurrencyFxRateSerializer(serializers.ModelSerializer):
    from_currency_code = serializers.CharField(required=False, allow_blank=True)
    to_currency_code = serializers.CharField(required=False, allow_blank=True)

    class Meta:
        model = CurrencyFxRate
        fields = [
            'id',
            'from_currency',
            'to_currency',
            'from_currency_code',
            'to_currency_code',
            'rate',
            'effective_at',
            'created_at',
        ]
        read_only_fields = ['id', 'created_at']
        extra_kwargs = {
            'from_currency': {'required': False},
            'to_currency': {'required': False},
        }

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['from_currency_code'] = instance.from_currency.code
        data['to_currency_code'] = instance.to_currency.code
        return data

    def create(self, validated_data):
        from src.apps.finances.models import Currency

        from_code = (validated_data.pop('from_currency_code', None) or 'USD').strip().upper()
        to_code = (validated_data.pop('to_currency_code', None) or '').strip().upper()
        from_currency = validated_data.pop('from_currency', None)
        to_currency = validated_data.pop('to_currency', None)
        if from_currency is None:
            from_currency = Currency.objects.filter(code__iexact=from_code).first()
            if not from_currency:
                raise serializers.ValidationError(
                    {'from_currency_code': _('Unknown currency.')}
                )
        if to_currency is None:
            if not to_code:
                raise serializers.ValidationError(
                    {'to_currency_code': _('This field is required.')}
                )
            to_currency = Currency.objects.filter(code__iexact=to_code).first()
            if not to_currency:
                raise serializers.ValidationError(
                    {'to_currency_code': _('Unknown currency.')}
                )
        return CurrencyFxRate.objects.create(
            from_currency=from_currency,
            to_currency=to_currency,
            **validated_data,
        )


class StaffSettlementRequestSerializer(serializers.ModelSerializer):
    status = ChoiceEnumField()
    currency_code = serializers.CharField(source='currency.code', read_only=True)
    organization_name = serializers.CharField(source='organization.name', read_only=True)
    confirmation_image_url = serializers.SerializerMethodField()

    class Meta:
        model = SettlementRequest
        fields = [
            'id',
            'organization',
            'organization_name',
            'amount',
            'currency',
            'currency_code',
            'status',
            'method_code',
            'destination_snapshot',
            'staff_note',
            'confirmation_image_url',
            'created_at',
            'processed_at',
        ]
        read_only_fields = fields

    def get_confirmation_image_url(self, obj):
        return _file_url(obj.confirmation_image, self.context.get('request'))


class StaffCategoryPlatformFeeSerializer(serializers.ModelSerializer):
    category = serializers.PrimaryKeyRelatedField(
        queryset=ServiceCategory.objects.filter(deleted_at__isnull=True),
    )
    category_name = serializers.CharField(source='category.name', read_only=True)

    class Meta:
        model = CategoryPlatformFee
        fields = [
            'id',
            'category',
            'category_name',
            'rate',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'category_name', 'created_at', 'updated_at']


class StaffOrganizationFeeSettingsSerializer(serializers.Serializer):
    platform_fee_rate = serializers.DecimalField(
        max_digits=5,
        decimal_places=2,
        required=False,
        allow_null=True,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
    )
    platform_fee_payer = serializers.ChoiceField(
        choices=OrganizationSettings.PlatformFeePayer.choices,
        required=False,
    )
    clear_rate_override = serializers.BooleanField(required=False, default=False)

    def update(self, instance: OrganizationSettings, validated_data):
        if validated_data.get('clear_rate_override'):
            instance.platform_fee_rate = None
        elif 'platform_fee_rate' in validated_data:
            instance.platform_fee_rate = validated_data['platform_fee_rate']
        if 'platform_fee_payer' in validated_data:
            instance.platform_fee_payer = validated_data['platform_fee_payer']
        instance.save()
        return instance

    def to_representation(self, instance: OrganizationSettings):
        return {
            'organization_id': str(instance.organization_id),
            'platform_fee_rate': (
                str(instance.platform_fee_rate)
                if instance.platform_fee_rate is not None
                else None
            ),
            'platform_fee_payer': {
                'value': instance.platform_fee_payer,
                'title': instance.get_platform_fee_payer_display(),
                'css': instance.get_platform_fee_payer_css(),
            },
            'payout_delay_days': instance.payout_delay_days,
        }


class StaffPlatformFeeEntrySerializer(serializers.ModelSerializer):
    status = ChoiceEnumField()
    payer = ChoiceEnumField()
    source = ChoiceEnumField()
    currency_code = serializers.CharField(source='currency.code', read_only=True)
    organization_name = serializers.CharField(
        source='organization.name',
        read_only=True,
    )
    category_name = serializers.SerializerMethodField()
    booking = serializers.UUIDField(source='booking_id', read_only=True)

    class Meta:
        model = PlatformFeeEntry
        fields = [
            'id',
            'booking',
            'organization',
            'organization_name',
            'category',
            'category_name',
            'amount',
            'currency_code',
            'rate',
            'payer',
            'source',
            'status',
            'created_at',
        ]

    def get_category_name(self, obj):
        if obj.category_id and obj.category:
            return obj.category.name
        return None
