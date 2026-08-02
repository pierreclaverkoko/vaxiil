import {
  AVAILABLE_HEROICON_NAMES,
  heroiconToMaterialSymbol,
} from './heroicon-to-material';

describe('heroiconToMaterialSymbol', () => {
  it('maps known heroicon names', () => {
    expect(heroiconToMaterialSymbol('sparkles')).toBe('auto_awesome');
    expect(heroiconToMaterialSymbol('squares-2x2')).toBe('grid_view');
  });

  it('passes through plain material-style names', () => {
    expect(heroiconToMaterialSymbol('self_improvement')).toBe('self_improvement');
  });

  it('falls back for empty or unknown kebab names', () => {
    expect(heroiconToMaterialSymbol('')).toBe('spa');
    expect(heroiconToMaterialSymbol(null)).toBe('spa');
    expect(heroiconToMaterialSymbol('totally-unknown-icon')).toBe('spa');
    expect(heroiconToMaterialSymbol('', 'category')).toBe('category');
  });
});

describe('AVAILABLE_HEROICON_NAMES', () => {
  it('is a non-empty sorted list of mapped names', () => {
    expect(AVAILABLE_HEROICON_NAMES.length).toBeGreaterThan(0);
    expect([...AVAILABLE_HEROICON_NAMES]).toEqual(
      [...AVAILABLE_HEROICON_NAMES].sort((a, b) => a.localeCompare(b)),
    );
    expect(AVAILABLE_HEROICON_NAMES).toContain('sparkles');
    expect(AVAILABLE_HEROICON_NAMES).toContain('heart');
  });
});
