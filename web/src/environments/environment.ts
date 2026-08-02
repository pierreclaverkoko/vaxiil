export const environment = {
  production: true,
  apiBaseUrl: 'https://api.vaxiiltropbien.com/api/v1/',
  managementAdminUrl: 'https://api.vaxiiltropbien.com/vx-mgmt/',
  supportEmail: 'info@vaxiiltropbien.com',
  supportPhone: '',
  turnstileSiteKey: '0x4AAAAAAD9kzYulPy5lqUue',
  /** Unused in production — Sumsub redirects use `window.location.origin`. */
  kycRedirectOrigin: '',
  featureFlags: {
    messagesEnabled: true,
  },
};
