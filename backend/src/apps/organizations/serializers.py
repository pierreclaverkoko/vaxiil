from django.db import transaction
from django.utils import timezone
from django_drf_dynamics.serializers.fields import ChoiceEnumField
from rest_framework import serializers

from src.apps.finances.services.platform_fees import organization_fee_summary
from src.apps.organizations.models import (
    Country,
    CountryAcceptedCurrency,
    Organization,
    OrganizationAddress,
    OrganizationMembership,
    OrganizationSettings,
    OrganizationTeamInvite,
    OrganizationTypeModel,
)
from src.apps.organizations.serializers_geo import (
    CountryAcceptedCurrencySerializer,
    CountryBriefSerializer,
)
from src.apps.users.models import User


class ChoiceValueField(serializers.ChoiceField):
    """Accept a value or the API's structured choice-enum object."""

    def to_internal_value(self, data):
        if isinstance(data, dict):
            data = data.get("value")
        return super().to_internal_value(data)


class OrganizationTypeSerializer(serializers.ModelSerializer):
    """Active organization types for registration dropdowns."""

    class Meta:
        model = OrganizationTypeModel
        fields = ["id", "name", "display_name", "description", "icon"]


class OrganizationMembershipBriefSerializer(serializers.ModelSerializer):
    """User's memberships (profile / org switching)."""

    organization_name = serializers.CharField(source="organization.name", read_only=True)
    role = ChoiceEnumField()

    class Meta:
        model = OrganizationMembership
        fields = [
            "id",
            "organization",
            "organization_name",
            "role",
        ]
        read_only_fields = fields


class OrganizationBriefSerializer(serializers.ModelSerializer):
    """Minimal org for booking cards and detail (name + logo)."""

    logo = serializers.SerializerMethodField()

    class Meta:
        model = Organization
        fields = ["id", "name", "logo"]

    def get_logo(self, obj):
        if not obj.logo:
            return None
        request = self.context.get("request")
        url = obj.logo.url
        if request:
            return request.build_absolute_uri(url)
        return url


class UserBriefSerializer(serializers.ModelSerializer):
    """Practitioner / user row on booking detail."""

    avatar_url = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ["id", "first_name", "last_name", "avatar_url"]

    def get_avatar_url(self, obj):
        if not obj.avatar:
            return None
        request = self.context.get("request")
        url = obj.avatar.url
        if request:
            return request.build_absolute_uri(url)
        return url


class OrganizationAddressSerializer(serializers.ModelSerializer):
    country = CountryBriefSerializer(read_only=True)

    class Meta:
        model = OrganizationAddress
        fields = [
            "id",
            "label",
            "is_primary",
            "address",
            "city",
            "postal_code",
            "country_text",
            "country",
            "latitude",
            "longitude",
        ]
        read_only_fields = fields


