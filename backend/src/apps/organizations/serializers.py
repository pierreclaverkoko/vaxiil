from django.db import transaction
from django.utils import timezone
from django.utils.translation import gettext as _
from django_drf_dynamics.serializers.fields import ChoiceEnumField
from rest_framework import serializers

from cities.models import City
from src.apps.core.fields import ChoiceValueField
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
    CityBriefSerializer,
    CountryAcceptedCurrencySerializer,
    CountryBriefSerializer,
)
from src.apps.users.models import User


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
    city = CityBriefSerializer(source="cities_city", read_only=True)

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


class OrganizationAddressWriteSerializer(serializers.ModelSerializer):
    city_id = serializers.PrimaryKeyRelatedField(
        queryset=City.objects.all(),
        source="cities_city",
        required=False,
    )
    country = serializers.PrimaryKeyRelatedField(
        queryset=Country.objects.filter(is_active=True),
        required=False,
        allow_null=True,
    )

    class Meta:
        model = OrganizationAddress
        fields = [
            "label",
            "is_primary",
            "address",
            "city_id",
            "postal_code",
            "country_text",
            "country",
            "latitude",
            "longitude",
        ]

    def validate(self, attrs):
        if self.instance is None and "cities_city" not in attrs:
            raise serializers.ValidationError({"city_id": _("This field is required.")})
        if self.instance is None and not attrs.get("address"):
            raise serializers.ValidationError({"address": _("This field is required.")})
        if self.instance is None and not attrs.get("postal_code"):
            raise serializers.ValidationError({"postal_code": _("This field is required.")})
        cities_city = attrs.get("cities_city") or getattr(self.instance, "cities_city", None)
        country = attrs.get("country")
        if country is None and self.instance is not None:
            country = self.instance.country
        if cities_city is not None and country is not None and country.cities_country_id:
            if cities_city.country_id != country.cities_country_id:
                raise serializers.ValidationError(
                    {"city_id": _("City must belong to the selected country.")}
                )
        return attrs


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
    business_license_document_url = serializers.SerializerMethodField()
    id_document_url = serializers.SerializerMethodField()
    has_venue_address = serializers.SerializerMethodField()

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
            "business_license_document_url",
            "id_document_url",
            "is_active",
            "accepts_bookings",
            "requires_prepayment",
            "require_client_name",
            "accepted_location_types",
            "has_venue_address",
            "platform_fees",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields

    def get_has_venue_address(self, obj):
        from src.apps.bookings.location_types import has_usable_venue_address

        return has_usable_venue_address(obj)

    def _pa(self, obj):
        return obj.primary_address()

    def _file_url(self, file_field):
        if not file_field:
            return None
        request = self.context.get("request")
        url = file_field.url
        if request:
            return request.build_absolute_uri(url)
        return url

    def _can_view_kyb_docs(self, obj) -> bool:
        request = self.context.get("request")
        if not request or not request.user.is_authenticated:
            return False
        if request.user.is_staff:
            return True
        role = self.get_my_membership_role(obj)
        value = role.get("value") if isinstance(role, dict) else role
        return value in {
            OrganizationMembership.OrganizationMemberRole.OWNER,
            OrganizationMembership.OrganizationMemberRole.ADMIN,
            OrganizationMembership.OrganizationMemberRole.MANAGER,
        }

    def get_business_license_document_url(self, obj):
        if not self._can_view_kyb_docs(obj):
            return None
        return self._file_url(obj.business_license_document)

    def get_id_document_url(self, obj):
        if not self._can_view_kyb_docs(obj):
            return None
        return self._file_url(obj.id_document)

    def get_address(self, obj):
        a = self._pa(obj)
        return a.address if a else ""

    def get_city(self, obj):
        a = self._pa(obj)
        if not a or not getattr(a, "cities_city_id", None):
            return None
        return CityBriefSerializer(a.cities_city).data

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
        if not a or not getattr(a, "cities_city_id", None):
            return None
        return CityBriefSerializer(a.cities_city).data

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
    address = serializers.CharField(
        write_only=True,
        max_length=255,
        required=False,
        allow_blank=True,
        default="",
    )
    city_id = serializers.PrimaryKeyRelatedField(
        queryset=City.objects.all(),
        source="cities_city",
        write_only=True,
        required=False,
        allow_null=True,
    )
    postal_code = serializers.CharField(
        write_only=True,
        max_length=20,
        required=False,
        allow_blank=True,
        default="",
    )
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
            "city_id",
            "postal_code",
            "country_text",
        ]

    def validate(self, attrs):
        from src.apps.bookings.location_types import (
            default_location_types,
            without_office,
        )

        cac = attrs.get("default_currency")
        country = attrs.get("country")
        if cac and country and cac.country_id != country.id:
            raise serializers.ValidationError({"default_currency": "Must be an accepted currency for the country."})
        address = (attrs.get("address") or "").strip()
        cities_city = attrs.get("cities_city")
        postal_code = (attrs.get("postal_code") or "").strip()
        # Partial venue payloads are rejected; omit all three for no-venue orgs.
        provided = [bool(address), cities_city is not None, bool(postal_code)]
        if any(provided) and not all(provided):
            raise serializers.ValidationError(
                {
                    "address": _(
                        "Provide street address, city, and postal code together, "
                        "or omit all venue fields."
                    ),
                }
            )
        if not address:
            # Empty accepted_location_types means all four; exclude At venue without a venue.
            attrs["accepted_location_types"] = without_office(default_location_types())
        return attrs

    def to_representation(self, instance):
        return OrganizationSerializer(instance, context=self.context).data

    def create(self, validated_data):
        request = self.context["request"]
        user = request.user
        address = (validated_data.pop("address", None) or "").strip()
        cities_city = validated_data.pop("cities_city", None)
        postal_code = (validated_data.pop("postal_code", None) or "").strip()
        country_text = validated_data.pop("country_text", "")
        accepted_location_types = validated_data.pop("accepted_location_types", None)
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
            if accepted_location_types is not None:
                org.accepted_location_types = accepted_location_types
                org.save(update_fields=["accepted_location_types", "updated_at"])
            if address and cities_city is not None:
                OrganizationAddress.objects.create(
                    organization=org,
                    address=address,
                    cities_city=cities_city,
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
    primary_city_id = serializers.PrimaryKeyRelatedField(
        queryset=City.objects.all(),
        source="cities_city",
        required=False,
        allow_null=True,
        write_only=True,
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
            "primary_city_id",
            "primary_postal_code",
            "primary_country_text",
            "primary_country",
            "primary_latitude",
            "primary_longitude",
        ]

    def validate_accepted_location_types(self, value):
        from src.apps.bookings.location_types import (
            OFFICE_LOCATION_TYPE,
            VALID_LOCATION_TYPES,
            has_usable_venue_address,
            normalize_location_types,
        )

        codes = normalize_location_types(value)
        if value and not codes:
            raise serializers.ValidationError(_("Invalid venue type codes."))
        invalid = {str(v).strip().upper() for v in (value or [])} - VALID_LOCATION_TYPES
        if invalid:
            raise serializers.ValidationError(
                _("Invalid venue types: %(codes)s")
                % {"codes": ", ".join(sorted(invalid))}
            )
        if OFFICE_LOCATION_TYPE in codes and self.instance is not None:
            if not has_usable_venue_address(self.instance):
                raise serializers.ValidationError(
                    _(
                        "At venue is only available when the company has a venue address "
                        "(street and city)."
                    )
                )
        return codes

    def validate(self, attrs):
        from src.apps.bookings.location_types import (
            OFFICE_LOCATION_TYPE,
            has_usable_venue_address,
        )

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
                "cities_city",
                "primary_postal_code",
                "primary_country_text",
                "primary_country",
                "primary_latitude",
                "primary_longitude",
            )
        )
        if inst and primary_touch and not inst.primary_address():
            addr = (attrs.get("primary_address") or "").strip()
            city = attrs.get("cities_city")
            pc = (attrs.get("primary_postal_code") or "").strip()
            # Allow clearing / omitting venue; only enforce full trio when creating one.
            if any([addr, city is not None, pc]) and not (addr and city and pc):
                raise serializers.ValidationError(
                    {
                        "primary_address": _(
                            "Provide primary_address, primary_city_id, and primary_postal_code "
                            "together when creating a venue address."
                        ),
                    }
                )

        if inst and OFFICE_LOCATION_TYPE in (attrs.get("accepted_location_types") or []):
            # After this update, would venue still exist?
            will_have_venue = has_usable_venue_address(inst)
            if primary_touch:
                addr = (attrs.get("primary_address") or "").strip()
                city = attrs.get("cities_city")
                if addr and city is not None:
                    will_have_venue = True
                elif "primary_address" in attrs and not addr:
                    will_have_venue = False
            if not will_have_venue:
                raise serializers.ValidationError(
                    {
                        "accepted_location_types": _(
                            "At venue is only available when the company has a venue address "
                            "(street and city)."
                        )
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
            "cities_city",
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
            from src.apps.bookings.location_types import (
                has_usable_venue_address,
                strip_office_from_org_location_types,
            )

            if not has_usable_venue_address(instance):
                strip_office_from_org_location_types(instance)

        return instance

    def _upsert_primary_address(self, org, data):
        from src.apps.bookings.location_types import strip_office_from_org_location_types

        pa = org.primary_address()
        updates = {}
        if "primary_address" in data:
            updates["address"] = data["primary_address"]
        if "cities_city" in data and data["cities_city"] is not None:
            updates["cities_city"] = data["cities_city"]
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

        addr = (data.get("primary_address") if "primary_address" in data else None)
        if pa:
            for key, val in updates.items():
                setattr(pa, key, val)
            # Blanking street clears the venue row when it is the only address.
            if "primary_address" in data and not (addr or "").strip():
                pa.delete()
                strip_office_from_org_location_types(org)
                return
            pa.save()
            return

        addr = (data.get("primary_address") or "").strip()
        cities_city = data.get("cities_city")
        pc = (data.get("primary_postal_code") or "").strip()
        if not (addr and cities_city is not None and pc):
            return
        country = data.get("primary_country") or org.country
        OrganizationAddress.objects.create(
            organization=org,
            address=addr,
            cities_city=cities_city,
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
