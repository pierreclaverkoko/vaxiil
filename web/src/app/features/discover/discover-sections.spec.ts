import { ServiceListItem } from '@/models/service-catalog';

import { buildDiscoverServiceSections } from './discover-sections';

function svc(id: string, featured = false): ServiceListItem {
  return {
    id,
    name: id,
    description: '',
    priceMin: 10,
    priceMax: 10,
    currency: 'USD',
    featured,
    organization: { id: 'o1', name: 'Org' },
    subCategory: {
      id: 'sub',
      name: 'Sub',
      category: { id: 'cat', name: 'Cat', icon: 'sparkles' },
    },
    primaryImage: null,
    averageRating: null,
    ratingCount: null,
    isFavorite: false,
  };
}

describe('buildDiscoverServiceSections', () => {
  it('shows only recent when total <= 4, hiding featured and view-all', () => {
    const featured = [svc('f1', true)];
    const recent = [svc('r1'), svc('r2'), svc('f1', true)];
    const result = buildDiscoverServiceSections({
      totalCount: 3,
      featured,
      recent,
    });
    expect(result.showFeatured).toBe(false);
    expect(result.featured).toEqual([]);
    expect(result.recent).toEqual(recent);
    expect(result.showViewAll).toBe(false);
  });

  it('shows featured and capped recent with view-all when total > 4', () => {
    const featured = [svc('f1', true), svc('f2', true)];
    const recent = [
      svc('r1'),
      svc('f1', true),
      svc('r2'),
      svc('r3'),
      svc('r4'),
      svc('r5'),
    ];
    const result = buildDiscoverServiceSections({
      totalCount: 10,
      featured,
      recent,
    });
    expect(result.showFeatured).toBe(true);
    expect(result.featured.map((s) => s.id)).toEqual(['f1', 'f2']);
    expect(result.recent.map((s) => s.id)).toEqual(['r1', 'r2', 'r3', 'r4']);
    expect(result.showViewAll).toBe(true);
  });

  it('hides featured block when featured list is empty', () => {
    const recent = [svc('r1'), svc('r2'), svc('r3'), svc('r4'), svc('r5')];
    const result = buildDiscoverServiceSections({
      totalCount: 5,
      featured: [],
      recent,
    });
    expect(result.showFeatured).toBe(false);
    expect(result.recent.map((s) => s.id)).toEqual(['r1', 'r2', 'r3', 'r4']);
    expect(result.showViewAll).toBe(true);
  });
});
