import 'package:local_auth/local_auth.dart';

class BiometricService {
  BiometricService() : _auth = LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> get canAuthenticate async {
    try {
      final bio = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      return bio || supported;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> get availableBiometrics =>
      _auth.getAvailableBiometrics();

  Future<bool> authenticate({String reason = 'Unlock Vaxiil'}) async {
    try {
      return _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
