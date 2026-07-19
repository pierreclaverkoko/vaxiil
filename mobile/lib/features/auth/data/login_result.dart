import 'package:vaxiil_mobile/features/auth/domain/entities/auth_user.dart';

/// Result of `POST auth/login/` — either a full session or an email OTP challenge.
sealed class LoginResult {
  const LoginResult();
}

class LoginSessionResult extends LoginResult {
  const LoginSessionResult(this.user);

  final AuthUser user;
}

class LoginOtpChallengeResult extends LoginResult {
  const LoginOtpChallengeResult({
    required this.challengeId,
    required this.emailHint,
  });

  final String challengeId;
  final String emailHint;
}
