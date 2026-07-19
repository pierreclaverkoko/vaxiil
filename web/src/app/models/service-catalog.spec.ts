import { parseServiceListItem } from './service-catalog';

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
  });
});
