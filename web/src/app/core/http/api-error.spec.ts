import { HttpErrorResponse } from '@angular/common/http';

import { mapHttpError } from './api-error';

describe('mapHttpError', () => {
  it('maps detail string', () => {
    const error = new HttpErrorResponse({
      status: 400,
      error: { detail: 'Invalid credentials' },
    });
    expect(mapHttpError(error).message).toBe('Invalid credentials');
  });

  it('maps field errors', () => {
    const error = new HttpErrorResponse({
      status: 400,
      error: { email: ['Enter a valid email.'] },
    });
    const mapped = mapHttpError(error);
    expect(mapped.fieldErrors['email']).toEqual(['Enter a valid email.']);
    expect(mapped.message).toBe('Enter a valid email.');
  });

  it('maps network failure', () => {
    const error = new HttpErrorResponse({ status: 0, statusText: 'Unknown Error' });
    expect(mapHttpError(error).message).toContain('Unable to reach');
  });
});
