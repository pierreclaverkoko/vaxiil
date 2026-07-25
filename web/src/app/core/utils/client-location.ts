/** Optional GPS snapshot for audit metadata on sensitive API posts. */
export interface ClientLocationSnapshot {
  client_latitude: string;
  client_longitude: string;
  client_location_accuracy_m?: number;
}

/**
 * Returns current browser location only when geolocation permission is already
 * granted. Never prompts and never throws — resolves null otherwise.
 */
export async function optionalClientLocation(
  timeoutMs = 4000,
): Promise<ClientLocationSnapshot | null> {
  if (typeof navigator === 'undefined' || !navigator.geolocation) {
    return null;
  }

  // Skip unless permission is already granted (no prompt on payment/booking actions).
  const permissions = navigator.permissions;
  if (!permissions?.query) {
    return null;
  }
  try {
    const status = await permissions.query({
      name: 'geolocation' as PermissionName,
    });
    if (status.state !== 'granted') {
      return null;
    }
  } catch {
    return null;
  }

  try {
    const position = await new Promise<GeolocationPosition>((resolve, reject) => {
      navigator.geolocation.getCurrentPosition(resolve, reject, {
        enableHighAccuracy: false,
        timeout: timeoutMs,
        maximumAge: 60_000,
      });
    });
    const { latitude, longitude, accuracy } = position.coords;
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      return null;
    }
    const snapshot: ClientLocationSnapshot = {
      client_latitude: latitude.toFixed(6),
      client_longitude: longitude.toFixed(6),
    };
    if (Number.isFinite(accuracy) && accuracy >= 0) {
      snapshot.client_location_accuracy_m = accuracy;
    }
    return snapshot;
  } catch {
    return null;
  }
}

/** Merge optional GPS fields into an API body object. */
export async function withOptionalClientLocation(
  body: Record<string, unknown> = {},
): Promise<Record<string, unknown>> {
  const loc = await optionalClientLocation();
  if (!loc) {
    return body;
  }
  return { ...body, ...loc };
}
