import {
  formatServicePrice,
  parseLocationTypeCodes,
  parseServiceDetail,
  parseServiceListItem,
} from './service-catalog';

describe('formatServicePrice', () => {
  it('formats amounts with two fraction digits', () => {
    expect(formatServicePrice(75.5, 'USD', 'en-US')).toBe('$75.50');
    expect(formatServicePrice(75, 'EUR', 'en-US')).toContain('75.00');
  });
});

describe('parseLocationTypeCodes', () => {
  it('normalizes and dedupes venue codes', () => {
    expect(parseLocationTypeCodes(['o', 'H', 'x', 'H', 'V'])).toEqual(['O', 'H', 'V']);
    expect(parseLocationTypeCodes(null)).toEqual([]);
  });
});

describe('parseServiceListItem', () => {
  it('parses catalog list rows with nested org and currency', () => {
    const item = parseServiceListItem({
      id: 'svc-1',
      name: 'Deep Tissue',
      description: 'Relaxing massage',
      price_min: '80',
      price_max: 120,
      featured: true,
      organization: { id: 'org-1', name: 'Zen Studio' },
      sub_category: {
        id: 'sub-1',
        name: 'Massage',
        category: { id: 'cat-1', name: 'Bodywork', icon: 'spa' },
      },
      accepted_currency: {
        currency: { code: 'EUR' },
      },
      city: { id: 'c1', name: 'Paris', name_std: 'Paris' },
      effective_location_types: ['O', 'V'],
      average_rating: 4.8,
      rating_count: 12,
    });

    expect(item.id).toBe('svc-1');
    expect(item.name).toBe('Deep Tissue');
    expect(item.priceMin).toBe(80);
    expect(item.priceMax).toBe(120);
    expect(item.currency).toBe('EUR');
    expect(item.organization.name).toBe('Zen Studio');
    expect(item.subCategory.category.name).toBe('Bodywork');
    expect(item.averageRating).toBe(4.8);
    expect(item.featured).toBe(true);
    expect(item.cityName).toBe('Paris');
    expect(item.effectiveLocationTypes).toEqual(['O', 'V']);
  });
});

describe('parseServiceDetail', () => {
  it('parses accepted and effective location types', () => {
    const detail = parseServiceDetail({
      id: 'svc-1',
      name: 'Deep Tissue',
      description: 'Relaxing massage',
      price_min: 80,
      price_max: 120,
      accepted_location_types: ['O', 'V'],
      effective_location_types: ['O', 'V'],
      organization: {
        id: 'org-1',
        name: 'Zen Studio',
        accepted_location_types: ['O', 'H', 'V', 'B'],
      },
      sub_category: {
        id: 'sub-1',
        name: 'Massage',
        category: { id: 'cat-1', name: 'Bodywork', icon: 'spa' },
      },
      accepted_currency: { currency: { code: 'EUR' } },
      variants: [],
    });

    expect(detail.acceptedLocationTypes).toEqual(['O', 'V']);
    expect(detail.effectiveLocationTypes).toEqual(['O', 'V']);
    expect(detail.organization.acceptedLocationTypes).toEqual(['O', 'H', 'V', 'B']);
  });
});
