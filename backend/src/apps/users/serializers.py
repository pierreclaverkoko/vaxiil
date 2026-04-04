from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from django_drf_dynamics.serializers.fields import ChoiceEnumField
from rest_framework import serializers

from src.apps.organizations.serializers import OrganizationMembershipBriefSerializer

from .models import User


class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, validators=[validate_password])
    password_confirm = serializers.CharField(write_only=True)
    # Do not inherit model choices here: clients may send legacy names (e.g. CLIENT);
    # `validate_role` + `User.coerce_role` map them to single-char codes.
    role = serializers.CharField(required=False, allow_blank=True)

    class Meta:
        model = User
        fields = [
            'email', 'username', 'password', 'password_confirm',
            'first_name', 'last_name', 'phone', 'role',
        ]

    def validate_role(self, value):
        return User.coerce_role(value)

    def validate(self, attrs):
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError("Passwords don't match")
        return attrs

    def create(self, validated_data):
        validated_data.pop('password_confirm')
        role = validated_data.get('role', User.UserRole.CLIENT)
        if isinstance(role, User.UserRole):
            validated_data['role'] = role.value
        user = User.objects.create_user(**validated_data)
        user.generate_trust_alias()
        return user


class UserLoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField()

    def validate(self, attrs):
        email = attrs.get('email')
        password = attrs.get('password')

        if email and password:
            user = authenticate(username=email, password=password)
            if not user:
                raise serializers.ValidationError('Invalid credentials')
            if not user.is_active:
                raise serializers.ValidationError('User account is disabled')
            attrs['user'] = user
            return attrs
        raise serializers.ValidationError('Must include email and password')


class UserProfileSerializer(serializers.ModelSerializer):
    organization_name = serializers.CharField(source='organization.name', read_only=True)
    organization_memberships = OrganizationMembershipBriefSerializer(
        many=True,
        read_only=True,
    )
    role = ChoiceEnumField()
    verification_status = ChoiceEnumField()
    avatar = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id', 'email', 'username', 'first_name', 'last_name',
            'phone', 'role', 'organization',
            'organization_name', 'organization_memberships',
            'trust_alias', 'is_trusted',
            'verification_status',
            'rejection_reason', 'verified_at',
            'show_real_name', 'show_phone_number', 'avatar',
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
            'created_at',
            'updated_at',
        ]

    def validate_organization(self, value):
        if value is None:
            return value
        user = self.instance
        if user is None:
            return value
        if not user.organization_memberships.filter(organization=value).exists():
            raise serializers.ValidationError(
                'You are not a member of this organization.'
            )
        return value

    def update(self, instance, validated_data):
        request = self.context.get('request')
        if request is not None and 'role' in request.data:
            raw = request.data.get('role')
            if isinstance(raw, dict):
                raw = raw.get('value')
            if raw is not None and raw != '':
                validated_data['role'] = User.coerce_role(raw).value
        return super().update(instance, validated_data)

    def get_avatar(self, obj):
        if not obj.avatar:
            return None
        request = self.context.get('request')
        url = obj.avatar.url
        if request is not None:
            return request.build_absolute_uri(url)
        return url


class UserVerificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = [
            'id_document', 'selfie_document',
        ]

    def update(self, instance, validated_data):
        instance.verification_status = User.VerificationStatus.PENDING
        return super().update(instance, validated_data)
