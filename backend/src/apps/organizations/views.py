from decimal import Decimal

from django.db.models import Count, Prefetch, Q, Sum
from django.utils.dateparse import parse_date
from django.utils.translation import gettext as _
from rest_framework import mixins, permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response

from src.apps.bookings.models import Booking
from src.apps.finances.models import (
    OrganizationRevenueLedger,
    SettlementAccount,
    SettlementRequest,
)
from src.apps.organizations.models import (
    Country,
    CountryAcceptedCurrency,
    Organization,
    OrganizationMembership,
    OrganizationTeamInvite,
    OrganizationTypeModel,
)
from src.apps.organizations.serializers import (
    OrganizationCreateSerializer,
    OrganizationDiscoverySerializer,
    OrganizationSerializer,
    OrganizationSubmitVerificationSerializer,
    OrganizationTeamInviteResultSerializer,
    OrganizationTeamInviteSerializer,
    OrganizationTeamMemberSerializer,
    OrganizationTeamMembershipUpdateSerializer,
    OrganizationTypeSerializer,
    OrganizationUpdateSerializer,
)
from src.apps.organizations.serializers_geo import (
    CityBriefSerializer,
    CountryAcceptedCurrencySerializer,
    CountryBriefSerializer,
)
from src.apps.payments.models import PaymentTransaction
from src.apps.users.permissions import IsEmailVerified
from cities.models import City

_ORG_MODIFY_ROLES = frozenset(
    {
        OrganizationMembership.OrganizationMemberRole.OWNER,
        OrganizationMembership.OrganizationMemberRole.ADMIN,
        OrganizationMembership.OrganizationMemberRole.MANAGER,
        OrganizationMembership.OrganizationMemberRole.STAFF,
    }
)
_TEAM_MANAGE_ROLES = frozenset(
    {
        OrganizationMembership.OrganizationMemberRole.OWNER,
        OrganizationMembership.OrganizationMemberRole.ADMIN,
    }
)


class CountryViewSet(viewsets.ReadOnlyModelViewSet):
    """List countries (registration / address FK)."""

    permission_classes = [permissions.AllowAny]
    serializer_class = CountryBriefSerializer

    def get_queryset(self):
        return Country.objects.filter(
            is_active=True,
            deleted_at__isnull=True,
        ).select_related("cities_country").order_by("cities_country__name")


class CityViewSet(viewsets.ReadOnlyModelViewSet):
    """City autocomplete for operating addresses (?country=&q=)."""

    permission_classes = [permissions.AllowAny]
    serializer_class = CityBriefSerializer
    http_method_names = ['get', 'head', 'options']

    def get_queryset(self):
        qs = City.objects.all().select_related('country').order_by('name')
        country = self.request.query_params.get('country')
        q = (self.request.query_params.get('q') or '').strip()
        if country:
            org_country = Country.objects.filter(pk=country).select_related(
                'cities_country'
            ).first()
            if org_country and org_country.cities_country_id:
                qs = qs.filter(country_id=org_country.cities_country_id)
            else:
                # Treat as ISO2 or cities country id
                qs = qs.filter(
                    Q(country__code__iexact=country) | Q(country_id=country)
                )
        if q:
            qs = qs.filter(Q(name__icontains=q) | Q(name_std__icontains=q))
        return qs[:50]


class CountryAcceptedCurrencyViewSet(viewsets.ReadOnlyModelViewSet):
    """Accepted currencies per country (filter with ?country=<uuid>)."""

    permission_classes = [permissions.AllowAny]
    serializer_class = CountryAcceptedCurrencySerializer

    def get_queryset(self):
        qs = CountryAcceptedCurrency.objects.filter(
            is_active=True,
            deleted_at__isnull=True,
        ).select_related("country", "currency")
        country_id = self.request.query_params.get("country")
        if country_id:
            qs = qs.filter(country_id=country_id)
        return qs.order_by("country__name", "currency__code")


class OrganizationTypeViewSet(viewsets.ReadOnlyModelViewSet):
    """List active organization types (for business registration)."""

    permission_classes = [permissions.IsAuthenticated, IsEmailVerified]
    serializer_class = OrganizationTypeSerializer

    def get_queryset(self):
        return OrganizationTypeModel.objects.filter(is_active=True).order_by("display_name")


class OrganizationViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.CreateModelMixin,
    mixins.UpdateModelMixin,
    viewsets.GenericViewSet,
):
    permission_classes = [permissions.IsAuthenticated, IsEmailVerified]
    lookup_field = "pk"

    def get_parser_classes(self):
        if self.action in ("create", "update", "partial_update"):
            return [JSONParser, MultiPartParser, FormParser]
        return super().get_parser_classes()

    def get_queryset(self):
        user = self.request.user
        if user.is_staff:
            qs = Organization.objects.all()
        else:
            qs = Organization.objects.filter(memberships__user=user).distinct()
        return (
            qs.select_related(
                "country",
                "default_currency",
                "default_currency__currency",
                "type",
            )
            .prefetch_related(
                "addresses",
                "addresses__country",
                Prefetch(
                    "memberships",
                    queryset=OrganizationMembership.objects.filter(
                        user=user,
                    ).only("id", "organization_id", "role"),
                ),
            )
            .order_by("name")
        )

    def get_serializer_class(self):
        if self.action == "create":
            return OrganizationCreateSerializer
        if self.action in ("update", "partial_update"):
            return OrganizationUpdateSerializer
        return OrganizationSerializer

    @action(
        detail=False,
        methods=["get"],
        url_path="discovery",
        permission_classes=[permissions.AllowAny],
    )
    def discovery(self, request):
        """List verified organizations accepting bookings (client discovery, not membership-scoped)."""
        qs = (
            Organization.objects.filter(
                verification_status=Organization.VerificationStatus.VERIFIED,
                is_active=True,
                accepts_bookings=True,
            )
            .select_related("type", "country")
            .prefetch_related("addresses", "addresses__country")
            .order_by("name")[:20]
        )
        ser = OrganizationDiscoverySerializer(qs, many=True, context={"request": request})
        return Response(ser.data)

    @action(detail=False, methods=["get"], url_path="mine-summary")
    def mine_summary(self, request):
        """Aggregate stats across organizations the current user can list (memberships)."""
        qs = self.get_queryset()
        org_ids = list(qs.values_list("pk", flat=True))
        collective_beneficiaries = Booking.objects.filter(
            organization_id__in=org_ids,
            deleted_at__isnull=True,
            status=Booking.BookingStatus.COMPLETED,
        ).count()
        return Response(
            {
                "organization_count": len(org_ids),
                "collective_beneficiaries": collective_beneficiaries,
            }
        )

    def perform_update(self, serializer):
        self._ensure_can_modify_organization(self.request.user, serializer.instance)
        serializer.save()

    def _ensure_can_modify_organization(self, user, org):
        if user.is_staff:
            return
        membership = OrganizationMembership.objects.filter(user=user, organization=org).first()
        if not membership:
            raise PermissionDenied(_("You are not a member of this organization."))
        if membership.role not in _ORG_MODIFY_ROLES:
            raise PermissionDenied(_("Insufficient permissions to update this organization."))

    def _ensure_can_manage_team(self, user, org):
        if user.is_staff:
            return
        membership = OrganizationMembership.objects.filter(user=user, organization=org).first()
        if not membership or membership.role not in _TEAM_MANAGE_ROLES:
            raise PermissionDenied(_("Only organization owners and administrators can manage the team."))

    @action(
        detail=True,
        methods=["post"],
        url_path="submit-verification",
        parser_classes=[MultiPartParser, FormParser],
    )
    def submit_verification(self, request, pk=None):
        """Upload KYB documents; sets verification status to PENDING for staff review."""
        org = self.get_object()
        self._ensure_can_modify_organization(request.user, org)
        serializer = OrganizationSubmitVerificationSerializer(
            org,
            data=request.data,
            partial=True,
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        org.refresh_from_db()
        out = OrganizationSerializer(org, context={"request": request})
        return Response(out.data, status=200)

    @action(detail=True, methods=["get"])
    def team(self, request, pk=None):
        org = self.get_object()
        memberships = (
            OrganizationMembership.objects.filter(organization=org).select_related("user").order_by("user__email")
        )
        ser = OrganizationTeamMemberSerializer(memberships, many=True)
        return Response(ser.data)

    @action(detail=True, methods=["post"], url_path="team/invite")
    def team_invite(self, request, pk=None):
        org = self.get_object()
        self._ensure_can_manage_team(request.user, org)
        serializer = OrganizationTeamInviteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data["email"].lower()
        role = serializer.validated_data["role"]

        from src.apps.users.models import User

        user = User.objects.filter(email__iexact=email).first()
        if user:
            membership, created = OrganizationMembership.objects.get_or_create(
                organization=org,
                user=user,
                defaults={"role": role},
            )
            if not created:
                raise ValidationError({"email": _("This user is already on the organization team.")})
            from django.conf import settings

            from src.apps.notifications.models import Notification
            from src.apps.notifications.services import notify_user

            site = (getattr(settings, "SITE_URL", None) or "http://localhost:8000").rstrip("/")
            notify_user(
                user=user,
                kind=Notification.Kind.TEAM_INVITE,
                title=str(_("You've been added to %(org)s") % {"org": org.name}),
                body=str(
                    _(
                        "%(inviter)s added you to the %(org)s team on Vaxiil."
                    )
                    % {"inviter": request.user.email, "org": org.name}
                ),
                organization=org,
                audience=Notification.Audience.ORGANIZATION,
                cta_url=f"{site}/business/{org.pk}",
                cta_label=str(_("Open business hub")),
            )
            return Response(
                OrganizationTeamMemberSerializer(membership).data,
                status=status.HTTP_201_CREATED,
            )

        invite, created = OrganizationTeamInvite.objects.get_or_create(
            organization=org,
            email__iexact=email,
            accepted_at__isnull=True,
            defaults={
                "email": email,
                "role": role,
                "created_by": request.user,
            },
        )
        if not created:
            invite.role = role
            invite.created_by = request.user
            invite.save(update_fields=["role", "created_by", "updated_at"])

        from django.conf import settings

        from src.apps.notifications.services import notify_email_only

        site = (getattr(settings, "SITE_URL", None) or "http://localhost:8000").rstrip("/")
        org_name = org.name
        notify_email_only(
            email=email,
            title=str(_("You're invited to join %(org)s on Vaxiil") % {"org": org_name}),
            body=str(
                _(
                    "%(inviter)s invited you to join %(org)s on Vaxiil.\n"
                    "Sign up or log in with this email address to continue."
                )
                % {
                    "inviter": request.user.email,
                    "org": org_name,
                }
            ),
            cta_url=f"{site}/register",
            cta_label=str(_("Join Vaxiil")),
        )
        return Response(
            OrganizationTeamInviteResultSerializer(invite).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )

    @action(
        detail=True,
        methods=["patch", "delete"],
        url_path=r"team/(?P<membership_id>[^/.]+)",
    )
    def team_membership(self, request, pk=None, membership_id=None):
        org = self.get_object()
        self._ensure_can_manage_team(request.user, org)
        membership = (
            OrganizationMembership.objects.filter(organization=org, pk=membership_id).select_related("user").first()
        )
        if not membership:
            raise ValidationError({"detail": _("Team membership was not found.")})

        if request.method == "DELETE":
            self._ensure_not_sole_owner(membership)
            membership.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)

        serializer = OrganizationTeamMembershipUpdateSerializer(membership, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        if (
            membership.role == OrganizationMembership.OrganizationMemberRole.OWNER
            and serializer.validated_data.get("role") != OrganizationMembership.OrganizationMemberRole.OWNER
        ):
            self._ensure_not_sole_owner(membership)
        serializer.save()
        return Response(OrganizationTeamMemberSerializer(membership).data)

    @staticmethod
    def _ensure_not_sole_owner(membership):
        if membership.role != OrganizationMembership.OrganizationMemberRole.OWNER:
            return
        owner_count = OrganizationMembership.objects.filter(
            organization=membership.organization,
            role=OrganizationMembership.OrganizationMemberRole.OWNER,
        ).count()
        if owner_count <= 1:
            raise ValidationError({"detail": _("An organization must retain at least one owner.")})

    @action(detail=True, methods=["get"])
    def analytics(self, request, pk=None):
        org = self.get_object()
        code = "USD"
        if org.default_currency_id and org.default_currency.currency_id:
            code = org.default_currency.currency.code
        bookings = Booking.objects.filter(
            organization=org,
            deleted_at__isnull=True,
        )
        for param, lookup in (
            ("date_from", "created_at__date__gte"),
            ("date_to", "created_at__date__lte"),
        ):
            raw = request.query_params.get(param)
            if raw:
                parsed = parse_date(raw)
                if parsed is None:
                    raise ValidationError({param: _("Use a date in YYYY-MM-DD format.")})
                bookings = bookings.filter(**{lookup: parsed})

        counts = bookings.aggregate(
            total_bookings=Count("id"),
            confirmed_bookings=Count("id", filter=Q(status=Booking.BookingStatus.CONFIRMED)),
            completed_bookings=Count("id", filter=Q(status=Booking.BookingStatus.COMPLETED)),
            cancelled_bookings=Count("id", filter=Q(status=Booking.BookingStatus.CANCELLED)),
        )
        completed_ids = bookings.filter(status=Booking.BookingStatus.COMPLETED).values("id")
        revenue_transactions = PaymentTransaction.objects.filter(
            booking_id__in=completed_ids,
            status=PaymentTransaction.TransactionStatus.SUCCEEDED,
        )
        if org.default_currency_id:
            revenue_transactions = revenue_transactions.filter(
                currency_id=org.default_currency.currency_id
            )
        paid = revenue_transactions.filter(
            kind=PaymentTransaction.TransactionKind.PAYMENT,
        ).aggregate(total=Sum("amount"))["total"] or Decimal("0")
        refunded = revenue_transactions.filter(
            kind__in=(
                PaymentTransaction.TransactionKind.REFUND,
                PaymentTransaction.TransactionKind.PARTIAL_REFUND,
            )
        ).aggregate(total=Sum("amount"))["total"] or Decimal("0")
        revenue = max(Decimal("0"), paid - refunded)

        from src.apps.finances.models import PlatformFeeEntry

        fee_qs = PlatformFeeEntry.objects.filter(
            organization=org,
            booking_id__in=completed_ids,
        )
        if org.default_currency_id:
            fee_qs = fee_qs.filter(currency_id=org.default_currency.currency_id)
        accrued_fees = fee_qs.filter(
            status=PlatformFeeEntry.EntryStatus.ACCRUED,
        ).aggregate(total=Sum("amount"))["total"] or Decimal("0")
        reversed_fees = fee_qs.filter(
            status=PlatformFeeEntry.EntryStatus.REVERSED,
        ).aggregate(total=Sum("amount"))["total"] or Decimal("0")
        platform_fees = max(Decimal("0"), accrued_fees - reversed_fees)
        net_revenue = max(Decimal("0"), revenue - platform_fees)
        return Response(
            {
                "organization_id": str(org.id),
                **counts,
                "revenue": f"{revenue:.2f}",
                "gross_revenue": f"{revenue:.2f}",
                "platform_fees": f"{platform_fees:.2f}",
                "net_revenue": f"{net_revenue:.2f}",
                "currency": code,
            }
        )

    def _ensure_can_manage_settlement(self, user, org):
        membership = OrganizationMembership.objects.filter(
            user=user, organization=org
        ).first()
        if not membership or membership.role not in _TEAM_MANAGE_ROLES:
            raise PermissionDenied(
                _("Only organization owners and administrators can manage settlement.")
            )

    @action(detail=True, methods=["get", "post"], url_path="settlement/accounts")
    def settlement_accounts(self, request, pk=None):
        from src.apps.organizations.settlement_serializers import (
            SettlementAccountSerializer,
        )

        org = self.get_object()
        self._ensure_can_manage_settlement(request.user, org)
        if request.method == "GET":
            qs = SettlementAccount.objects.filter(
                organization=org, deleted_at__isnull=True
            ).select_related(
                'method',
                'method__connector',
                'method__country',
                'method__currency',
            )
            return Response(
                SettlementAccountSerializer(
                    qs, many=True, context={'request': request}
                ).data
            )

        ser = SettlementAccountSerializer(
            data=request.data, context={'request': request}
        )
        ser.is_valid(raise_exception=True)
        account = ser.save(organization=org)
        if account.is_default:
            SettlementAccount.objects.filter(organization=org).exclude(
                pk=account.pk
            ).update(is_default=False)
        account = SettlementAccount.objects.select_related(
            'method', 'method__connector'
        ).get(pk=account.pk)
        return Response(
            SettlementAccountSerializer(
                account, context={'request': request}
            ).data,
            status=status.HTTP_201_CREATED,
        )

    @action(
        detail=True,
        methods=["patch", "delete"],
        url_path=r"settlement/accounts/(?P<account_id>[^/.]+)",
    )
    def settlement_account_detail(self, request, pk=None, account_id=None):
        from src.apps.organizations.settlement_serializers import (
            SettlementAccountSerializer,
        )

        org = self.get_object()
        self._ensure_can_manage_settlement(request.user, org)
        account = SettlementAccount.objects.filter(
            organization=org, pk=account_id, deleted_at__isnull=True
        ).first()
        if not account:
            raise ValidationError({"detail": _("Settlement account not found.")})
        if request.method == "DELETE":
            account.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        ser = SettlementAccountSerializer(account, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        account = ser.save()
        if account.is_default:
            SettlementAccount.objects.filter(organization=org).exclude(
                pk=account.pk
            ).update(is_default=False)
        return Response(SettlementAccountSerializer(account).data)

    @action(detail=True, methods=["get", "patch"], url_path="settlement/settings")
    def settlement_settings(self, request, pk=None):
        from src.apps.finances.models import Currency
        from src.apps.finances.services.settlement import get_or_create_settlement_settings
        from src.apps.organizations.settlement_serializers import (
            SettlementSettingsSerializer,
        )

        org = self.get_object()
        self._ensure_can_manage_settlement(request.user, org)
        currency = None
        if org.default_currency_id and org.default_currency:
            currency = org.default_currency.currency
        if currency is None:
            currency = Currency.objects.filter(code="USD", is_active=True).first()
        if currency is None:
            raise ValidationError({"currency": _("No currency configured.")})
        settings_row = get_or_create_settlement_settings(
            organization=org, currency=currency
        )
        if request.method == "GET":
            return Response(SettlementSettingsSerializer(settings_row).data)
        ser = SettlementSettingsSerializer(
            settings_row, data=request.data, partial=True
        )
        ser.is_valid(raise_exception=True)
        ser.save()
        return Response(SettlementSettingsSerializer(settings_row).data)

    @action(detail=True, methods=["get"], url_path="settlement/balance")
    def settlement_balance(self, request, pk=None):
        from src.apps.organizations.settlement_serializers import (
            RevenueLedgerSerializer,
            revenue_balances_payload,
        )

        org = self.get_object()
        self._ensure_can_manage_settlement(request.user, org)
        ledger = (
            OrganizationRevenueLedger.objects.filter(wallet__organization=org)
            .select_related("wallet__currency")
            .order_by("-created_at")[:50]
        )
        return Response(
            {
                "balances": revenue_balances_payload(org),
                "ledger": RevenueLedgerSerializer(ledger, many=True).data,
            }
        )

    @action(detail=True, methods=["get", "post"], url_path="settlement/requests")
    def settlement_requests(self, request, pk=None):
        from src.apps.finances.models import Currency
        from src.apps.finances.services.settlement import create_manual_settlement_request
        from src.apps.organizations.settlement_serializers import (
            SettlementRequestBusinessSerializer,
            SettlementRequestCreateSerializer,
        )

        org = self.get_object()
        self._ensure_can_manage_settlement(request.user, org)
        if request.method == "GET":
            qs = SettlementRequest.objects.filter(organization=org).select_related(
                "currency"
            )
            return Response(
                SettlementRequestBusinessSerializer(qs, many=True).data
            )

        ser = SettlementRequestCreateSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        account = SettlementAccount.objects.filter(
            organization=org,
            pk=ser.validated_data["account_id"],
            deleted_at__isnull=True,
        ).first()
        if not account:
            raise ValidationError({"account_id": _("Settlement account not found.")})
        code = (ser.validated_data.get("currency_code") or "").upper()
        if code:
            currency = Currency.objects.filter(code=code, is_active=True).first()
        elif org.default_currency_id:
            currency = org.default_currency.currency
        else:
            currency = None
        if currency is None:
            raise ValidationError({"currency_code": _("Currency is required.")})
        req = create_manual_settlement_request(
            organization=org,
            amount=ser.validated_data["amount"],
            currency=currency,
            account=account,
            requested_by=request.user,
        )
        return Response(
            SettlementRequestBusinessSerializer(req).data,
            status=status.HTTP_201_CREATED,
        )
