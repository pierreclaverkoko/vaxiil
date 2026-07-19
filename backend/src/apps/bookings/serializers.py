from django.db import transaction
from django.utils.translation import gettext as _
from django_drf_dynamics.serializers.fields import ChoiceEnumField
from rest_framework import serializers

from src.apps.bookings.access import user_is_org_booking_staff
from src.apps.bookings.models import Booking, BookingTimeSlot
from src.apps.bookings.services import AvailabilityService
from src.apps.finances.services.platform_fees import apply_platform_fee_to_booking_data
from src.apps.organizations.models import CountryAcceptedCurrency
from src.apps.organizations.serializers import (
    OrganizationBriefSerializer,
    UserBriefSerializer,
)
from src.apps.organizations.serializers_geo import CountryAcceptedCurrencySerializer
from src.apps.payments.services.refunds import net_captured_for_booking
from src.apps.services.models import Service, ServiceVariantModel


class BookingTimeSlotReadSerializer(serializers.ModelSerializer):
    location_type = ChoiceEnumField()

    class Meta:
        model = BookingTimeSlot
        fields = [
            "id",
            "start_time",
            "end_time",
            "location_type",
            "address",
            "room_details",
            "virtual_meeting_link",
            "notes",
        ]


class BookingTimeSlotWriteSerializer(serializers.ModelSerializer):
    location_type = ChoiceEnumField()

    class Meta:
        model = BookingTimeSlot
        fields = [
            "start_time",
            "end_time",
            "location_type",
            "address",
            "room_details",
            "virtual_meeting_link",
            "notes",
        ]


class ServiceVariantBriefSerializer(serializers.ModelSerializer):
    class Meta:
        model = ServiceVariantModel
        fields = ["id", "name", "duration_minutes", "price"]


class ServiceBriefSerializer(serializers.ModelSerializer):
    """Nested on bookings; includes parent category for UI (icon + name)."""

    category = serializers.SerializerMethodField()

    class Meta:
        model = Service
        fields = ["id", "name", "category"]

    def get_category(self, obj):
        sub = getattr(obj, "sub_category", None)
        if sub is None:
            return None
        cat = getattr(sub, "category", None)
        if cat is None:
            return None
        return {
            "id": str(cat.id),
            "name": cat.name,
            "icon": cat.icon or "",
        }


class BookingSerializer(serializers.ModelSerializer):
    status = ChoiceEnumField()
    service = ServiceBriefSerializer(read_only=True)
    organization = OrganizationBriefSerializer(read_only=True)
    practitioner = UserBriefSerializer(read_only=True)
    accepted_currency = CountryAcceptedCurrencySerializer(read_only=True)
    service_variant = ServiceVariantBriefSerializer(read_only=True)
    time_slots = BookingTimeSlotReadSerializer(many=True, read_only=True)
    internal_notes = serializers.SerializerMethodField()
    client = serializers.SerializerMethodField()
    payment_summary = serializers.SerializerMethodField()
    platform_fee_payer = ChoiceEnumField()
    platform_fee_source = ChoiceEnumField()

    class Meta:
        model = Booking
        fields = [
            "id",
            "user",
            "service",
            "organization",
            "practitioner",
            "status",
            "practitioner_alias",
            "service_variant",
            "accepted_currency",
            "base_price",
            "platform_fee_rate",
            "platform_fee_amount",
            "platform_fee_payer",
            "platform_fee_source",
            "total_price",
            "special_requests",
            "internal_notes",
            "confirmed_at",
            "completed_at",
            "cancelled_at",
            "cancellation_reason",
            "time_slots",
            "created_at",
            "updated_at",
            "client",
            "payment_summary",
        ]
        read_only_fields = fields

    def get_internal_notes(self, obj):
        request = self.context.get("request")
        if request and user_is_org_booking_staff(request.user, obj.organization_id):
            return obj.internal_notes
        return ""

    def get_client(self, obj):
        request = self.context.get("request")
        u = obj.user
        is_client = bool(request and request.user.pk == u.pk)
        is_org_staff = bool(request and user_is_org_booking_staff(request.user, obj.organization_id))
        can_see_name = is_client or u.show_real_name or obj.share_name
        can_see_phone = is_client or u.show_phone_number or obj.share_phone
        can_see_email = is_client or u.show_email or obj.share_email
        # Age/sex stay visible to the client and org staff even when name is private.
        can_see_demographics = is_client or is_org_staff
        sex_payload = (
            {
                "value": u.sex,
                "title": u.get_sex_display(),
                "css": u.get_sex_css(),
            }
            if can_see_demographics and u.sex
            else None
        )
        base = {
            "id": str(u.pk),
            "trust_alias": u.trust_alias,
            "age": u.age if can_see_demographics else None,
            "sex": sex_payload,
            "first_name": (u.first_name or "") if can_see_name else None,
            "last_name": (u.last_name or "") if can_see_name else None,
            "phone": (u.phone or "") if can_see_phone else None,
            "email": (u.email or "") if can_see_email else None,
        }
        if not (is_client or is_org_staff):
            base["age"] = None
            base["sex"] = None
            base["first_name"] = None
            base["last_name"] = None
            base["phone"] = None
            base["email"] = None
        return base

    def get_payment_summary(self, obj):
        net, code = net_captured_for_booking(obj)
        return {
            "net_captured": str(net),
            "currency_code": code,
        }


