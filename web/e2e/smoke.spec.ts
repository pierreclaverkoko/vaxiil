import { expect, test, type Page } from '@playwright/test';

const API = '**/api/v1/**';

async function mockAuthAndCatalog(page: Page): Promise<void> {
  await page.route(API, async (route) => {
    const url = route.request().url();
    const method = route.request().method();

    if (url.includes('/auth/login/') && method === 'POST') {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          access: 'e2e-access',
          refresh: 'e2e-refresh',
          user: {
            id: 'u1',
            email: 'guest@example.com',
            first_name: 'Guest',
            last_name: 'User',
            is_staff: false,
            organization_memberships: [
              {
                id: 'm1',
                organization: { id: 'o1', name: 'Zen Studio', logo: null },
                role: { value: 'O', title: 'Owner', css: 'primary' },
              },
            ],
            verification_status: { value: 'V', title: 'Verified', css: 'success' },
          },
        }),
      });
      return;
    }

    if (url.includes('/auth/profile/') && method === 'GET') {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          id: 'u1',
          email: 'guest@example.com',
          first_name: 'Guest',
          last_name: 'User',
          is_staff: false,
          organization_memberships: [
            {
              id: 'm1',
              organization: { id: 'o1', name: 'Zen Studio', logo: null },
              role: { value: 'O', title: 'Owner', css: 'primary' },
            },
          ],
          verification_status: { value: 'V', title: 'Verified', css: 'success' },
        }),
      });
      return;
    }

    if (url.includes('/services/categories/')) {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([
          { id: 'c1', name: 'Wellness', description: '', icon: 'spa', sort_order: 0 },
        ]),
      });
      return;
    }

    if (url.includes('/services/') && !url.includes('/book') && method === 'GET') {
      const serviceDetail = {
        id: 's1',
        name: 'Forest Immersion',
        description: 'A calm walk among the trees.',
        price_min: 50,
        price_max: 80,
        featured: true,
        organization: {
          id: 'o1',
          name: 'Zen Studio',
          verification_status: { value: 'V', title: 'Verified', css: 'success' },
        },
        sub_category: {
          id: 'sc1',
          name: 'Nature',
          category: { id: 'c1', name: 'Wellness', icon: 'spa' },
        },
        primary_image: null,
        variants: [
          {
            id: 'v1',
            name: '60 min',
            duration_minutes: 60,
            duration_type: { value: 'F', title: 'Fixed', css: 'default' },
            price: 75,
            is_popular: true,
            is_active: true,
          },
        ],
        media: [],
        feature_mappings: [],
        accepted_currency: {
          id: 'cac1',
          currency: { code: 'EUR', symbol: '€', name: 'Euro' },
        },
        average_rating: 4.8,
        rating_count: 12,
        is_active: true,
        show_location_on_listing: true,
        requires_verification: false,
        address: '',
        city: '',
        postal_code: '',
        country: '',
      };

      if (url.match(/\/services\/s1\/?(\?|$)/)) {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify(serviceDetail),
        });
        return;
      }

      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          count: 1,
          next: null,
          previous: null,
          results: [
            {
              id: 's1',
              name: 'Forest Immersion',
              description: 'A calm walk among the trees.',
              price_min: 50,
              price_max: 80,
              featured: true,
              organization: { id: 'o1', name: 'Zen Studio' },
              sub_category: {
                id: 'sc1',
                name: 'Nature',
                category: { id: 'c1', name: 'Wellness', icon: 'spa' },
              },
              primary_image: null,
              accepted_currency: {
                id: 'cac1',
                currency: { code: 'EUR', symbol: '€', name: 'Euro' },
              },
              average_rating: 4.8,
              rating_count: 12,
              is_favorite: false,
            },
          ],
        }),
      });
      return;
    }

    if (url.includes('/bookings/') && method === 'POST') {
      await route.fulfill({
        status: 201,
        contentType: 'application/json',
        body: JSON.stringify({
          id: 'b1',
          service: {
            id: 's1',
            name: 'Forest Immersion',
            category: { id: 'c1', name: 'Wellness', icon: 'spa' },
          },
          organization: { id: 'o1', name: 'Zen Studio', logo: null },
          status: { value: 'R', title: 'Requested', css: 'warning' },
          total_price: '75.00',
          accepted_currency: {
            id: 'cac1',
            currency: { code: 'EUR', symbol: '€', name: 'Euro' },
          },
          service_variant: { id: 'v1', name: '60 min', duration_minutes: 60, price: '75.00' },
          time_slots: [],
          special_requests: '',
          payment_summary: { net_captured: '0', currency_code: 'EUR' },
        }),
      });
      return;
    }

    if (url.includes('/bookings/b1') && method === 'GET') {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          id: 'b1',
          service: {
            id: 's1',
            name: 'Forest Immersion',
            category: { id: 'c1', name: 'Wellness', icon: 'spa' },
          },
          organization: { id: 'o1', name: 'Zen Studio', logo: null },
          status: { value: 'R', title: 'Requested', css: 'warning' },
          total_price: '75.00',
          accepted_currency: {
            id: 'cac1',
            currency: { code: 'EUR', symbol: '€', name: 'Euro' },
          },
          service_variant: { id: 'v1', name: '60 min', duration_minutes: 60, price: '75.00' },
          time_slots: [],
          special_requests: '',
          payment_summary: { net_captured: '0', currency_code: 'EUR' },
        }),
      });
      return;
    }

    if (url.includes('/organizations/mine-summary/')) {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          companies_count: 1,
          beneficiaries_count: 0,
          organizations: [{ id: 'o1', name: 'Zen Studio', logo: null }],
        }),
      });
      return;
    }

    if (url.includes('/organizations/') && method === 'GET') {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          count: 1,
          next: null,
          previous: null,
          results: [
            {
              id: 'o1',
              name: 'Zen Studio',
              email: 'zen@example.com',
              verification_status: { value: 'V', title: 'Verified', css: 'success' },
            },
          ],
        }),
      });
      return;
    }

    if (url.includes('/bookings/') && method === 'GET') {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ count: 0, next: null, previous: null, results: [] }),
      });
      return;
    }

    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ count: 0, next: null, previous: null, results: [] }),
    });
  });
}

