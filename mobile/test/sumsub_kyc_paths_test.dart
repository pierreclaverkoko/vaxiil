import 'package:flutter_test/flutter_test.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';

void main() {
  test('Sumsub KYC API paths are under auth/', () {
    expect(
      AppConstants.authSumsubAccessTokenPath,
      'auth/kyc/sumsub/access-token/',
    );
    expect(
      AppConstants.authSumsubWebsdkLinkPath,
      'auth/kyc/sumsub/websdk-link/',
    );
    expect(
      AppConstants.authSumsubReturnPath,
      'auth/kyc/sumsub/return/',
    );
  });

  test('resolveKycRedirectOrigin does not throw without http base', () {
    // VM tests use a file: Uri.base; should return empty without dart-define.
    expect(() => AppConstants.resolveKycRedirectOrigin(), returnsNormally);
  });
}
