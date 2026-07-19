/** API shape from DRF ChoiceEnumField: `{ value, title, css }`. */
export interface ChoiceEnum {
  value: string | number;
  title: string;
  css?: string | null;
}

export type ChoiceEnumCss =
  | 'default'
  | 'primary'
  | 'secondary'
  | 'success'
  | 'warning'
  | 'danger'
  | 'info';

const KNOWN_CSS = new Set<string>([
  'default',
  'primary',
  'secondary',
  'success',
  'warning',
  'danger',
  'info',
]);

/** Normalize API `css` to a known token; unknown values fall back to `default`. */
export function normalizeChoiceEnumCss(css: string | null | undefined): ChoiceEnumCss {
  const raw = (css ?? 'default').toLowerCase();
  return KNOWN_CSS.has(raw) ? (raw as ChoiceEnumCss) : 'default';
}

/** Parse DRF choice payload: object `{ value, title, css }` or bare string. */
export function parseChoiceEnum(raw: unknown): ChoiceEnum | null {
  if (raw == null) {
    return null;
  }
  if (typeof raw === 'string') {
    return { value: raw, title: raw };
  }
  if (typeof raw === 'object' && !Array.isArray(raw)) {
    const m = raw as Record<string, unknown>;
    const value = m['value'] != null ? String(m['value']) : '';
    const title = m['title'] != null ? String(m['title']) : value;
    const css = typeof m['css'] === 'string' ? m['css'] : null;
    return { value, title, css };
  }
  return null;
}

export function choiceEnumToJson(choice: ChoiceEnum | null | undefined): Record<string, unknown> | null {
  if (!choice) {
    return null;
  }
  return { value: choice.value, title: choice.title, css: choice.css ?? null };
}
