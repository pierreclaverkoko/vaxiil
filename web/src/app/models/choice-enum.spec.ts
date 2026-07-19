import { normalizeChoiceEnumCss, parseChoiceEnum } from './choice-enum';

describe('parseChoiceEnum', () => {
  it('parses object payloads', () => {
    expect(parseChoiceEnum({ value: 'CLIENT', title: 'Client', css: 'primary' })).toEqual({
      value: 'CLIENT',
      title: 'Client',
      css: 'primary',
    });
  });

  it('parses bare strings', () => {
    expect(parseChoiceEnum('CLIENT')).toEqual({ value: 'CLIENT', title: 'CLIENT' });
  });

  it('returns null for nullish input', () => {
    expect(parseChoiceEnum(null)).toBeNull();
    expect(parseChoiceEnum(undefined)).toBeNull();
  });
});

describe('normalizeChoiceEnumCss', () => {
  it('keeps known tokens', () => {
    expect(normalizeChoiceEnumCss('success')).toBe('success');
  });

  it('falls back for unknown tokens', () => {
    expect(normalizeChoiceEnumCss('neon')).toBe('default');
  });
});
