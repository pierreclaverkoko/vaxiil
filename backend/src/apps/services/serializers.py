from django.db import transaction
from django_drf_dynamics.serializers.fields import ChoiceEnumField
from rest_framework import serializers

from src.apps.organizations.models import Country, CountryAcceptedCurrency
from src.apps.organizations.serializers_geo import (
    CountryAcceptedCurrencySerializer,
    CountryBriefSerializer,
)
from src.apps.services.models import (
    Service,
    ServiceCategory,
    ServiceFeature,
    ServiceFeatureMapping,
    ServiceMedia,
    ServiceSubCategory,
    ServiceVariantModel,
)


def _primary_image_url(service, request):
    qs = (
        service.media.filter(media_type=ServiceMedia.ServiceMediaType.IMAGE)
        .order_by('-is_primary', 'sort_order', 'created_at')
    )
    row = qs.first()
    if not row or not row.file:
        return None
    url = row.file.url
    if request is not None:
        return request.build_absolute_uri(url)
    return url


class ServiceCategorySerializer(serializers.ModelSerializer):
    """Active service categories for catalog filters and icons."""

    class Meta:
        model = ServiceCategory
        fields = ['id', 'name', 'description', 'icon', 'sort_order']


class ServiceCategoryBriefSerializer(serializers.ModelSerializer):
    class Meta:
        model = ServiceCategory
        fields = ['id', 'name', 'icon']


class ServiceSubCategoryBriefSerializer(serializers.ModelSerializer):
    category = ServiceCategoryBriefSerializer(read_only=True)

    class Meta:
        model = ServiceSubCategory
        fields = ['id', 'name', 'category']


class ServiceListSerializer(serializers.ModelSerializer):
    organization = serializers.SerializerMethodField()
    sub_category = ServiceSubCategoryBriefSerializer(read_only=True)
    primary_image = serializers.SerializerMethodField()
    accepted_currency = CountryAcceptedCurrencySerializer(read_only=True)

    class Meta:
        model = Service
        fields = [
            'id',
            'name',
            'description',
            'price_min',
            'price_max',
            'accepted_currency',
            'featured',
            'organization',
            'sub_category',
            'primary_image',
        ]

    def get_organization(self, obj):
        return {
            'id': str(obj.organization_id),
            'name': obj.organization.name,
        }

    def get_primary_image(self, obj):
        return _primary_image_url(obj, self.context.get('request'))


class ServiceVariantDetailSerializer(serializers.ModelSerializer):
    duration_type = ChoiceEnumField()

    class Meta:
        model = ServiceVariantModel
        fields = [
            'id',
            'name',
            'duration_minutes',
            'duration_type',
            'price',
            'is_popular',
            'is_active',
        ]


class ServiceFeatureNestedSerializer(serializers.ModelSerializer):
    feature_type = ChoiceEnumField()

    class Meta:
        model = ServiceFeature
        fields = ['id', 'name', 'feature_type', 'description', 'icon']


class ServiceFeatureMappingDetailSerializer(serializers.ModelSerializer):
    feature = ServiceFeatureNestedSerializer(read_only=True)

    class Meta:
        model = ServiceFeatureMapping
        fields = ['id', 'feature', 'is_required']


class ServiceMediaDetailSerializer(serializers.ModelSerializer):
    file = serializers.SerializerMethodField()

    class Meta:
        model = ServiceMedia
        fields = [
            'id',
            'media_type',
            'file',
            'title',
            'description',
            'sort_order',
            'is_primary',
        ]

    def get_file(self, obj):
        if not obj.file:
            return None
        request = self.context.get('request')
        url = obj.file.url
        if request is not None:
            return request.build_absolute_uri(url)
        return url


class ServiceDetailSerializer(serializers.ModelSerializer):
    organization = serializers.SerializerMethodField()
    sub_category = ServiceSubCategoryBriefSerializer(read_only=True)
    availability_type = ChoiceEnumField()
    primary_image = serializers.SerializerMethodField()
    variants = ServiceVariantDetailSerializer(many=True, read_only=True)
    media = ServiceMediaDetailSerializer(many=True, read_only=True)
    feature_mappings = ServiceFeatureMappingDetailSerializer(
        many=True,
        read_only=True,
    )
    accepted_currency = CountryAcceptedCurrencySerializer(read_only=True)
    country = CountryBriefSerializer(read_only=True)

    class Meta:
        model = Service
        fields = [
            'id',
            'name',
            'description',
            'price_min',
            'price_max',
            'accepted_currency',
            'show_location_on_listing',
            'featured',
            'requires_verification',
            'is_active',
            'availability_type',
            'address',
            'city',
            'postal_code',
            'country_text',
            'country',
            'latitude',
            'longitude',
            'max_bookings_per_day',
            'max_bookings_per_time_slot',
            'booking_advance_days',
            'minimum_booking_hours',
            'cancellation_hours',
            'available_start_time',
            'available_end_time',
            'available_days',
            'seasonal_start_date',
            'seasonal_end_date',
            'availability_notes',
            'organization',
            'sub_category',
            'primary_image',
            'variants',
            'media',
            'feature_mappings',
        ]

    def get_organization(self, obj):
        return {
            'id': str(obj.organization_id),
            'name': obj.organization.name,
            'verification_status': {
                'value': obj.organization.verification_status,
                'title': obj.organization.get_verification_status_display(),
                'css': obj.organization.get_verification_status_css(),
            },
        }

    def get_primary_image(self, obj):
        return _primary_image_url(obj, self.context.get('request'))

    def to_representation(self, instance):
        data = super().to_representation(instance)
        if not instance.show_location_on_listing:
            data['address'] = None
            data['city'] = None
            data['postal_code'] = None
            data['country_text'] = None
            data['country'] = None
            data['latitude'] = None
            data['longitude'] = None
        return data