class OrganizationSerializer(serializers.ModelSerializer):
    type_display_name = serializers.CharField(source="type.display_name", read_only=True)
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
    my_membership_role = serializers.SerializerMethodField()
    platform_fees = serializers.SerializerMethodField()

    class Meta:
        model = Organization
        fields = [
            "id",
            "name",
            "type",
            "type_display_name",
            "my_membership_role",
            "description",
            "phone",
            "email",
            "website",
            "logo",
            "country",
            "default_currency",
            "addresses",
            "address",
            "city",
            "postal_code",
            "country_legacy",
            "latitude",
            "longitude",
            "verification_status",
            "rejection_reason",
            "kyb_submitted_at",
            "business_license_number",
            "tax_id",
            "is_active",
            "accepts_bookings",
            "requires_prepayment",
            "require_client_name",
            "accepted_location_types",
            "platform_fees",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields

    def _pa(self, obj):
        return obj.primary_address()

    def get_address(self, obj):
        a = self._pa(obj)
        return a.address if a else ""

    def get_city(self, obj):
        a = self._pa(obj)
        return a.city if a else ""

    def get_postal_code(self, obj):
        a = self._pa(obj)
        return a.postal_code if a else ""

    def get_country_legacy(self, obj):
        a = self._pa(obj)
        return a.country_text if a else ""

    def get_latitude(self, obj):
        a = self._pa(obj)
        if not a:
            return None
        if a.location is not None:
            return a.location.y
        return a.latitude

    def get_longitude(self, obj):
        a = self._pa(obj)
        if not a:
            return None
        if a.location is not None:
            return a.location.x
        return a.longitude

    def get_logo(self, obj):
        if not obj.logo:
            return None
        request = self.context.get("request")
        url = obj.logo.url
        if request:
            return request.build_absolute_uri(url)
        return url

    def get_platform_fees(self, obj):
        return organization_fee_summary(obj)

    def get_my_membership_role(self, obj):
        request = self.context.get("request")
        if not request or not request.user.is_authenticated:
            return None
        prefetch = getattr(obj, "_prefetched_objects_cache", {}).get("memberships")
        if prefetch is not None:
            m = next(iter(prefetch), None)
        else:
            m = obj.memberships.filter(user=request.user).first()
        if not m:
            return None
        return {
            "value": m.role,
            "title": m.get_role_display(),
            "css": m.get_role_css(),
        }


class OrganizationDiscoverySerializer(serializers.ModelSerializer):
    """Verified organizations for client home / discovery (no membership required)."""

    city = serializers.SerializerMethodField()
    logo = serializers.SerializerMethodField()
    description = serializers.SerializerMethodField()

    class Meta:
        model = Organization
        fields = ["id", "name", "description", "city", "logo"]

    def get_description(self, obj):
        text = (obj.description or "").strip()
        if len(text) <= 200:
            return text
        return f"{text[:197]}..."

    def _primary_address(self, obj):
        return obj.primary_address()

    def get_city(self, obj):
        a = self._primary_address(obj)
        return a.city if a else ""

    def get_logo(self, obj):
        if not obj.logo:
            return None
        request = self.context.get("request")
        url = obj.logo.url
        if request:
            return request.build_absolute_uri(url)
        return url


class OrganizationSubmitVerificationSerializer(serializers.ModelSerializer):
    """Multipart KYB submission for business documents (sets status to PENDING)."""

    class Meta:
        model = Organization
        fields = [
            "business_license_document",
            "id_document",
            "business_license_number",
            "tax_id",
        ]

    def validate(self, attrs):
        doc = attrs.get("business_license_document")
        id_doc = attrs.get("id_document")
        if not doc:
            raise serializers.ValidationError({"business_license_document": "This file is required."})
        if not id_doc:
            raise serializers.ValidationError({"id_document": "This file is required."})
        return attrs

    def update(self, instance, validated_data):
        instance.verification_status = Organization.VerificationStatus.PENDING
        instance.rejection_reason = ""
        instance.kyb_submitted_at = timezone.now()
        return super().update(instance, validated_data)


class OrganizationCreateSerializer(serializers.ModelSerializer):
    type = serializers.PrimaryKeyRelatedField(queryset=OrganizationTypeModel.objects.filter(is_active=True))
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
        default="",
    )
    logo = serializers.ImageField(required=True)

    class Meta:
        model = Organization
        fields = [
            "type",
            "name",
            "email",
            "phone",
            "description",
            "website",
            "logo",
            "country",
            "default_currency",
            "require_client_name",
            "address",
            "city",
            "postal_code",
            "country_text",
        ]

    def validate(self, attrs):
        cac = attrs.get("default_currency")
        country = attrs.get("country")
        if cac and country and cac.country_id != country.id:
            raise serializers.ValidationError({"default_currency": "Must be an accepted currency for the country."})
        return attrs

    def to_representation(self, instance):
        return OrganizationSerializer(instance, context=self.context).data

    def create(self, validated_data):
        request = self.context["request"]
        user = request.user
        address = validated_data.pop("address")
        city = validated_data.pop("city")
        postal_code = validated_data.pop("postal_code")
        country_text = validated_data.pop("country_text", "")
        default_currency = validated_data.pop("default_currency", None)
        country = validated_data["country"]
        if default_currency is None:
            default_currency = CountryAcceptedCurrency.objects.filter(
                country=country,
                is_default=True,
                is_active=True,
                deleted_at__isnull=True,
            ).first()
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
            update_fields = ["organization", "updated_at"]
            if user.role == User.UserRole.CLIENT:
                user.role = User.UserRole.BUSINESS_OWNER
                update_fields.append("role")
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

    primary_address = serializers.CharField(
        required=False,
        allow_blank=True,
        write_only=True,
        max_length=255,
    )
    primary_city = serializers.CharField(
        required=False,
        allow_blank=True,
        write_only=True,
        max_length=100,
    )
    primary_postal_code = serializers.CharField(
        required=False,
        allow_blank=True,
        write_only=True,
        max_length=20,
    )
    primary_country_text = serializers.CharField(
        required=False,
        allow_blank=True,
        write_only=True,
        max_length=100,
    )
    primary_country = serializers.PrimaryKeyRelatedField(
        queryset=Country.objects.filter(is_active=True),
        required=False,
        allow_null=True,
        write_only=True,
    )
    primary_latitude = serializers.DecimalField(
        max_digits=23,
        decimal_places=20,
        required=False,
        allow_null=True,
        write_only=True,
    )
    primary_longitude = serializers.DecimalField(
        max_digits=23,
        decimal_places=20,
        required=False,
        allow_null=True,
        write_only=True,
    )

    class Meta:
        model = Organization
        fields = [
            "name",
            "description",
            "phone",
            "email",
            "website",
            "logo",
            "country",
            "default_currency",
            "is_active",
            "accepts_bookings",
            "requires_prepayment",
            "require_client_name",
            "accepted_location_types",
            "primary_address",
            "primary_city",
            "primary_postal_code",
            "primary_country_text",
            "primary_country",
            "primary_latitude",
            "primary_longitude",
        ]

    def validate_accepted_location_types(self, value):
        from src.apps.bookings.location_types import (
            VALID_LOCATION_TYPES,
            normalize_location_types,
        )

        codes = normalize_location_types(value)
        if value and not codes:
            raise serializers.ValidationError("Invalid venue type codes.")
        invalid = {str(v).strip().upper() for v in (value or [])} - VALID_LOCATION_TYPES
        if invalid:
            raise serializers.ValidationError(f"Invalid venue types: {', '.join(sorted(invalid))}")
        return codes

    def validate(self, attrs):
        inst = self.instance
        next_country = attrs.get("country", inst.country if inst else None)
        if attrs.get("primary_country") is not None:
            next_country = attrs["primary_country"]
        cac = attrs.get("default_currency", getattr(inst, "default_currency", None))
        if "default_currency" in attrs:
            cac = attrs["default_currency"]
        if cac and next_country and cac.country_id != next_country.id:
            raise serializers.ValidationError(
                {"default_currency": "Must be an accepted currency for the organization country."}
            )

        primary_touch = any(
            k in attrs
            for k in (
                "primary_address",
                "primary_city",
                "primary_postal_code",
                "primary_country_text",
                "primary_country",
                "primary_latitude",
                "primary_longitude",
            )
        )
        if inst and primary_touch and not inst.primary_address():
            addr = (attrs.get("primary_address") or "").strip()
            city = (attrs.get("primary_city") or "").strip()
            pc = (attrs.get("primary_postal_code") or "").strip()
            if not (addr and city and pc):
                raise serializers.ValidationError(
                    {
                        "primary_address": (
                            "Provide primary_address, primary_city, and primary_postal_code "
                            "when creating the first primary location."
                        ),
                    }
                )

        return attrs

    def validate_email(self, value):
        org = self.instance
        if org and Organization.objects.filter(email=value).exclude(pk=org.pk).exists():
            raise serializers.ValidationError("An organization with this email already exists.")
        return value

    def update(self, instance, validated_data):
        primary_keys = (
            "primary_address",
            "primary_city",
            "primary_postal_code",
            "primary_country_text",
            "primary_country",
            "primary_latitude",
            "primary_longitude",
        )
        primary_data = {}
        for k in primary_keys:
            if k in validated_data:
                primary_data[k] = validated_data.pop(k)

        if primary_data.get("primary_country") is not None:
            validated_data["country"] = primary_data["primary_country"]

        country_in_payload = "country" in validated_data

        with transaction.atomic():
            instance = super().update(instance, validated_data)
            if country_in_payload:
                pa = instance.primary_address()
                if pa and pa.country_id != instance.country_id:
                    pa.country = instance.country
                    pa.save(update_fields=["country"])
            if primary_data:
                self._upsert_primary_address(instance, primary_data)

        return instance

    def _upsert_primary_address(self, org, data):
        pa = org.primary_address()
        updates = {}
        if "primary_address" in data:
            updates["address"] = data["primary_address"]
        if "primary_city" in data:
            updates["city"] = data["primary_city"]
        if "primary_postal_code" in data:
            updates["postal_code"] = data["primary_postal_code"]
        if "primary_country_text" in data:
            updates["country_text"] = data["primary_country_text"]
        if "primary_latitude" in data:
            updates["latitude"] = data["primary_latitude"]
        if "primary_longitude" in data:
            updates["longitude"] = data["primary_longitude"]
        if data.get("primary_country") is not None:
            updates["country"] = data["primary_country"]

        if pa:
            for key, val in updates.items():
                setattr(pa, key, val)
            pa.save()
            return

        addr = (data.get("primary_address") or "").strip()
        city = (data.get("primary_city") or "").strip()
        pc = (data.get("primary_postal_code") or "").strip()
        country = data.get("primary_country") or org.country
        OrganizationAddress.objects.create(
            organization=org,
            address=addr,
            city=city,
            postal_code=pc,
            country_text=(data.get("primary_country_text") or ""),
            country=country,
            latitude=data.get("primary_latitude"),
            longitude=data.get("primary_longitude"),
            is_primary=True,
        )
        if country:
            org.country = country
            org.save(update_fields=["country"])


