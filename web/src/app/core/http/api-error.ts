import { HttpErrorResponse } from '@angular/common/http';

export interface ApiError {
  message: string;
  status: number | null;
  fieldErrors: Record<string, string[]>;
  code?: string;
}

export interface ApiErrorMessages {
  unexpected: string;
  requestFailed: string;
  network: string;
}

const DEFAULT_MESSAGES: ApiErrorMessages = {
  unexpected: 'Unexpected error',
  requestFailed: 'Request failed',
  network: 'Unable to reach the server. Check your connection.',
};

function firstString(value: unknown): string | null {
  if (typeof value === 'string' && value.trim()) {
    return value;
  }
  if (Array.isArray(value) && value.length > 0 && typeof value[0] === 'string') {
    return value[0];
  }
  return null;
}

/** Normalize DRF / network errors for UI display. */
export function mapHttpError(
  error: unknown,
  messages: ApiErrorMessages = DEFAULT_MESSAGES,
): ApiError {
  if (!(error instanceof HttpErrorResponse)) {
    return {
      message: error instanceof Error ? error.message : messages.unexpected,
      status: null,
      fieldErrors: {},
      code: 'UNKNOWN',
    };
  }

  const fieldErrors: Record<string, string[]> = {};
  const data = error.error;
  let message = error.statusText || messages.requestFailed;
  let bodyCode: string | null = null;

  if (typeof data === 'string' && data.trim()) {
    message = data;
  } else if (data && typeof data === 'object' && !Array.isArray(data)) {
    const body = data as Record<string, unknown>;
    const detail = firstString(body['detail']);
    const nonField = firstString(body['non_field_errors']);
    bodyCode = firstString(body['code']);
    if (detail) {
      message = detail;
    } else if (nonField) {
      message = nonField;
    }

    for (const [key, value] of Object.entries(body)) {
      if (key === 'detail' || key === 'non_field_errors' || key === 'code') {
        continue;
      }
      if (Array.isArray(value)) {
        const msgs = value.filter((v): v is string => typeof v === 'string');
        if (msgs.length) {
          fieldErrors[key] = msgs;
        }
      } else if (typeof value === 'string') {
        fieldErrors[key] = [value];
      }
    }

    if (!detail && !nonField && Object.keys(fieldErrors).length > 0) {
      const first = Object.values(fieldErrors)[0]?.[0];
      if (first) {
        message = first;
      }
    }
  }

  if (error.status === 0) {
    message = messages.network;
  }

  return {
    message,
    status: error.status,
    fieldErrors,
    code: bodyCode || (error.status === 401 ? 'UNAUTHORIZED' : undefined),
  };
}
