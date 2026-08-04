import { HttpErrorResponse } from '@angular/common/http';

export interface ApiError {
  message: string;
  /** Full sanitized message before truncation (for tooltips). */
  fullMessage?: string;
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

/** Max characters shown in payment / toast error banners. */
export const API_ERROR_DISPLAY_MAX = 200;

function firstString(value: unknown): string | null {
  if (typeof value === 'string' && value.trim()) {
    return value;
  }
  if (Array.isArray(value) && value.length > 0 && typeof value[0] === 'string') {
    return value[0];
  }
  return null;
}

function looksLikeHtml(text: string): boolean {
  const t = text.trim().toLowerCase();
  if (t.startsWith('<!doctype') || t.startsWith('<html')) {
    return true;
  }
  const tags = text.match(/<\/?[a-z][\w:-]*\b[^>]*>/gi);
  return (tags?.length ?? 0) >= 2;
}

/** Strip HTML tags and collapse whitespace for safe UI display. */
export function sanitizeErrorMessage(raw: string): string {
  let text = raw ?? '';
  if (looksLikeHtml(text)) {
    text = text
      .replace(/<script[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style[\s\S]*?<\/style>/gi, ' ')
      .replace(/<[^>]+>/g, ' ')
      .replace(/&nbsp;/gi, ' ')
      .replace(/&amp;/gi, '&')
      .replace(/&lt;/gi, '<')
      .replace(/&gt;/gi, '>')
      .replace(/&quot;/gi, '"')
      .replace(/&#39;/gi, "'");
  }
  return text.replace(/\s+/g, ' ').trim();
}

/** Truncate for banners; returns display + full sanitized text. */
export function truncateErrorMessage(
  raw: string,
  max = API_ERROR_DISPLAY_MAX,
): { display: string; full: string } {
  const full = sanitizeErrorMessage(raw);
  if (full.length <= max) {
    return { display: full, full };
  }
  return { display: `${full.slice(0, Math.max(0, max - 1)).trimEnd()}…`, full };
}

/** Normalize DRF / network errors for UI display. */
export function mapHttpError(
  error: unknown,
  messages: ApiErrorMessages = DEFAULT_MESSAGES,
): ApiError {
  if (!(error instanceof HttpErrorResponse)) {
    const raw =
      error instanceof Error ? error.message : messages.unexpected;
    const { display, full } = truncateErrorMessage(raw);
    return {
      message: display,
      fullMessage: full !== display ? full : undefined,
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

  const { display, full } = truncateErrorMessage(message);
  return {
    message: display,
    fullMessage: full !== display ? full : undefined,
    status: error.status,
    fieldErrors,
    code: bodyCode || (error.status === 401 ? 'UNAUTHORIZED' : undefined),
  };
}