test.describe('consumer smoke', () => {
  test('auth → discover → book → pay-confirm → business inbox', async ({ page }) => {
    await mockAuthAndCatalog(page);

    await page.goto('/login');
    await expect(page.getByRole('heading', { name: /login/i })).toBeVisible();
    await page.locator('input#login-email').fill('guest@example.com');
    await page.locator('input#login-password').fill('password123');
    await page.getByRole('button', { name: /login/i }).click();

    await page.waitForURL(/\/discover/);
    await expect(page.locator('#main-content')).toBeVisible();

    await page.goto('/services/s1');
    await expect(page.getByText('Forest Immersion').first()).toBeVisible();

    await page.goto('/services/s1/book');
    await expect(page.getByRole('heading', { name: /schedule/i })).toBeVisible();

    // Pick a future bookable day + time if chips render; otherwise create via confirmation path.
    const dayBtn = page.locator('.schedule__day:not([disabled])').first();
    if (await dayBtn.count()) {
      await dayBtn.click();
      const timeBtn = page.locator('.schedule__time').first();
      if (await timeBtn.count()) {
        await timeBtn.click();
        await page.getByRole('button', { name: /confirm/i }).click();
        await page.waitForURL(/\/bookings\/b1\/confirmation/);
      }
    }

    await page.goto('/bookings/b1/pay');
    await expect(page.getByRole('heading', { name: /confirm payment/i })).toBeVisible();
    await expect(page.getByText(/MainMoney/i).first()).toBeVisible();
    // Stop before external provider redirect.
    await expect(page.getByRole('button', { name: /proceed to mainmoney/i })).toBeVisible();

    await page.goto('/business/o1/bookings');
    await expect(page.locator('#main-content')).toBeVisible();
  });
});
