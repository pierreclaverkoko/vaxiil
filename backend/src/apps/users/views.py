from decouple import config
from django.contrib.auth import login, logout
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token
from rest_framework import status, permissions
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken

from .models import User, UserRole
from .serializers import (
    UserRegistrationSerializer,
    UserLoginSerializer,
    UserProfileSerializer,
    UserVerificationSerializer
)


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def register(request):
    serializer = UserRegistrationSerializer(data=request.data)
    if serializer.is_valid():
        user = serializer.save()
        refresh = RefreshToken.for_user(user)
        return Response({
            'user': UserProfileSerializer(user, context={'request': request}).data,
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        }, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def login_view(request):
    serializer = UserLoginSerializer(data=request.data)
    if serializer.is_valid():
        user = serializer.validated_data['user']
        login(request, user)
        refresh = RefreshToken.for_user(user)
        return Response({
            'user': UserProfileSerializer(user, context={'request': request}).data,
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        }, status=status.HTTP_200_OK)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def logout_view(request):
    try:
        refresh_token = request.data.get('refresh')
        if refresh_token:
            token = RefreshToken(refresh_token)
            token.blacklist()
        logout(request)
        return Response(
            {'message': 'Successfully logged out'},
            status=status.HTTP_200_OK
        )
    except Exception:
        return Response(
            {'error': 'Invalid token'},
            status=status.HTTP_400_BAD_REQUEST
        )


@api_view(['GET', 'PUT'])
@permission_classes([permissions.IsAuthenticated])
def profile(request):
    if request.method == 'GET':
        serializer = UserProfileSerializer(request.user, context={'request': request})
        return Response(serializer.data)
    
    elif request.method == 'PUT':
        serializer = UserProfileSerializer(
            request.user,
            data=request.data,
            partial=True,
            context={'request': request},
        )
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def submit_verification(request):
    serializer = UserVerificationSerializer(
        request.user,
        data=request.data,
        partial=True
    )
    if serializer.is_valid():
        serializer.save()
        return Response({
            'message': 'Verification documents submitted successfully'
        }, status=status.HTTP_200_OK)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def generate_trust_alias(request):
    if request.user.trust_alias:
        return Response({
            'trust_alias': request.user.trust_alias
        }, status=status.HTTP_200_OK)
    
    alias = request.user.generate_trust_alias()
    return Response({
        'trust_alias': alias
    }, status=status.HTTP_201_CREATED)


def _unique_username_from_email(email: str) -> str:
    base = email.split('@')[0][:30] or 'user'
    username = base
    n = 0
    while User.objects.filter(username=username).exists():
        n += 1
        username = f'{base}{n}'
    return username


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def google_auth(request):
    """Exchange a Google ID token for Vaxiil JWTs. Set GOOGLE_OAUTH_CLIENT_ID in env."""
    raw = request.data.get('id_token')
    if not raw:
        return Response({'error': 'id_token is required'}, status=status.HTTP_400_BAD_REQUEST)

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
        return Response({'error': 'Token has no email'}, status=status.HTTP_400_BAD_REQUEST)

    user = User.objects.filter(email=email).first()
    if user is None:
        user = User(
            email=email,
            username=_unique_username_from_email(email),
            first_name=idinfo.get('given_name', '') or '',
            last_name=idinfo.get('family_name', '') or '',
            role=UserRole.CLIENT,
        )
        user.set_unusable_password()
        user.save()
        user.generate_trust_alias()

    login(request, user)
    refresh = RefreshToken.for_user(user)
    return Response({
        'user': UserProfileSerializer(user, context={'request': request}).data,
        'refresh': str(refresh),
        'access': str(refresh.access_token),
    }, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
@parser_classes([MultiPartParser, FormParser])
def upload_avatar(request):
    """Multipart upload: field name `avatar`."""
    if 'avatar' not in request.FILES:
        return Response({'error': 'avatar file is required'}, status=status.HTTP_400_BAD_REQUEST)
    request.user.avatar = request.FILES['avatar']
    request.user.save()
    serializer = UserProfileSerializer(request.user, context={'request': request})
    return Response(serializer.data, status=status.HTTP_200_OK)
