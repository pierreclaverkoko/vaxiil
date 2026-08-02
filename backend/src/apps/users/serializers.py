from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from django.utils import timezone
from django.utils.translation import gettext as _
from django_drf_dynamics.serializers.fields import ChoiceEnumField
from rest_framework import serializers

from src.apps.core.fields import ChoiceValueField, TurnstileField, choice_enum_dict
from src.apps.organizations.serializers import OrganizationMembershipBriefSerializer
from src.apps.organizations.serializers_geo import CountryBriefSerializer
from src.apps.organizations.models import Country
from src.apps.users.legal_services import (
    legal_status_for_user,
    record_acceptance,
    require_current_acceptance_versions,
)
from src.apps.users.legal_models import UserLegalAcceptance

from .models import User


class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, validators=[validate_password])
    password_confirm = serializers.CharField(write_only=True)
    # Do not inherit model choices here: clients may send legacy names (e.g. CLIENT);
    # `validate_role` + `User.coerce_role` map them to single-char codes.
    role = serializers.CharField(required=False, allow_blank=True)
    accepted_terms_version = serializers.CharField(write_only=True)
    accepted_privacy_version = serializers.CharField(write_only=True)
    cf_turnstile_response = TurnstileField()

    class Meta:
        model = User
        fields = [
            'email', 'username', 'password', 'password_confirm',
            'first_name', 'last_name', 'phone', 'role',
            'accepted_terms_version', 'accepted_privacy_version',
            'cf_turnstile_response',
        ]

    def validate_role(self, value):
        return User.coerce_role(value)

    def validate(self, attrs):
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError(_("Passwords don't match"))
        terms, privacy = require_current_acceptance_versions(
            accepted_terms_version=attrs.get('accepted_terms_version'),
            accepted_privacy_version=attrs.get('accepted_privacy_version'),
        )
        attrs['_terms_document'] = terms
        attrs['_privacy_document'] = privacy
        return attrs

    def create(self, validated_data):
        validated_data.pop('password_confirm')
        validated_data.pop('cf_turnstile_response', None)
        terms = validated_data.pop('_terms_document')
        privacy = validated_data.pop('_privacy_document')
        validated_data.pop('accepted_terms_version', None)
        validated_data.pop('accepted_privacy_version', None)
        role = validated_data.get('role', User.UserRole.CLIENT)
        if isinstance(role, User.UserRole):
            validated_data['role'] = role.value
        user = User.objects.create_user(**validated_data)
        user.generate_trust_alias()
        record_acceptance(
            user=user,
            terms_document=terms,
            privacy_document=privacy,
            source=UserLegalAcceptance.Source.SIGNUP,
            request=self.context.get('request'),
        )
        return user


class UserLoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField()
    cf_turnstile_response = TurnstileField()

    def validate(self, attrs):
        email = attrs.get('email')
        password = attrs.get('password')

        if email and password:
            user = authenticate(username=email, password=password)
            if not user:
                raise serializers.ValidationError(_('Invalid credentials'))
            if not user.is_active:
                raise serializers.ValidationError(_('User account is disabled'))
            attrs['user'] = user
            return attrs
        raise serializers.ValidationError(_('Must include email and password'))


class LoginVerifyOtpSerializer(serializers.Serializer):
    challenge_id = serializers.UUIDField()
    code = serializers.CharField()
    cf_turnstile_response = TurnstileField()


class EmailVerifySerializer(serializers.Serializer):
    challenge_id = serializers.UUIDField()
    code = serializers.CharField()


class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()
    cf_turnstile_response = TurnstileField()


class PasswordResetConfirmSerializer(serializers.Serializer):
    email = serializers.EmailField()
    challenge_id = serializers.UUIDField()
    code = serializers.CharField()
    new_password = serializers.CharField()
    cf_turnstile_response = TurnstileField()


class GoogleAuthSerializer(serializers.Serializer):
    id_token = serializers.CharField()
    accepted_terms_version = serializers.CharField(required=False, allow_blank=True)
    accepted_privacy_version = serializers.CharField(required=False, allow_blank=True)
    cf_turnstile_response = TurnstileField()


class UserProfileSerializer(serializers.ModelSerializer):
    organization_name = serializers.CharField(source='organization.name', read_only=True)
    organization_memberships = OrganizationMembershipBriefSerializer(
        many=True,
        read_only=True,
    )
    role = ChoiceValueField(choices=User.UserRole.choices, required=False)
    verification_status = ChoiceEnumField()
    sex = ChoiceValueField(
        choices=User.Sex.choices,
        required=False,
        allow_null=True,
    )
    age = serializers.IntegerField(read_only=True)
    avatar = serializers.SerializerMethodField()
    id_document_url = serializers.SerializerMethodField()
    selfie_document_url = serializers.SerializerMethodField()
    legal = serializers.SerializerMethodField()
    email_verified = serializers.BooleanField(read_only=True)
    needs_email_verification = serializers.BooleanField(read_only=True)
    default_country = CountryBriefSerializer(read_only=True)
    default_country_id = serializers.PrimaryKeyRelatedField(
        queryset=Country.objects.filter(is_active=True),
        source='default_country',
        required=False,
        allow_null=True,
        write_only=True,
    )

    class Meta:
        model = User
        fields = [
            'id', 'email', 'username', 'first_name', 'last_name',
            'phone', 'role', 'organization',
            'organization_name', 'organization_memberships',
            'trust_alias', 'is_trusted',
            'verification_status',
            'rejection_reason', 'verified_at',
            'date_of_birth', 'sex',
            'show_real_name', 'show_phone_number', 'show_email', 'avatar',
            'id_document_url', 'selfie_document_url',
            'age',
            'two_factor_enabled',
            'email_verified',
            'needs_email_verification',
            'default_country',
            'default_country_id',
            'is_staff',
            'is_superuser',
            'legal',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id',
            'trust_alias',
            'is_trusted',
            'verification_status',
            'rejection_reason',
            'verified_at',
            'organization_memberships',
            'id_document_url',
            'selfie_document_url',
            'email_verified',
            'needs_email_verification',
            'is_staff',
            'is_superuser',
            'legal',
            'created_at',
            'updated_at',
        ]

    def validate_date_of_birth(self, value):
        if value and value > timezone.localdate():
            raise serializers.ValidationError(
                _('Date of birth cannot be in the future.')
            )
        return value

    def validate_organization(self, value):
        if value is None:
            return value
        user = self.instance
        if user is None:
            return value
        if not user.organization_memberships.filter(organization=value).exists():
            raise serializers.ValidationError(
                _('You are not a member of this organization.')
            )
        return value

    def validate_role(self, value):
        return User.coerce_role(value).value

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['role'] = choice_enum_dict(instance, 'role')
        data['sex'] = choice_enum_dict(instance, 'sex')
        return data

    def get_avatar(self, obj):
        if not obj.avatar:
            return None
        request = self.context.get('request')
        url = obj.avatar.url
        if request is not None:
            return request.build_absolute_uri(url)
        return url

    def _document_url(self, file_field):
        if not file_field:
            return None
        request = self.context.get('request')
        url = file_field.url
        if request is not None:
            return request.build_absolute_uri(url)
        return url

    def get_id_document_url(self, obj):
        return self._document_url(obj.id_document)

    def get_selfie_document_url(self, obj):
        return self._document_url(obj.selfie_document)

    def get_legal(self, obj):
        return legal_status_for_user(obj)


class UserVerificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = [
            'id_document', 'selfie_document',
        ]

    def update(self, instance, validated_data):
        instance.verification_status = User.VerificationStatus.PENDING
        return super().update(instance, validated_data)
