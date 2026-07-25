import 'package:location/location.dart';

/// Optional GPS coordinates for audit metadata on sensitive API posts.
class ClientLocationSnapshot {
  const ClientLocationSnapshot({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;

  Map<String, dynamic> toJson() => {
        'client_latitude': latitude.toStringAsFixed(6),
        'client_longitude': longitude.toStringAsFixed(6),
        if (accuracyMeters != null)
          'client_location_accuracy_m': accuracyMeters,
      };
}

/// Returns current location when permission is already granted.
/// Never prompts and never throws — returns null when unavailable or denied.
Future<ClientLocationSnapshot?> optionalClientLocation() async {
  try {
    final location = Location();
    final serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) return null;

    final permission = await location.hasPermission();
    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.grantedLimited) {
      return null;
    }

    final data = await location.getLocation();
    final lat = data.latitude;
    final lng = data.longitude;
    if (lat == null || lng == null) return null;
    return ClientLocationSnapshot(
      latitude: lat,
      longitude: lng,
      accuracyMeters: data.accuracy,
    );
  } on Object {
    return null;
  }
}

/// Merge optional GPS fields into an API body map.
Future<Map<String, dynamic>> withOptionalClientLocation(
  Map<String, dynamic> body,
) async {
  final loc = await optionalClientLocation();
  if (loc == null) return body;
  return {...body, ...loc.toJson()};
}