class ServiceVariantWriteSerializer(serializers.ModelSerializer):
    duration_type = ChoiceEnumField()

    class Meta:
        model = ServiceVariantModel
        fields = [
            'name',
            'duration_minutes',
            'duration_type',
            'price',
            'is_popular',
            'is_active',
        ]


class ServiceFeatureMappingWriteSerializer(serializers.Serializer):
    feature = serializers.PrimaryKeyRelatedField(
        queryset=ServiceFeature.objects.all()
    )
    is_required = serializers.BooleanField(default=False)


class ServiceWriteSerializer(serializers.ModelSerializer):
    variants = ServiceVariantWriteSerializer(many=True, required=False)
    feature_mappings = ServiceFeatureMappingWriteSerializer(
        many=True,
        required=False,
    )
    availability_type = ChoiceEnumField()
    accepted_currency = serializers.PrimaryKeyRelatedField(
        queryset=CountryAcceptedCurrency.objects.filter(
            is_active=True,
            deleted_at__isnull=True,
        ),
        required=False,
        allow_null=True,
    )
    country = serializers.PrimaryKeyRelatedField(
        queryset=Country.objects.filter(is_active=True),
        required=False,
        allow_null=True,
    )

    class Meta:
        model = Service
        fields = [
            'name',
            'sub_category',
            'description',
            'price_min',
            'price_max',
            'accepted_currency',
            'show_location_on_listing',
            'featured',
            'is_active',
            'requires_verification',
            'availability_type',
            'address',
            'city',
            'postal_code',
            'country_text',
            'country',
            'latitude',
            'longitude',
            'max_bookings_per_day',
            'max_bookings_per_time_slot',
            'booking_advance_days',
            'minimum_booking_hours',
            'cancellation_hours',
            'available_start_time',
            'available_end_time',
            'available_days',
            'seasonal_start_date',
            'seasonal_end_date',
            'availability_notes',
            'variants',
            'feature_mappings',
        ]

    def validate(self, attrs):
        pmin = attrs.get('price_min')
        pmax = attrs.get('price_max')
        if self.instance is not None:
            if pmin is None:
                pmin = self.instance.price_min
            if pmax is None:
                pmax = self.instance.price_max
        if pmin is not None and pmax is not None and pmin > pmax:
            raise serializers.ValidationError(
                {'price_max': 'Must be greater than or equal to price_min.'}
            )
        org = attrs.get('organization') or (
            self.instance.organization if self.instance else None
        )
        cac = attrs.get('accepted_currency')
        if self.instance is not None and cac is None:
            cac = self.instance.accepted_currency
        if org and cac and cac.country_id != org.country_id:
            raise serializers.ValidationError(
                {'accepted_currency': 'Must match the organization country.'}
            )
        variants_raw = self.initial_data.get('variants')
        if isinstance(variants_raw, list) and len(variants_raw) >= 2:
            for v in variants_raw:
                if not (v or {}).get('name', '').strip():
                    raise serializers.ValidationError(
                        {'variants': 'Each variant must have a name when multiple options exist.'}
                    )
        return attrs

    @transaction.atomic
    def create(self, validated_data):
        variants_data = validated_data.pop('variants', [])
        fm_data = validated_data.pop('feature_mappings', [])
        organization = validated_data.pop('organization')
        if not validated_data.get('accepted_currency') and organization.default_currency_id:
            validated_data['accepted_currency'] = organization.default_currency
        if not validated_data.get('country_id') and organization.country_id:
            validated_data['country'] = organization.country
        service = Service.objects.create(
            organization=organization,
            **validated_data,
        )
        for v in variants_data:
            ServiceVariantModel.objects.create(service=service, **v)
        for row in fm_data:
            ServiceFeatureMapping.objects.create(
                service=service,
                feature=row['feature'],
                is_required=row['is_required'],
            )
        return service

    @transaction.atomic
    def update(self, instance, validated_data):
        variants_data = validated_data.pop('variants', None)
        fm_data = validated_data.pop('feature_mappings', None)
        organization = instance.organization
        if (
            validated_data.get('accepted_currency') is None
            and 'accepted_currency' not in validated_data
            and not instance.accepted_currency_id
            and organization.default_currency_id
        ):
            validated_data['accepted_currency'] = organization.default_currency
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        if variants_data is not None:
            ServiceVariantModel.all_objects.filter(service=instance).delete()
            for v in variants_data:
                ServiceVariantModel.objects.create(service=instance, **v)
        if fm_data is not None:
            ServiceFeatureMapping.all_objects.filter(service=instance).delete()
            for row in fm_data:
                ServiceFeatureMapping.objects.create(
                    service=instance,
                    feature=row['feature'],
                    is_required=row['is_required'],
                )
        return instance
