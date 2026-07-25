from decouple import config
from django.contrib.auth import login as auth_login
from django.contrib.auth import logout as auth_logout
from django.utils.translation import get_language_from_request
from django.utils.translation import gettext as _
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token
from rest_framework import status, permissions, viewsets
from rest_framework.decorators import action, parser_classes
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from src.apps.users.legal_models import LegalDocumentVersion, UserLegalAcceptance
from src.apps.users.legal_services import (
    body_for_locale,
    current_documents,
    legal_status_for_user,
    record_acceptance,
    require_current_acceptance_versions,
    summary_for_locale,
)

from .models import User
from .otp_models import EmailOtp
from .otp_services import create_and_send_otp, verify_otp
from .serializers import (
    GoogleAuthSerializer,
    LoginVerifyOtpSerializer,
    PasswordResetConfirmSerializer,
    PasswordResetRequestSerializer,
    UserRegistrationSerializer,
    UserLoginSerializer,
    UserProfileSerializer,
    UserVerificationSerializer,
)


def _user_for_profile(user: User) -> User:
    return User.objects.prefetch_related(
        'organization_memberships__organization'
    ).get(pk=user.pk)


def _unique_username_from_email(email: str) -> str:
    base = email.split('@')[0][:30] or 'user'
    username = base
    n = 0
    while User.objects.filter(username=username).exists():
        n += 1
        username = f'{base}{n}'
    return username


