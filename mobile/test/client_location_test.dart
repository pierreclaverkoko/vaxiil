import 'package:flutter_test/flutter_test.dart';
import 'package:vaxiil_mobile/core/utils/client_location.dart';

void main() {
  test('ClientLocationSnapshot.toJson includes accuracy when set', () {
    const snap = ClientLocationSnapshot(
      latitude: 4.3276,
      longitude: 15.3136,
      accuracyMeters: 12.5,
    );
    expect(snap.toJson(), {
      'client_latitude': '4.327600',
      'client_longitude': '15.313600',
      'client_location_accuracy_m': 12.5,
    });
  });

  test('ClientLocationSnapshot.toJson omits accuracy when null', () {
    const snap = ClientLocationSnapshot(
      latitude: 1,
      longitude: 2,
    );
    expect(snap.toJson().containsKey('client_location_accuracy_m'), isFalse);
  });
}