class BookingRescheduleSerializer(serializers.Serializer):
    time_slots = BookingTimeSlotWriteSerializer(many=True)


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
            "service",
            "practitioner",
            "status",
            "practitioner_alias",
            "service_variant",
            "accepted_currency",
            "total_price",
            "special_requests",
            "share_name",
            "share_phone",
            "share_email",
            "time_slots",
        ]
        extra_kwargs = {
            "total_price": {"required": False},
        }

    def validate(self, attrs):
        service = attrs["service"]
        org = service.organization
        request = self.context.get("request")
        user = request.user if request else None
        if user is not None and not user.is_verified:
            raise serializers.ValidationError(
                {
                    "non_field_errors": _(
                        "Verify your identity before booking. Complete KYC from your profile."
                    )
                }
            )
        if (
            org.require_client_name
            and user is not None
            and not user.show_real_name
            and not attrs.get("share_name", False)
        ):
            raise serializers.ValidationError({"share_name": _("Share your name to book with this organization.")})
        variant = attrs.get("service_variant")
        if variant and variant.service_id != service.id:
            raise serializers.ValidationError({"service_variant": "Variant does not belong to this service."})
        n_variants = ServiceVariantModel.objects.filter(
            service=service,
            is_active=True,
            deleted_at__isnull=True,
        ).count()
        if n_variants >= 2 and variant is None:
            raise serializers.ValidationError(
                {"service_variant": "Select an option when the service has multiple variants."}
            )
        cac = attrs.get("accepted_currency")
        if cac and cac.country_id != org.country_id:
            raise serializers.ValidationError({"accepted_currency": "Currency must match the organization country."})
        AvailabilityService.validate_slots(
            service=service,
            practitioner=attrs.get("practitioner"),
            slots=attrs.get("time_slots", []),
        )
        return attrs

    @transaction.atomic
    def create(self, validated_data):
        slots = validated_data.pop("time_slots")
        user = self.context["request"].user
        validated_data["user"] = user
        service = validated_data["service"]
        org = service.organization
        validated_data["organization"] = org
        if not validated_data.get("accepted_currency"):
            if service.accepted_currency_id:
                validated_data["accepted_currency"] = service.accepted_currency
            elif org.default_currency_id:
                validated_data["accepted_currency"] = org.default_currency
        if validated_data.get("status") is None:
            validated_data["status"] = Booking.BookingStatus.REQUESTED
        apply_platform_fee_to_booking_data(
            validated_data=validated_data,
            service=service,
            organization=org,
        )
        booking = Booking.objects.create(**validated_data)
        for row in slots:
            BookingTimeSlot.objects.create(booking=booking, **row)
        return booking


class BookingCancelSerializer(serializers.Serializer):
    reason = serializers.CharField(required=False, allow_blank=True, default="")


class BookingRejectSerializer(serializers.Serializer):
    reason = serializers.CharField(required=True, allow_blank=False, max_length=2000)
