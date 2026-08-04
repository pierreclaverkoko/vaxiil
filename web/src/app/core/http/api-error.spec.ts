import { HttpErrorResponse } from '@angular/common/http';

import {
  mapHttpError,
  sanitizeErrorMessage,
  truncateErrorMessage,
} from './api-error';

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

  it('passes through body code', () => {
    const error = new HttpErrorResponse({
      status: 400,
      error: { detail: 'Sumsub redirect JWT has expired.', code: 'sumsub_redirect_jwt_expired' },
    });
    const mapped = mapHttpError(error);
    expect(mapped.message).toBe('Sumsub redirect JWT has expired.');
    expect(mapped.code).toBe('sumsub_redirect_jwt_expired');
  });

  it('strips HTML error bodies and truncates', () => {
    const html =
      '<!DOCTYPE html><html><body><h1>Server Error (500)</h1><p>' +
      'x'.repeat(300) +
      '</p></body></html>';
    const error = new HttpErrorResponse({ status: 500, error: html });
    const mapped = mapHttpError(error);
    expect(mapped.message).not.toContain('<');
    expect(mapped.message.endsWith('…')).toBe(true);
    expect(mapped.message.length).toBeLessThanOrEqual(200);
    expect(mapped.fullMessage).toBeTruthy();
    expect(mapped.fullMessage!.length).toBeGreaterThan(mapped.message.length);
  });
});

describe('sanitizeErrorMessage / truncateErrorMessage', () => {
  it('leaves plain text alone', () => {
    expect(sanitizeErrorMessage('  Hello world  ')).toBe('Hello world');
  });

  it('strips multi-tag HTML', () => {
    expect(sanitizeErrorMessage('<p>Bad <b>gateway</b></p>')).toBe('Bad gateway');
  });

  it('truncates with ellipsis', () => {
    const { display, full } = truncateErrorMessage('a'.repeat(250), 50);
    expect(display.length).toBeLessThanOrEqual(50);
    expect(display.endsWith('…')).toBe(true);
    expect(full.length).toBe(250);
  });
});
