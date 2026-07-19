import { ServiceListItem } from '@/models/service-catalog';

export const DISCOVER_RECENT_CAP = 4;

export interface DiscoverServiceSections {
  showFeatured: boolean;
  featured: ServiceListItem[];
  recent: ServiceListItem[];
  showViewAll: boolean;
}

/**
 * Build featured / recent sections for the discover page.
 * - totalCount <= 4: recent only (all recent items), no featured, no view-all
 * - totalCount > 4: featured if non-empty; recent capped at 4 with view-all;
 *   when featured is shown, dedupe those ids from recent
 */
export function buildDiscoverServiceSections(input: {
  totalCount: number;
  featured: ServiceListItem[];
  recent: ServiceListItem[];
}): DiscoverServiceSections {
  const { totalCount, featured, recent } = input;

  if (totalCount <= DISCOVER_RECENT_CAP) {
    return {
      showFeatured: false,
      featured: [],
      recent,
      showViewAll: false,
    };
  }

  const showFeatured = featured.length > 0;
  const featuredIds = new Set(featured.map((s) => s.id));
  const recentDeduped = showFeatured
    ? recent.filter((s) => !featuredIds.has(s.id))
    : recent;

  return {
    showFeatured,
    featured: showFeatured ? featured : [],
    recent: recentDeduped.slice(0, DISCOVER_RECENT_CAP),
    showViewAll: true,
  };
}
