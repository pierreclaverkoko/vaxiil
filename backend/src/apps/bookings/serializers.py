from django.db import transaction
from django_drf_dynamics.serializers.fields import ChoiceEnumField
from rest_framework import serializers

from src.apps.bookings.models import Booking, BookingTimeSlot
from src.apps.organizations.models import CountryAcceptedCurrency
from src.apps.organizations.serializers import (
    OrganizationBriefSerializer,
    UserBriefSerializer,
)
from src.apps.organizations.serializers_geo import CountryAcceptedCurrencySerializer
from src.apps.services.models import Service, ServiceVariantModel


class BookingTimeSlotReadSerializer(serializers.ModelSerializer):
    location_type = ChoiceEnumField()

    class Meta:
        model = BookingTimeSlot
        fields = [
            'id',
            'start_time',
            'end_time',
            'location_type',
            'address',
            'room_details',
            'virtual_meeting_link',
            'notes',
        ]


class BookingTimeSlotWriteSerializer(serializers.ModelSerializer):
    location_type = ChoiceEnumField()

    class Meta:
        model = BookingTimeSlot
        fields = [
            'start_time',
            'end_time',
            'location_type',
            'address',
            'room_details',
            'virtual_meeting_link',
            'notes',
        ]


class ServiceVariantBriefSerializer(serializers.ModelSerializer):
    class Meta:
        model = ServiceVariantModel
        fields = ['id', 'name', 'duration_minutes', 'price']


class ServiceBriefSerializer(serializers.ModelSerializer):
    """Nested on bookings; includes parent category for UI (icon + name)."""

    category = serializers.SerializerMethodField()

    class Meta:
        model = Service
        fields = ['id', 'name', 'category']

    def get_category(self, obj):
        sub = getattr(obj, 'sub_category', None)
        if sub is None:
            return None
        cat = getattr(sub, 'category', None)
        if cat is None:
            return None
        return {
            'id': str(cat.id),
            'name': cat.name,
            'icon': cat.icon or '',
        }


class BookingSerializer(serializers.ModelSerializer):
    status = ChoiceEnumField()
    service = ServiceBriefSerializer(read_only=True)
    organization = OrganizationBriefSerializer(read_only=True)
    practitioner = UserBriefSerializer(read_only=True)
    accepted_currency = CountryAcceptedCurrencySerializer(read_only=True)
    service_variant = ServiceVariantBriefSerializer(read_only=True)
    time_slots = BookingTimeSlotReadSerializer(many=True, read_only=True)

    class Meta:
        model = Booking
        fields = [
            'id',
            'user',
            'service',
            'organization',
            'practitioner',
            'status',
            'practitioner_alias',
            'service_variant',
            'accepted_currency',
            'total_price',
            'special_requests',
            'internal_notes',
            'confirmed_at',
            'completed_at',
            'cancelled_at',
            'cancellation_reason',
            'time_slots',
            'created_at',
            'updated_at',
        ]
        read_only_fields = fields


class BookingCreateSerializer(serializers.ModelSerializer):
    time_slots = BookingTimeSlotWriteSerializer(many=True)
    service_variant = serializers.PrimaryKeyRelatedField(
        queryset=ServiceVariantModel.objects.filter(
            deleted_at__isnull=True,
            is_active=True,
        ),
        required=False,
        allow_null=True,
    )
    accepted_currency = serializers.PrimaryKeyRelatedField(
        queryset=CountryAcceptedCurrency.objects.filter(
            is_active=True,
            deleted_at__isnull=True,
        ),
        required=False,
        allow_null=True,
    )
    status = ChoiceEnumField(required=False)

    class Meta:
        model = Booking
        fields = [
            'service',
            'practitioner',
            'status',
            'practitioner_alias',
            'service_variant',
            'accepted_currency',
            'total_price',
            'special_requests',
            'time_slots',
        ]

    def validate(self, attrs):
        service = attrs['service']
        org = service.organization
        variant = attrs.get('service_variant')
        if variant and variant.service_id != service.id:
            raise serializers.ValidationError(
                {'service_variant': 'Variant does not belong to this service.'}
            )
        n_variants = ServiceVariantModel.objects.filter(
            service=service,
            is_active=True,
            deleted_at__isnull=True,
        ).count()
        if n_variants >= 2 and variant is None:
            raise serializers.ValidationError(
                {'service_variant': 'Select an option when the service has multiple variants.'}
            )
        cac = attrs.get('accepted_currency')
        if cac and cac.country_id != org.country_id:
            raise serializers.ValidationError(
                {'accepted_currency': 'Currency must match the organization country.'}
            )
        return attrs

    @transaction.atomic
    def create(self, validated_data):
        slots = validated_data.pop('time_slots')
        user = self.context['request'].user
        validated_data['user'] = user
        service = validated_data['service']
        org = service.organization
        validated_data['organization'] = org
        if not validated_data.get('accepted_currency'):
            if service.accepted_currency_id:
                validated_data['accepted_currency'] = service.accepted_currency
            elif org.default_currency_id:
                validated_data['accepted_currency'] = org.default_currency
        if validated_data.get('status') is None:
            validated_data['status'] = Booking.BookingStatus.REQUESTED
        booking = Booking.objects.create(**validated_data)
        for row in slots:
            BookingTimeSlot.objects.create(booking=booking, **row)
        return booking


class BookingCancelSerializer(serializers.Serializer):
    reason = serializers.CharField(required=False, allow_blank=True, default='')
