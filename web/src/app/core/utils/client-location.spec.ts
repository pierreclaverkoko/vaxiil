import { afterEach, describe, expect, it, vi } from 'vitest';

import {
  optionalClientLocation,
  withOptionalClientLocation,
} from './client-location';

describe('client-location', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('returns null when geolocation is unavailable', async () => {
    vi.stubGlobal('navigator', {});
    await expect(optionalClientLocation()).resolves.toBeNull();
  });

  it('returns null when permission is not granted', async () => {
    vi.stubGlobal('navigator', {
      geolocation: { getCurrentPosition: vi.fn() },
      permissions: {
        query: vi.fn().mockResolvedValue({ state: 'prompt' }),
      },
    });
    await expect(optionalClientLocation()).resolves.toBeNull();
  });

  it('maps coords when permission is granted', async () => {
    const getCurrentPosition = vi.fn((success: PositionCallback) => {
      success({
        coords: {
          latitude: 4.3276,
          longitude: 15.3136,
          accuracy: 10,
          altitude: null,
          altitudeAccuracy: null,
          heading: null,
          speed: null,
          toJSON: () => ({}),
        },
        timestamp: Date.now(),
        toJSON: () => ({}),
      });
    });
    vi.stubGlobal('navigator', {
      geolocation: { getCurrentPosition },
      permissions: {
        query: vi.fn().mockResolvedValue({ state: 'granted' }),
      },
    });

    const loc = await optionalClientLocation();
    expect(loc).toEqual({
      client_latitude: '4.327600',
      client_longitude: '15.313600',
      client_location_accuracy_m: 10,
    });
  });

  it('merges location into body when available', async () => {
    const getCurrentPosition = vi.fn((success: PositionCallback) => {
      success({
        coords: {
          latitude: 1,
          longitude: 2,
          accuracy: 5,
          altitude: null,
          altitudeAccuracy: null,
          heading: null,
          speed: null,
          toJSON: () => ({}),
        },
        timestamp: Date.now(),
        toJSON: () => ({}),
      });
    });
    vi.stubGlobal('navigator', {
      geolocation: { getCurrentPosition },
      permissions: {
        query: vi.fn().mockResolvedValue({ state: 'granted' }),
      },
    });

    const body = await withOptionalClientLocation({ reason: 'x' });
    expect(body['reason']).toBe('x');
    expect(body['client_latitude']).toBe('1.000000');
    expect(body['client_longitude']).toBe('2.000000');
  });
});
