import 'package:flutter_test/flutter_test.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';

void main() {
  test('turnstile site key defaults to provisioned widget key', () {
    expect(AppConstants.turnstileSiteKey, '0x4AAAAAAD9kzYulPy5lqUue');
  });
}