class OrganizationTeamMemberSerializer(serializers.ModelSerializer):
    """Team list: one row per membership (role is per-organization)."""

    user_id = serializers.UUIDField(source="user.id", read_only=True)
    email = serializers.EmailField(source="user.email", read_only=True)
    first_name = serializers.CharField(source="user.first_name", read_only=True)
    last_name = serializers.CharField(source="user.last_name", read_only=True)
    phone = serializers.CharField(source="user.phone", read_only=True)
    role = ChoiceEnumField(choice_field_name="user_role")
    membership_role = ChoiceEnumField(choice_field_name="role")

    class Meta:
        model = OrganizationMembership
        fields = [
            "id",
            "user_id",
            "email",
            "first_name",
            "last_name",
            "role",
            "phone",
            "membership_role",
        ]


class OrganizationTeamInviteSerializer(serializers.Serializer):
    email = serializers.EmailField()
    role = ChoiceValueField(
        choices=OrganizationMembership.OrganizationMemberRole.choices,
        required=False,
        default=OrganizationMembership.OrganizationMemberRole.STAFF,
    )


class OrganizationTeamMembershipUpdateSerializer(serializers.ModelSerializer):
    role = ChoiceValueField(
        choices=OrganizationMembership.OrganizationMemberRole.choices,
    )

    class Meta:
        model = OrganizationMembership
        fields = ["role"]


class OrganizationTeamInviteResultSerializer(serializers.ModelSerializer):
    role = ChoiceEnumField()

    class Meta:
        model = OrganizationTeamInvite
        fields = ["id", "email", "role", "token", "created_at", "accepted_at"]
        read_only_fields = fields