class UserAuthViewSet(viewsets.GenericViewSet):
    """Registration, session auth, Google OAuth, logout."""

    def get_permissions(self):
        """Public routes are not wired via a router, so @action permission_classes are ignored.

        Without this, DEFAULT_PERMISSION_CLASSES (IsAuthenticated) applies and login/register
        return 401.
        """
        if self.action in (
            'register',
            'login',
            'login_verify_otp',
            'google_auth',
            'metadata',
            'password_reset_request',
            'password_reset_confirm',
        ):
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    @action(
        detail=False,
        methods=['get'],
        permission_classes=[permissions.AllowAny],
        url_path='metadata',
    )
    def metadata(self, request):
        docs = current_documents()
        terms = docs['terms']
        privacy = docs['privacy']
        payload = {
            'terms_version': terms.version if terms else None,
            'terms_document_id': str(terms.id) if terms else None,
            'privacy_version': privacy.version if privacy else None,
            'privacy_document_id': str(privacy.id) if privacy else None,
        }
        if request.user and request.user.is_authenticated:
            payload['legal'] = legal_status_for_user(request.user)
        return Response(payload)

    @action(
        detail=False,
        methods=['post'],
        permission_classes=[permissions.IsAuthenticated],
        url_path='accept-legal',
    )
    def accept_legal(self, request):
        terms, privacy = require_current_acceptance_versions(
            accepted_terms_version=request.data.get('accepted_terms_version'),
            accepted_privacy_version=request.data.get('accepted_privacy_version'),
        )
        record_acceptance(
            user=request.user,
            terms_document=terms,
            privacy_document=privacy,
            source=UserLegalAcceptance.Source.REACCEPT,
            request=request,
        )
        user = _user_for_profile(request.user)
        return Response(
            UserProfileSerializer(user, context={'request': request}).data
        )

    @action(
        detail=False,
        methods=['post'],
        permission_classes=[permissions.AllowAny],
        url_path='register',
    )
    def register(self, request):
        serializer = UserRegistrationSerializer(
            data=request.data,
            context={'request': request},
        )
        if serializer.is_valid():
            user = serializer.save()
            user = _user_for_profile(user)
            refresh = RefreshToken.for_user(user)
            return Response({
                'user': UserProfileSerializer(user, context={'request': request}).data,
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @action(
        detail=False,
        methods=['post'],
        permission_classes=[permissions.AllowAny],
        url_path='login',
    )
    def login(self, request):
        serializer = UserLoginSerializer(
            data=request.data,
            context={'request': request},
        )
        if serializer.is_valid():
            user = serializer.validated_data['user']
            if user.two_factor_enabled:
                otp = create_and_send_otp(
                    email=user.email,
                    purpose=EmailOtp.Purpose.LOGIN,
                    user=user,
                )
                return Response(
                    {
                        'requires_otp': True,
                        'challenge_id': str(otp.id),
                        'email_hint': user.email,
                    },
                    status=status.HTTP_200_OK,
                )
            auth_login(request, user)
            user = _user_for_profile(user)
            refresh = RefreshToken.for_user(user)
            return Response({
                'user': UserProfileSerializer(user, context={'request': request}).data,
                'refresh': str(refresh),
                'access': str(refresh.access_token),
                'requires_otp': False,
            }, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @action(
        detail=False,
        methods=['post'],
        permission_classes=[permissions.AllowAny],
        url_path='login/verify-otp',
    )
    def login_verify_otp(self, request):
        serializer = LoginVerifyOtpSerializer(
            data=request.data,
            context={'request': request},
        )
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        challenge_id = serializer.validated_data['challenge_id']
        code = serializer.validated_data['code']
        otp = verify_otp(
            challenge_id=challenge_id,
            code=code,
            purpose=EmailOtp.Purpose.LOGIN,
        )
        user = otp.user
        if user is None or not user.is_active:
            return Response(
                {'detail': _('Invalid or expired code.')},
                status=status.HTTP_400_BAD_REQUEST,
            )
        auth_login(request, user)
        user = _user_for_profile(user)
        refresh = RefreshToken.for_user(user)
        return Response(
            {
                'user': UserProfileSerializer(user, context={'request': request}).data,
                'refresh': str(refresh),
                'access': str(refresh.access_token),
                'requires_otp': False,
            },
            status=status.HTTP_200_OK,
        )

    @action(
        detail=False,
        methods=['post'],
        permission_classes=[permissions.IsAuthenticated],
        url_path='otp/send',
    )
    def otp_send(self, request):
        purpose_raw = (request.data.get('purpose') or '').strip().lower()
        purpose_map = {
            'password_change': EmailOtp.Purpose.PASSWORD_CHANGE,
            'login': EmailOtp.Purpose.LOGIN,
        }
        purpose = purpose_map.get(purpose_raw)
        if purpose is None:
            return Response(
                {'purpose': [_('Unsupported purpose.')]},
                status=status.HTTP_400_BAD_REQUEST,
            )
        otp = create_and_send_otp(
            email=request.user.email,
            purpose=purpose,
            user=request.user,
        )
        return Response(
            {'challenge_id': str(otp.id), 'email_hint': request.user.email},
            status=status.HTTP_200_OK,
        )

    @action(
        detail=False,
        methods=['post'],
        permission_classes=[permissions.IsAuthenticated],
        url_path='password/change',
    )
    def password_change(self, request):
        from django.contrib.auth.password_validation import validate_password
        from django.core.exceptions import ValidationError as DjangoValidationError

        current_password = request.data.get('current_password') or ''
        new_password = request.data.get('new_password') or ''
        challenge_id = request.data.get('challenge_id')
        code = request.data.get('code')
        if not request.user.check_password(current_password):
            return Response(
                {'current_password': [_('Current password is incorrect.')]},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not challenge_id or not code:
            return Response(
                {'code': [_('Email verification code is required.')]},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            validate_password(new_password, user=request.user)
        except DjangoValidationError as exc:
            return Response(
                {'new_password': list(exc.messages)},
                status=status.HTTP_400_BAD_REQUEST,
            )
        verify_otp(
            challenge_id=challenge_id,
            code=code,
            purpose=EmailOtp.Purpose.PASSWORD_CHANGE,
            email=request.user.email,
        )
        request.user.set_password(new_password)
        request.user.save(update_fields=['password'])
        return Response({'detail': _('Password updated.')}, status=status.HTTP_200_OK)

    @action(
        detail=False,
        methods=['post'],
        permission_classes=[permissions.AllowAny],
        url_path='password/reset/request',
    )
    def password_reset_request(self, request):
        serializer = PasswordResetRequestSerializer(
            data=request.data,
            context={'request': request},
        )
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        email = serializer.validated_data['email'].strip().lower()
        user = User.objects.filter(email__iexact=email, is_active=True).first()
        challenge_id = None
        if user is not None:
            otp = create_and_send_otp(
                email=user.email,
                purpose=EmailOtp.Purpose.PASSWORD_RESET,
                user=user,
            )
            challenge_id = str(otp.id)
        # Always succeed to avoid account enumeration; include challenge when known.
        payload = {
            'detail': _('If an account exists for this email, a code was sent.'),
        }
        if challenge_id:
            payload['challenge_id'] = challenge_id
        return Response(payload, status=status.HTTP_200_OK)

    @action(
        detail=False,
        methods=['post'],
        permission_classes=[permissions.AllowAny],
        url_path='password/reset/confirm',
    )
    def password_reset_confirm(self, request):
        from django.contrib.auth.password_validation import validate_password
        from django.core.exceptions import ValidationError as DjangoValidationError

        serializer = PasswordResetConfirmSerializer(
            data=request.data,
            context={'request': request},
        )
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        email = serializer.validated_data['email'].strip().lower()
        challenge_id = serializer.validated_data['challenge_id']
        code = serializer.validated_data['code']
        new_password = serializer.validated_data['new_password']
        otp = verify_otp(
            challenge_id=challenge_id,
            code=code,
            purpose=EmailOtp.Purpose.PASSWORD_RESET,
            email=email,
        )
        user = otp.user or User.objects.filter(email__iexact=email).first()
        if user is None:
            return Response(
                {'detail': _('Invalid or expired code.')},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            validate_password(new_password, user=user)
        except DjangoValidationError as exc:
            return Response(
                {'new_password': list(exc.messages)},
                status=status.HTTP_400_BAD_REQUEST,
            )
        user.set_password(new_password)
        user.save(update_fields=['password'])
        return Response({'detail': _('Password reset complete.')}, status=status.HTTP_200_OK)

    @action(
        detail=False,
        methods=['post'],
        permission_classes=[permissions.IsAuthenticated],
        url_path='logout',
    )
    def logout(self, request):
        try:
            refresh_token = request.data.get('refresh')
            if refresh_token:
                token = RefreshToken(refresh_token)
                token.blacklist()
            auth_logout(request)
            return Response(
                {'message': 'Successfully logged out'},
                status=status.HTTP_200_OK,
            )
        except Exception:
            return Response(
                {'error': 'Invalid token'},
                status=status.HTTP_400_BAD_REQUEST,
            )

    @action(
        detail=False,
        methods=['post'],
        permission_classes=[permissions.AllowAny],
        url_path='google',
    )
    def google_auth(self, request):
        """Exchange a Google ID token for Vaxiil JWTs. Set GOOGLE_OAUTH_CLIENT_ID in env."""
        serializer = GoogleAuthSerializer(
            data=request.data,
            context={'request': request},
        )
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        raw = serializer.validated_data['id_token']
        client_id = config('GOOGLE_OAUTH_CLIENT_ID', default='')
        if not client_id:
            return Response(
                {'error': 'Google sign-in is not configured on the server'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        try:
            idinfo = id_token.verify_oauth2_token(
                raw, google_requests.Request(), client_id
            )
        except ValueError as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

        email = idinfo.get('email')
        if not email:
            return Response(
                {'error': 'Token has no email'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = User.objects.filter(email=email).first()
        created = False
        if user is None:
            terms, privacy = require_current_acceptance_versions(
                accepted_terms_version=serializer.validated_data.get(
                    'accepted_terms_version'
                ),
                accepted_privacy_version=serializer.validated_data.get(
                    'accepted_privacy_version'
                ),
            )
            user = User(
                email=email,
                username=_unique_username_from_email(email),
                first_name=idinfo.get('given_name', '') or '',
                last_name=idinfo.get('family_name', '') or '',
                role=User.UserRole.CLIENT,
            )
            user.set_unusable_password()
            user.save()
            user.generate_trust_alias()
            record_acceptance(
                user=user,
                terms_document=terms,
                privacy_document=privacy,
                source=UserLegalAcceptance.Source.GOOGLE_SIGNUP,
                request=request,
            )
            created = True

        auth_login(request, user)
        user = _user_for_profile(user)
        refresh = RefreshToken.for_user(user)
        return Response({
            'user': UserProfileSerializer(user, context={'request': request}).data,
            'refresh': str(refresh),
            'access': str(refresh.access_token),
            'created': created,
        }, status=status.HTTP_200_OK)


class LegalDocumentView(APIView):
    """Public current Terms or Privacy body by locale."""

    permission_classes = [permissions.AllowAny]

    def get(self, request, document_type=None):
        type_map = {
            'terms': LegalDocumentVersion.DocumentType.TERMS,
            'privacy': LegalDocumentVersion.DocumentType.PRIVACY,
        }
        dtype = type_map.get((document_type or '').lower())
        if dtype is None:
            return Response(
                {'detail': _('Unknown document type.')},
                status=status.HTTP_404_NOT_FOUND,
            )
        doc = (
            LegalDocumentVersion.objects.filter(document_type=dtype, is_current=True)
            .order_by('-effective_at')
            .first()
        )
        if doc is None:
            return Response(
                {'detail': _('Document not found.')},
                status=status.HTTP_404_NOT_FOUND,
            )
        lang = request.query_params.get('lang') or get_language_from_request(request)
        return Response(
            {
                'id': str(doc.id),
                'document_type': doc.document_type,
                'version': doc.version,
                'effective_at': doc.effective_at,
                'summary': summary_for_locale(doc, lang),
                'body': body_for_locale(doc, lang),
                'locale': (lang or 'en')[:2],
            }
        )


class CurrentUserViewSet(viewsets.GenericViewSet):
    """Profile, verification, trust alias, avatar."""

    permission_classes = [permissions.IsAuthenticated]

    @action(detail=False, methods=['get', 'put'], url_path='profile')
    def profile(self, request):
        if request.method == 'GET':
            user = _user_for_profile(request.user)
            serializer = UserProfileSerializer(user, context={'request': request})
            return Response(serializer.data)

        user = _user_for_profile(request.user)
        serializer = UserProfileSerializer(
            user,
            data=request.data,
            partial=True,
            context={'request': request},
        )
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @action(
        detail=False,
        methods=['post'],
        parser_classes=[MultiPartParser, FormParser],
        url_path='verify',
    )
    def submit_verification(self, request):
        serializer = UserVerificationSerializer(
            request.user,
            data=request.data,
            partial=True,
        )
        if serializer.is_valid():
            serializer.save()
            return Response({
                'message': 'Verification documents submitted successfully',
            }, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=False, methods=['get'], url_path='generate-alias')
    def generate_trust_alias(self, request):
        if request.user.trust_alias:
            return Response(
                {'trust_alias': request.user.trust_alias},
                status=status.HTTP_200_OK,
            )

        alias = request.user.generate_trust_alias()
        return Response({'trust_alias': alias}, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['post'], url_path='regenerate-alias')
    def regenerate_trust_alias(self, request):
        alias = request.user.regenerate_trust_alias()
        return Response({'trust_alias': alias}, status=status.HTTP_200_OK)

    @action(
        detail=False,
        methods=['post'],
        parser_classes=[MultiPartParser, FormParser],
        url_path='avatar',
    )
    def upload_avatar(self, request):
        """Multipart upload: field name `avatar`."""
        if 'avatar' not in request.FILES:
            return Response(
                {'error': 'avatar file is required'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        request.user.avatar = request.FILES['avatar']
        request.user.save()
        user = _user_for_profile(request.user)
        serializer = UserProfileSerializer(user, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)
